from typing import Any


def _threshold_message(parameter: str, value: float, min_value: float, max_value: float) -> tuple[str, float]:
    if value < min_value:
        return f"{parameter} below threshold ({value:.2f} < {min_value:.2f})", min_value
    return f"{parameter} above threshold ({value:.2f} > {max_value:.2f})", max_value


def build_threshold_alerts(payload: dict[str, Any]) -> list[dict[str, Any]]:
    thresholds = payload.get("thresholds", {})

    temp = float(payload["temperature"])
    moisture = float(payload["moisture"])
    ph_value = float(payload.get("ph", 7.0))

    temp_min = float(thresholds.get("temp_min", 22.0))
    temp_max = float(thresholds.get("temp_max", 26.0))
    moisture_min = float(thresholds.get("moisture_min", 60.0))
    moisture_max = float(thresholds.get("moisture_max", 70.0))
    ph_min = float(thresholds.get("ph_min", 6.5))
    ph_max = float(thresholds.get("ph_max", 7.0))

    alerts: list[dict[str, Any]] = []

    checks = [
        ("temperature", temp, temp_min, temp_max),
        ("moisture", moisture, moisture_min, moisture_max),
        ("ph", ph_value, ph_min, ph_max),
    ]

    for parameter, value, min_value, max_value in checks:
        if min_value <= value <= max_value:
            continue

        message, threshold_value = _threshold_message(parameter, value, min_value, max_value)
        alerts.append(
            {
                "severity": "critical",
                "parameter": parameter,
                "message": message,
                "threshold_value": threshold_value,
                "current_value": value,
                "resolved": False,
            }
        )

    return alerts
