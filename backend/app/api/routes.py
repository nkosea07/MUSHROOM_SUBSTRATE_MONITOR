import random
from datetime import datetime
from typing import Any

import requests
from fastapi import APIRouter, Body, Depends, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.crud import actuator_crud, alert_crud, sensor_crud
from app.models.control_state import ControlState
from app.models.sensor_data import SensorData
from app.models.system_settings import SystemSettings
from app.schemas import (
    AlertListResponse,
    AlertOut,
    ControlCommand,
    ControlResponse,
    SensorHistoryResponse,
    SensorIn,
    SensorOut,
)
from app.services import build_threshold_alerts, esp32_client

router = APIRouter()


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def _serialize_thresholds(row: SystemSettings) -> dict[str, Any]:
    return {
        "temp_min": row.temp_min,
        "temp_max": row.temp_max,
        "moisture_min": row.moisture_min,
        "moisture_max": row.moisture_max,
        "ph_min": row.ph_min,
        "ph_max": row.ph_max,
    }


def _serialize_control_state(row: ControlState) -> dict[str, Any]:
    return {
        "mode": row.mode,
        "fan": row.fan,
        "heater": row.heater,
        "humidifier": row.humidifier,
        "ph_actuator": row.ph_actuator,
        "updated_at": row.updated_at,
    }


def _parameter_status(value: float, min_value: float, max_value: float) -> str:
    if value < min_value:
        return "low"
    if value > max_value:
        return "high"
    return "optimal"


def _bool_from_value(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().upper() in {"ON", "TRUE", "1"}
    return bool(value)


def _get_or_create_settings(db: Session) -> SystemSettings:
    settings = db.get(SystemSettings, 1)
    if settings:
        return settings

    settings = SystemSettings(id=1)
    db.add(settings)
    db.commit()
    db.refresh(settings)
    return settings


def _get_or_create_control_state(db: Session) -> ControlState:
    state = db.get(ControlState, 1)
    if state:
        return state

    state = ControlState(id=1)
    db.add(state)
    db.commit()
    db.refresh(state)
    return state


def _normalize_sensor_payload(raw_payload: dict[str, Any], settings: SystemSettings) -> dict[str, Any]:
    thresholds = raw_payload.get("thresholds") or _serialize_thresholds(settings)
    return {
        "temperature": float(raw_payload["temperature"]),
        "moisture": int(raw_payload["moisture"]),
        "ph": float(raw_payload.get("ph", 7.0)),
        "temp_min": float(thresholds.get("temp_min", settings.temp_min)),
        "temp_max": float(thresholds.get("temp_max", settings.temp_max)),
        "moisture_min": int(thresholds.get("moisture_min", settings.moisture_min)),
        "moisture_max": int(thresholds.get("moisture_max", settings.moisture_max)),
        "ph_min": float(thresholds.get("ph_min", settings.ph_min)),
        "ph_max": float(thresholds.get("ph_max", settings.ph_max)),
        "device_id": raw_payload.get("device_id"),
        "location": raw_payload.get("location"),
    }


def _create_alerts_for_payload(db: Session, raw_payload: dict[str, Any]) -> list[AlertOut]:
    created: list[AlertOut] = []
    for alert_payload in build_threshold_alerts(raw_payload):
        alert = alert_crud.create(db, alert_payload)
        created.append(AlertOut.model_validate(alert))
    return created


def _build_control_payload(command: ControlCommand) -> dict[str, Any]:
    outgoing: dict[str, Any] = {}

    if command.mode is not None:
        outgoing["mode"] = command.mode

    for key in ("fan", "heater", "humidifier", "ph_actuator"):
        value = getattr(command, key)
        if value is None:
            continue
        if isinstance(value, bool):
            outgoing[key] = "ON" if value else "OFF"
        elif isinstance(value, str):
            outgoing[key] = value.upper()

    if not outgoing:
        raise HTTPException(status_code=400, detail="At least one control field is required")

    return outgoing


def _update_control_state(db: Session, outgoing: dict[str, Any]) -> ControlState:
    state = _get_or_create_control_state(db)

    if "mode" in outgoing:
        state.mode = str(outgoing["mode"]).upper()

    for key in ("fan", "heater", "humidifier", "ph_actuator"):
        if key in outgoing:
            setattr(state, key, _bool_from_value(outgoing[key]))

    db.commit()
    db.refresh(state)
    return state


@router.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@router.get("/settings/targets")
def get_targets(db: Session = Depends(get_db)) -> dict[str, Any]:
    settings = _get_or_create_settings(db)
    return _serialize_thresholds(settings)


@router.put("/settings/targets")
def update_targets(payload: dict[str, Any] = Body(...), db: Session = Depends(get_db)) -> dict[str, Any]:
    settings = _get_or_create_settings(db)

    updates = {
        "temp_min": payload.get("temp_min", settings.temp_min),
        "temp_max": payload.get("temp_max", settings.temp_max),
        "moisture_min": payload.get("moisture_min", settings.moisture_min),
        "moisture_max": payload.get("moisture_max", settings.moisture_max),
        "ph_min": payload.get("ph_min", settings.ph_min),
        "ph_max": payload.get("ph_max", settings.ph_max),
    }

    if float(updates["temp_min"]) >= float(updates["temp_max"]):
        raise HTTPException(status_code=400, detail="temp_min must be lower than temp_max")
    if int(updates["moisture_min"]) >= int(updates["moisture_max"]):
        raise HTTPException(status_code=400, detail="moisture_min must be lower than moisture_max")
    if float(updates["ph_min"]) >= float(updates["ph_max"]):
        raise HTTPException(status_code=400, detail="ph_min must be lower than ph_max")

    settings.temp_min = float(updates["temp_min"])
    settings.temp_max = float(updates["temp_max"])
    settings.moisture_min = int(updates["moisture_min"])
    settings.moisture_max = int(updates["moisture_max"])
    settings.ph_min = float(updates["ph_min"])
    settings.ph_max = float(updates["ph_max"])

    db.commit()
    db.refresh(settings)
    return _serialize_thresholds(settings)


@router.get("/control/state")
def get_control_state(db: Session = Depends(get_db)) -> dict[str, Any]:
    state = _get_or_create_control_state(db)
    return _serialize_control_state(state)


@router.post("/sensor/ingest", response_model=SensorOut)
def ingest_sensor_data(payload: SensorIn, db: Session = Depends(get_db)) -> SensorOut:
    settings = _get_or_create_settings(db)
    raw_payload = payload.model_dump(exclude_none=True)

    if "thresholds" not in raw_payload:
        raw_payload["thresholds"] = _serialize_thresholds(settings)

    sensor_obj = sensor_crud.create(db, _normalize_sensor_payload(raw_payload, settings))
    _create_alerts_for_payload(db, raw_payload)
    return SensorOut.model_validate(sensor_obj)


@router.post("/sensor/sync", response_model=SensorOut)
def sync_sensor_data(db: Session = Depends(get_db)) -> SensorOut:
    settings = _get_or_create_settings(db)

    try:
        raw_payload = esp32_client.fetch_current_data()
    except requests.RequestException as exc:
        raise HTTPException(status_code=502, detail=f"Failed to fetch ESP32 data: {exc}") from exc

    if "thresholds" not in raw_payload:
        raw_payload["thresholds"] = _serialize_thresholds(settings)

    sensor_obj = sensor_crud.create(db, _normalize_sensor_payload(raw_payload, settings))
    _create_alerts_for_payload(db, raw_payload)
    return SensorOut.model_validate(sensor_obj)


@router.post("/sensor/simulate", response_model=SensorOut)
def simulate_sensor_data(db: Session = Depends(get_db)) -> SensorOut:
    settings = _get_or_create_settings(db)
    latest = sensor_crud.get_multi(db, limit=1)
    baseline = latest[0] if latest else None

    temp_mid = (settings.temp_min + settings.temp_max) / 2
    moisture_mid = (settings.moisture_min + settings.moisture_max) / 2
    ph_mid = (settings.ph_min + settings.ph_max) / 2

    temperature = baseline.temperature if baseline else temp_mid
    moisture = float(baseline.moisture) if baseline else moisture_mid
    ph_value = baseline.ph if baseline and baseline.ph is not None else ph_mid

    simulated = {
        "temperature": round(_clamp(temperature + random.uniform(-0.5, 0.5), 0.0, 50.0), 2),
        "moisture": int(round(_clamp(moisture + random.uniform(-2.5, 2.5), 0.0, 100.0))),
        "ph": round(_clamp(ph_value + random.uniform(-0.08, 0.08), 0.0, 14.0), 2),
        "device_id": "simulated-esp32",
        "location": "simulation",
        "thresholds": _serialize_thresholds(settings),
    }

    sensor_obj = sensor_crud.create(db, _normalize_sensor_payload(simulated, settings))
    _create_alerts_for_payload(db, simulated)
    return SensorOut.model_validate(sensor_obj)


@router.get("/sensor/latest", response_model=SensorOut)
def get_latest_sensor_data(db: Session = Depends(get_db)) -> SensorOut:
    items = sensor_crud.get_multi(db, limit=1)
    if not items:
        raise HTTPException(status_code=404, detail="No sensor data available")
    return SensorOut.model_validate(items[0])


@router.get("/sensor/history", response_model=SensorHistoryResponse)
def get_sensor_history(
    limit: int = Query(default=100, ge=1, le=2000),
    db: Session = Depends(get_db),
) -> SensorHistoryResponse:
    items = sensor_crud.get_multi(db, limit=limit)
    serialized = [SensorOut.model_validate(item) for item in items]
    return SensorHistoryResponse(items=serialized, count=len(serialized))


@router.get("/alerts", response_model=AlertListResponse)
def get_alerts(
    unresolved_only: bool = Query(default=True),
    severity: str | None = Query(default=None),
    db: Session = Depends(get_db),
) -> AlertListResponse:
    if unresolved_only:
        alerts = alert_crud.get_unresolved_alerts(db, severity=severity)
    else:
        alerts = alert_crud.get_recent_alerts(db, hours=168, limit=500)
        if severity:
            alerts = [alert for alert in alerts if alert.severity == severity]

    serialized = [AlertOut.model_validate(alert) for alert in alerts]
    return AlertListResponse(items=serialized, count=len(serialized))


@router.post("/alerts/{alert_id}/resolve", response_model=AlertOut)
def resolve_alert(alert_id: int, db: Session = Depends(get_db)) -> AlertOut:
    alert = alert_crud.resolve_alert(db, alert_id)
    if alert is None:
        raise HTTPException(status_code=404, detail="Alert not found")
    return AlertOut.model_validate(alert)


@router.post("/control", response_model=ControlResponse)
def send_control_command(command: ControlCommand, db: Session = Depends(get_db)) -> ControlResponse:
    outgoing = _build_control_payload(command)
    response_payload: dict[str, Any] = {}
    forwarded = False
    warning = None

    if not command.simulate:
        try:
            response_payload = esp32_client.send_control(outgoing)
            forwarded = True
        except requests.RequestException as exc:
            warning = f"ESP32 unavailable, applied locally only: {exc}"
    else:
        warning = "Simulated control mode enabled."

    state = _update_control_state(db, outgoing)

    latest = sensor_crud.get_multi(db, limit=1)
    latest_row = latest[0] if latest else None

    for actuator in ("fan", "heater", "humidifier", "ph_actuator"):
        if actuator not in outgoing:
            continue
        actuator_crud.create(
            db,
            {
                "actuator_type": actuator,
                "action": str(outgoing[actuator]),
                "duration_seconds": 0.0,
                "triggered_by": "manual_api",
                "sensor_temperature": latest_row.temperature if latest_row else None,
                "sensor_moisture": latest_row.moisture if latest_row else None,
                "sensor_ph": latest_row.ph if latest_row else None,
            },
        )

    payload = {
        "forwarded_to_esp32": forwarded,
        "esp32_response": response_payload,
        "warning": warning,
        "state": _serialize_control_state(state),
    }
    message = "Control command applied"
    if warning:
        message = f"{message} ({warning})"

    return ControlResponse(success=True, message=message, payload=payload)


@router.get("/monitoring/report")
def get_monitoring_report(
    points: int = Query(default=20, ge=5, le=500),
    log_items: int = Query(default=10, ge=5, le=100),
    db: Session = Depends(get_db),
) -> dict[str, Any]:
    settings = _get_or_create_settings(db)
    state = _get_or_create_control_state(db)

    max_rows = max(points, log_items, 100)
    history_desc = sensor_crud.get_multi(db, limit=max_rows)

    latest = history_desc[0] if history_desc else None
    live_rows = list(reversed(history_desc[:points]))
    log_rows = history_desc[:log_items]

    total_readings = db.execute(select(func.count(SensorData.id))).scalar_one() or 0

    if latest:
        temp_status = _parameter_status(latest.temperature, settings.temp_min, settings.temp_max)
        moisture_status = _parameter_status(float(latest.moisture), settings.moisture_min, settings.moisture_max)
        ph_status = _parameter_status(float(latest.ph or 7.0), settings.ph_min, settings.ph_max)
    else:
        temp_status = moisture_status = ph_status = "unknown"

    sample = history_desc[: max(points, log_items)]
    if sample:
        avg_temp = round(sum(item.temperature for item in sample) / len(sample), 2)
        avg_moisture = round(sum(item.moisture for item in sample) / len(sample), 1)
        avg_ph = round(sum(float(item.ph or 7.0) for item in sample) / len(sample), 2)
    else:
        avg_temp = avg_moisture = avg_ph = None

    live_series = [
        {
            "timestamp": item.timestamp,
            "temperature": item.temperature,
            "moisture": item.moisture,
            "ph": float(item.ph or 7.0),
        }
        for item in live_rows
    ]

    readings_log = [
        {
            "timestamp": item.timestamp,
            "temperature": item.temperature,
            "moisture": item.moisture,
            "ph": float(item.ph or 7.0),
        }
        for item in log_rows
    ]

    active_actuators = sum([state.fan, state.heater, state.humidifier, state.ph_actuator])

    return {
        "generated_at": datetime.utcnow(),
        "targets": _serialize_thresholds(settings),
        "control_state": _serialize_control_state(state),
        "current": {
            "temperature": latest.temperature if latest else None,
            "moisture": latest.moisture if latest else None,
            "ph": float(latest.ph or 7.0) if latest else None,
            "timestamp": latest.timestamp if latest else None,
        },
        "deviation": {
            "temperature": {
                "status": temp_status,
                "current": latest.temperature if latest else None,
                "target": round((settings.temp_min + settings.temp_max) / 2, 2),
            },
            "moisture": {
                "status": moisture_status,
                "current": latest.moisture if latest else None,
                "target": round((settings.moisture_min + settings.moisture_max) / 2, 1),
            },
            "ph": {
                "status": ph_status,
                "current": float(latest.ph or 7.0) if latest else None,
                "target": round((settings.ph_min + settings.ph_max) / 2, 2),
            },
        },
        "live_series": live_series,
        "readings_log": readings_log,
        "report": {
            "status": {
                "temperature": temp_status,
                "moisture": moisture_status,
                "ph": ph_status,
            },
            "averages": {
                "temperature": avg_temp,
                "moisture": avg_moisture,
                "ph": avg_ph,
            },
            "total_readings": total_readings,
            "active_actuators": active_actuators,
            "max_actuators": 4,
        },
    }


@router.get("/system/overview")
def get_system_overview(db: Session = Depends(get_db)) -> dict[str, Any]:
    latest_items = sensor_crud.get_multi(db, limit=1)
    unresolved = alert_crud.get_unresolved_alerts(db)
    recent_actuation = actuator_crud.get_actuator_history(db, limit=10)
    state = _get_or_create_control_state(db)

    return {
        "latest": SensorOut.model_validate(latest_items[0]).model_dump() if latest_items else None,
        "unresolved_alerts": len(unresolved),
        "control_state": _serialize_control_state(state),
        "recent_actuation": [
            {
                "id": item.id,
                "timestamp": item.timestamp,
                "actuator_type": item.actuator_type,
                "action": item.action,
                "triggered_by": item.triggered_by,
            }
            for item in recent_actuation
        ],
    }
