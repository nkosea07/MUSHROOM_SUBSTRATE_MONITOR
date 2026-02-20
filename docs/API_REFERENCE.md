# Backend API Reference

Base URL: `http://localhost:8000/api`

Interactive docs (Swagger UI): `http://localhost:8000/docs`

All request and response bodies use `application/json`.

---

## Health

### GET /health

Returns backend health status.

**Response 200**
```json
{
  "status": "ok"
}
```

---

## Runtime Mode

### GET /runtime/mode

Returns the current live/mock runtime mode and ESP32 configuration.

**Response 200**
```json
{
  "mode": "mock",
  "esp32_base_url": "http://192.168.1.100",
  "allow_live_fallback": false,
  "updated_at": "2024-01-15T10:30:00Z"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `mode` | string | `"live"` or `"mock"` |
| `esp32_base_url` | string | ESP32 device URL from environment config |
| `allow_live_fallback` | bool | Whether to fall back to mock if ESP32 is unreachable |
| `updated_at` | datetime | Last mode change timestamp |

---

### PUT /runtime/mode

Switch between live and mock mode. Takes effect immediately without restart.

**Request Body**
```json
{
  "mode": "live"
}
```

| Field | Type | Required | Values |
|-------|------|----------|--------|
| `mode` | string | Yes | `"live"` or `"mock"` |

**Response 200** — same shape as GET /runtime/mode

**Response 400** — invalid mode value
```json
{
  "detail": "Invalid mode: must be 'live' or 'mock'"
}
```

---

## Settings / Thresholds

### GET /settings/targets

Returns current optimal range thresholds stored in the database.

**Response 200**
```json
{
  "temp_min": 22.0,
  "temp_max": 26.0,
  "moisture_min": 60,
  "moisture_max": 70,
  "ph_min": 6.5,
  "ph_max": 7.0
}
```

---

### PUT /settings/targets

Update one or more threshold values. All fields are optional — only supplied fields are updated.

**Request Body**
```json
{
  "temp_min": 21.0,
  "temp_max": 25.0,
  "moisture_min": 55,
  "moisture_max": 65,
  "ph_min": 6.0,
  "ph_max": 7.5
}
```

**Validation rules:**
- `temp_min` must be less than `temp_max`
- `moisture_min` must be less than `moisture_max`
- `ph_min` must be less than `ph_max`
- Moisture values must be integers 0–100
- pH values must be floats 0.0–14.0

**Response 200** — updated thresholds (same shape as GET)

**Response 422** — validation error

---

## Sensor Data

### POST /sensor/collect

Smart collect: fetches from ESP32 in live mode, simulates in mock mode. This is the primary endpoint for regular data ingestion.

**Request Body** — none required

**Response 200**
```json
{
  "id": 42,
  "timestamp": "2024-01-15T10:30:00Z",
  "temperature": 24.3,
  "moisture": 65,
  "ph": 6.7,
  "temp_min": 22.0,
  "temp_max": 26.0,
  "moisture_min": 60,
  "moisture_max": 70,
  "ph_min": 6.5,
  "ph_max": 7.0,
  "device_id": "simulated-esp32",
  "location": null
}
```

**Response 502** — ESP32 unreachable (live mode only, when fallback disabled)

---

### POST /sensor/sync

Force fetch from ESP32. Only works in `live` mode.

**Response 200** — same as /sensor/collect

**Response 409** — called while in mock mode
```json
{
  "detail": "sync only available in live mode"
}
```

**Response 502** — ESP32 unreachable

---

### POST /sensor/simulate

Generate and save a simulated reading. Only works in `mock` mode.

**Response 200** — same as /sensor/collect

**Response 409** — called while in live mode

---

### POST /sensor/ingest

Manually push sensor data from an external source (not from ESP32).

**Request Body**
```json
{
  "temperature": 23.5,
  "moisture": 63,
  "ph": 6.8,
  "timestamp": "2024-01-15T10:30:00Z",
  "device_id": "my-device",
  "location": "shelf-1",
  "thresholds": {
    "temp_min": 22.0,
    "temp_max": 26.0,
    "moisture_min": 60,
    "moisture_max": 70,
    "ph_min": 6.5,
    "ph_max": 7.0
  }
}
```

| Field | Type | Required | Validation |
|-------|------|----------|------------|
| `temperature` | float | Yes | — |
| `moisture` | int | Yes | 0–100 |
| `ph` | float | No | 0.0–14.0 |
| `timestamp` | datetime | No | defaults to now |
| `device_id` | string | No | — |
| `location` | string | No | — |
| `thresholds` | object | No | uses DB defaults if omitted |

**Response 200** — SensorOut

---

### GET /sensor/latest

Returns the most recent sensor reading.

**Response 200** — SensorOut (same shape as /sensor/collect)

**Response 404** — no readings recorded yet

---

### GET /sensor/history

Returns a paginated list of recent sensor readings, newest first.

**Query Parameters**

| Parameter | Type | Default | Max | Description |
|-----------|------|---------|-----|-------------|
| `limit` | int | 100 | 2000 | Number of records to return |

**Response 200**
```json
{
  "items": [
    {
      "id": 42,
      "timestamp": "2024-01-15T10:30:00Z",
      "temperature": 24.3,
      "moisture": 65,
      "ph": 6.7,
      ...
    }
  ],
  "count": 42
}
```

---

## Alerts

### GET /alerts

Returns alerts with optional filters.

**Query Parameters**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `unresolved_only` | bool | false | If true, only return unresolved alerts |
| `severity` | string | null | Filter by: `"info"`, `"warning"`, or `"critical"` |

**Response 200**
```json
{
  "items": [
    {
      "id": 7,
      "timestamp": "2024-01-15T10:31:00Z",
      "severity": "critical",
      "parameter": "temperature",
      "message": "temperature above threshold: 27.1 > 26.0",
      "threshold_value": 26.0,
      "current_value": 27.1,
      "resolved": false,
      "resolved_at": null
    }
  ],
  "count": 1
}
```

| Field | Type | Description |
|-------|------|-------------|
| `severity` | string | `"info"`, `"warning"`, or `"critical"` |
| `parameter` | string | `"temperature"`, `"moisture"`, or `"ph"` |
| `threshold_value` | float | The boundary that was violated |
| `current_value` | float | The reading that triggered the alert |

---

### POST /alerts/{alert_id}/resolve

Mark a specific alert as resolved.

**Path Parameters**

| Parameter | Type | Description |
|-----------|------|-------------|
| `alert_id` | int | Alert record ID |

**Response 200**
```json
{
  "success": true,
  "message": "Alert 7 resolved"
}
```

**Response 404** — alert not found

---

## Actuator Control

### GET /control/state

Returns the current state of all actuators and control mode.

**Response 200**
```json
{
  "mode": "MANUAL",
  "fan": false,
  "heater": true,
  "humidifier": false,
  "ph_actuator": false,
  "updated_at": "2024-01-15T10:35:00Z"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `mode` | string | `"AUTO"` or `"MANUAL"` |
| `fan` | bool | Fan relay state |
| `heater` | bool | Heater relay state |
| `humidifier` | bool | Humidifier relay state |
| `ph_actuator` | bool | pH pump state (backend-only, not forwarded to ESP32) |

---

### POST /control

Send an actuator command. In live mode, the command is forwarded to the ESP32. In mock mode, it updates backend state only.

**Request Body**
```json
{
  "mode": "MANUAL",
  "fan": false,
  "heater": true,
  "humidifier": false,
  "ph_actuator": false,
  "simulate": false
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `mode` | string | No | `"AUTO"` or `"MANUAL"` — sets control mode |
| `fan` | bool/string | No | Target fan state |
| `heater` | bool/string | No | Target heater state |
| `humidifier` | bool/string | No | Target humidifier state |
| `ph_actuator` | bool/string | No | Target pH pump state (backend only) |
| `simulate` | bool | No | Forces mock behaviour for this command |

Actuator fields accept: `true`/`false`, `"ON"`/`"OFF"`, `"TRUE"`/`"FALSE"`, `"1"`/`"0"`.

**Response 200**
```json
{
  "success": true,
  "message": "Control command applied",
  "payload": {
    "mode": "MANUAL",
    "forwarded_to_esp32": true,
    "esp32_response": {"success": true},
    "warnings": [],
    "state": {
      "fan": false,
      "heater": true,
      "humidifier": false,
      "ph_actuator": false
    }
  }
}
```

**Response 502** — ESP32 unreachable (live mode, fallback disabled)

**Notes:**
- In `AUTO` mode the ESP32 manages its own actuators automatically based on sensor readings. Manual actuator commands are rejected by the ESP32 in AUTO mode (HTTP 409 from firmware).
- `ph_actuator` is tracked in backend state but never forwarded to ESP32. pH hardware control is a Phase 2 feature.

---

## Monitoring

### GET /monitoring/report

Returns an aggregated summary for dashboard display.

**Query Parameters**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `points` | int | 20 | Number of readings for chart series |
| `log_items` | int | 10 | Number of readings for log table |

**Response 200**
```json
{
  "avg_temperature": 24.1,
  "avg_moisture": 64,
  "avg_ph": 6.72,
  "temp_status": "optimal",
  "moisture_status": "optimal",
  "ph_status": "low",
  "total_readings": 158,
  "active_alerts": 2,
  "active_actuator_count": 1,
  "live_series": {
    "timestamps": ["10:00:00", "10:00:30", ...],
    "temperatures": [24.1, 24.3, ...],
    "moistures": [63, 65, ...],
    "ph_values": [6.7, 6.8, ...]
  },
  "log": [
    {
      "timestamp": "2024-01-15T10:35:00Z",
      "temperature": 24.3,
      "moisture": 65,
      "ph": 6.7
    }
  ],
  "actuator_history": [...]
}
```

| Status value | Meaning |
|---|---|
| `"optimal"` | Value within min–max range |
| `"low"` | Value below min |
| `"high"` | Value above max |

---

### GET /system/overview

High-level system summary for dashboard header.

**Response 200**
```json
{
  "latest_reading": { ...SensorOut... },
  "active_alert_count": 2,
  "actuator_history": [...]
}
```

---

## Error Responses

All error responses follow FastAPI's standard format:

```json
{
  "detail": "Human-readable error message"
}
```

| HTTP Status | Meaning |
|-------------|---------|
| 400 | Bad request — invalid parameter value |
| 404 | Resource not found |
| 409 | Conflict — e.g. calling sync in mock mode |
| 422 | Validation error — request body failed schema validation |
| 502 | Bad gateway — ESP32 unreachable |

---

## ESP32 API Reference

The ESP32 exposes its own HTTP API on port 80 (consumed by the backend in live mode).

Base URL: `http://<ESP32_IP>` (default `http://192.168.1.100`)

### GET /api/data

Returns current sensor readings, actuator states, and active alerts.

**Response 200**
```json
{
  "temperature": 24.3,
  "moisture": 65,
  "ph": 6.7,
  "thresholds": {
    "temp_min": 22.0, "temp_max": 26.0,
    "moisture_min": 60, "moisture_max": 70,
    "ph_min": 6.5, "ph_max": 7.0
  },
  "actuators": {
    "fan": false,
    "heater": false,
    "humidifier": false,
    "mode": "AUTO"
  },
  "wifi": {
    "ip": "192.168.1.100",
    "rssi": -62
  },
  "alerts": [
    {"parameter": "ph", "value": 6.7, "min": 6.5, "max": 7.0, "type": "ok"}
  ]
}
```

---

### POST /api/control

Apply mode or actuator state changes.

**Request Body**
```json
{
  "mode": "MANUAL",
  "fan": "ON",
  "heater": "OFF",
  "humidifier": "OFF"
}
```

Accepts string values `"ON"`/`"OFF"` for actuators. If `mode` is `"AUTO"`, the ESP32 runs its own control logic and rejects manual actuator fields (returns HTTP 409).

**Response 200**
```json
{
  "success": true,
  "mode": "MANUAL",
  "fan": false,
  "heater": false,
  "humidifier": true
}
```

---

### GET /api/history?count=N

Returns last N data points from the SPIFFS circular buffer (max 500).

**Response 200**
```json
{
  "count": 50,
  "data": {
    "timestamps": [12345, 12375, ...],
    "temperatures": [24.1, 24.3, ...],
    "moistures": [63, 65, ...],
    "ph_values": [6.7, 6.8, ...]
  }
}
```

---

### GET /api/alerts

Returns only active (threshold-crossing) alerts from current readings.

**Response 200**
```json
{
  "alerts": [
    {
      "parameter": "temperature",
      "value": 27.1,
      "min": 22.0,
      "max": 26.0,
      "type": "above"
    }
  ]
}
```
