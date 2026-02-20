# System Architecture

## Overview

The IoT Mushroom Substrate Monitor is a three-tier system for monitoring and automatically controlling the environmental conditions of mushroom substrate (temperature, moisture, pH).

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER INTERFACES                          │
│                                                                 │
│   Browser (Streamlit Dashboard)    Browser (ESP32 Local UI)     │
│         http://localhost:8501        http://<ESP32_IP>/         │
└────────────────┬────────────────────────────┬───────────────────┘
                 │ HTTP REST                  │ HTTP REST
                 ▼                            │
┌────────────────────────────┐                │
│     FastAPI Backend        │                │
│     localhost:8000         │                │
│                            │                │
│  ┌──────────────────────┐  │                │
│  │  SQLite Database     │  │                │
│  │  mushroom.db         │  │                │
│  │  - sensor_data       │  │                │
│  │  - alerts            │  │                │
│  │  - actuator_logs     │  │                │
│  │  - control_state     │  │                │
│  │  - runtime_mode      │  │                │
│  │  - system_settings   │  │                │
│  └──────────────────────┘  │                │
└────────────────┬────────────┘                │
                 │ HTTP (live mode only)        │
                 ▼                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                     ESP32 Firmware                              │
│                     port 80                                     │
│                                                                 │
│  DS18B20 ──── GPIO 4 │ Fan Relay ────── GPIO 26 (active LOW)   │
│  Moisture ─── GPIO 34│ Heater Relay ─── GPIO 27 (active LOW)   │
│  pH ADC ───── GPIO 35│ Humidifier Relay GPIO 14 (active LOW)   │
│                       │ pH Pump (future) GPIO 12/13             │
└─────────────────────────────────────────────────────────────────┘
```

---

## Component Breakdown

### 1. ESP32 Firmware (`firmware/`)

Runs on the physical device. Responsible for:
- Reading sensors every 30 seconds
- Running auto-control logic (relay actuators)
- Exposing a local HTTP API on port 80
- Serving a standalone local web dashboard from SPIFFS flash storage
- Maintaining a circular buffer of up to 1000 historical readings in SPIFFS

**Technology stack:** C++, Arduino framework, PlatformIO build system

**Libraries:** ArduinoJson, DallasTemperature, OneWire

---

### 2. FastAPI Backend (`backend/`)

The central processing hub. Responsible for:
- Fetching or simulating sensor data
- Persisting all readings, alerts, and actuator events to SQLite
- Evaluating threshold alerts
- Exposing a REST API consumed by the dashboard
- Maintaining runtime mode state (live vs mock)
- Forwarding actuator commands to the ESP32

**Technology stack:** Python 3.11, FastAPI, SQLAlchemy, Pydantic v2, Uvicorn

---

### 3. Streamlit Dashboard (`dashboard/`)

The operator's primary monitoring interface. Responsible for:
- Displaying real-time sensor readings and charts
- Showing active alerts and deviations
- Allowing threshold configuration
- Sending actuator commands
- Switching between live and mock environments

**Technology stack:** Python 3.11, Streamlit 1.28, Plotly, Requests

---

## Runtime Modes

The system supports two runtime modes, switchable at runtime without restart:

| Mode | Sensor Data | Actuator Control |
|------|-------------|-----------------|
| `live` | Fetched from real ESP32 via HTTP | Commands forwarded to ESP32 GPIO |
| `mock` | Simulated in backend with random drift | Backend state only, no hardware |

The mode is persisted in the `runtime_mode` SQLite table and defaults to the `RUNTIME_MODE_DEFAULT` env var on first boot.

---

## Directory Structure

```
MUSHROOM_SUBSTRATE_MONITOR/
├── backend/                    # FastAPI backend
│   ├── app/
│   │   ├── main.py             # App factory, startup
│   │   ├── api/
│   │   │   └── routes.py       # All API endpoints
│   │   ├── core/
│   │   │   ├── config.py       # Settings (env vars)
│   │   │   └── database.py     # SQLAlchemy engine + session
│   │   ├── models/             # SQLAlchemy ORM models
│   │   │   ├── sensor_data.py
│   │   │   ├── alert.py
│   │   │   ├── actuator_log.py
│   │   │   ├── control_state.py
│   │   │   ├── runtime_mode.py
│   │   │   └── system_settings.py
│   │   ├── schemas/            # Pydantic request/response schemas
│   │   │   ├── sensor.py
│   │   │   ├── alert.py
│   │   │   └── control.py
│   │   ├── crud/               # Database access layer
│   │   │   ├── crud_sensor.py
│   │   │   ├── crud_alert.py
│   │   │   └── crud_actuator.py
│   │   ├── services/
│   │   │   ├── alert_engine.py # Threshold violation detection
│   │   │   └── esp32_client.py # HTTP client for ESP32
│   │   └── utils/
│   │       └── logger.py
│   ├── requirements.txt
│   └── .env                    # Runtime environment config
│
├── dashboard/                  # Streamlit dashboard
│   ├── app.py                  # Entire UI (single file)
│   └── requirements.txt
│
├── firmware/                   # ESP32 C++ firmware
│   ├── src/
│   │   ├── main.cpp            # Setup + loop
│   │   ├── sensors.cpp         # Sensor reading logic
│   │   ├── control_logic.cpp   # Auto-control (relay logic)
│   │   ├── api_server.cpp      # ESP32 HTTP API
│   │   ├── wifi_manager.cpp    # WiFi + AP fallback
│   │   └── data_logger.cpp     # SPIFFS circular buffer
│   ├── include/
│   │   ├── config.h            # All compile-time constants
│   │   ├── sensors.h
│   │   ├── control_logic.h
│   │   ├── api_server.h
│   │   ├── wifi_manager.h
│   │   └── data_logger.h
│   ├── data/                   # SPIFFS web UI
│   │   ├── index.html
│   │   ├── script.js
│   │   └── style.css
│   └── platformio.ini
│
├── scripts/
│   └── deployment/
│       ├── deploy.sh           # Full stack startup script
│       └── stop.sh             # Process termination
├── .env.example                # Environment variable template
└── README.md
```

---

## Database Schema

```
┌──────────────────────────────┐
│         sensor_data          │
├──────────────────────────────┤
│ id (PK)                      │
│ timestamp (indexed)          │
│ temperature                  │
│ moisture                     │
│ ph (nullable)                │
│ temp_min / temp_max          │  ← threshold snapshot
│ moisture_min / moisture_max  │
│ ph_min / ph_max              │
│ device_id (nullable)         │
│ location (nullable)          │
└──────────────────────────────┘

┌──────────────────────────────┐
│           alerts             │
├──────────────────────────────┤
│ id (PK)                      │
│ timestamp (indexed)          │
│ severity ("info"/"warning"   │
│           /"critical")       │
│ parameter ("temperature"     │
│            /"moisture"/"ph") │
│ message                      │
│ threshold_value              │
│ current_value                │
│ resolved (bool)              │
│ resolved_at (nullable)       │
└──────────────────────────────┘

┌──────────────────────────────┐
│        actuator_logs         │
├──────────────────────────────┤
│ id (PK)                      │
│ timestamp (indexed)          │
│ actuator_type ("fan"         │
│   /"heater"/"humidifier"     │
│   /"ph_actuator")            │
│ action ("ON"/"OFF")          │
│ duration_seconds             │
│ triggered_by ("manual_api")  │
│ sensor_temperature (ctx)     │
│ sensor_moisture (ctx)        │
│ sensor_ph (ctx)              │
└──────────────────────────────┘

┌──────────────────────────────┐   ┌──────────────────────────────┐
│        control_state         │   │       system_settings        │
│        (singleton id=1)      │   │       (singleton id=1)       │
├──────────────────────────────┤   ├──────────────────────────────┤
│ id (PK, always 1)            │   │ id (PK, always 1)            │
│ updated_at                   │   │ temp_min  (default 22.0)     │
│ mode ("AUTO"/"MANUAL")       │   │ temp_max  (default 26.0)     │
│ fan (bool)                   │   │ moisture_min (default 60)    │
│ heater (bool)                │   │ moisture_max (default 70)    │
│ humidifier (bool)            │   │ ph_min  (default 6.5)        │
│ ph_actuator (bool)           │   │ ph_max  (default 7.0)        │
└──────────────────────────────┘   └──────────────────────────────┘

┌──────────────────────────────┐
│        runtime_mode          │
│        (singleton id=1)      │
├──────────────────────────────┤
│ id (PK, always 1)            │
│ mode ("live"/"mock")         │
│ updated_at                   │
└──────────────────────────────┘
```

---

## Backend Internal Architecture

```
app/main.py
    │
    ├── app/core/config.py      (Settings singleton - reads .env)
    ├── app/core/database.py    (SQLAlchemy engine, SessionLocal, Base)
    │
    └── app/api/routes.py       (all route handlers)
            │
            ├── app/crud/crud_sensor.py      (SensorData DB ops)
            ├── app/crud/crud_alert.py       (Alert DB ops)
            ├── app/crud/crud_actuator.py    (ActuatorLog DB ops)
            │
            ├── app/services/alert_engine.py (threshold check logic)
            ├── app/services/esp32_client.py (HTTP to ESP32)
            │
            ├── app/models/                  (ORM table definitions)
            └── app/schemas/                 (Pydantic I/O contracts)
```
