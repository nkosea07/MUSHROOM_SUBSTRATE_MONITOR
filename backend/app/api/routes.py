from typing import Any

import requests
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.crud import actuator_crud, alert_crud, sensor_crud
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


def _normalize_sensor_payload(raw_payload: dict[str, Any]) -> dict[str, Any]:
    thresholds = raw_payload.get("thresholds") or {}
    return {
        "temperature": float(raw_payload["temperature"]),
        "moisture": int(raw_payload["moisture"]),
        "ph": float(raw_payload.get("ph", 7.0)),
        "temp_min": float(thresholds.get("temp_min", 22.0)),
        "temp_max": float(thresholds.get("temp_max", 26.0)),
        "moisture_min": int(thresholds.get("moisture_min", 60)),
        "moisture_max": int(thresholds.get("moisture_max", 70)),
        "ph_min": float(thresholds.get("ph_min", 6.5)),
        "ph_max": float(thresholds.get("ph_max", 7.0)),
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

    for key in ("fan", "heater", "humidifier"):
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


@router.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@router.post("/sensor/ingest", response_model=SensorOut)
def ingest_sensor_data(payload: SensorIn, db: Session = Depends(get_db)) -> SensorOut:
    raw_payload = payload.model_dump(exclude_none=True)
    sensor_obj = sensor_crud.create(db, _normalize_sensor_payload(raw_payload))
    _create_alerts_for_payload(db, raw_payload)
    return SensorOut.model_validate(sensor_obj)


@router.post("/sensor/sync", response_model=SensorOut)
def sync_sensor_data(db: Session = Depends(get_db)) -> SensorOut:
    try:
        raw_payload = esp32_client.fetch_current_data()
    except requests.RequestException as exc:
        raise HTTPException(status_code=502, detail=f"Failed to fetch ESP32 data: {exc}") from exc

    sensor_obj = sensor_crud.create(db, _normalize_sensor_payload(raw_payload))
    _create_alerts_for_payload(db, raw_payload)
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

    try:
        response_payload = esp32_client.send_control(outgoing)
    except requests.RequestException as exc:
        raise HTTPException(status_code=502, detail=f"Failed to send command to ESP32: {exc}") from exc

    latest = sensor_crud.get_multi(db, limit=1)
    latest_row = latest[0] if latest else None

    for actuator in ("fan", "heater", "humidifier"):
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

    return ControlResponse(success=True, message="Command forwarded", payload=response_payload)


@router.get("/system/overview")
def get_system_overview(db: Session = Depends(get_db)) -> dict[str, Any]:
    latest_items = sensor_crud.get_multi(db, limit=1)
    unresolved = alert_crud.get_unresolved_alerts(db)
    recent_actuation = actuator_crud.get_actuator_history(db, limit=10)

    return {
        "latest": SensorOut.model_validate(latest_items[0]).model_dump() if latest_items else None,
        "unresolved_alerts": len(unresolved),
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
