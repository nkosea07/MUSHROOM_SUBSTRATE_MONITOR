# Configuration Reference

---

## Backend Environment Variables

The backend reads configuration from `backend/.env` (copied from `.env.example`). All values can also be passed as real environment variables — env vars take precedence over the `.env` file.

### Required for Live Mode

| Variable | Example | Description |
|---|---|---|
| `ESP32_BASE_URL` | `http://192.168.1.100` | IP address of the ESP32 on your local network. Find it in the ESP32 serial monitor after boot, or use `mushroom-monitor.local` if mDNS is working. |

### Core Settings

| Variable | Default | Description |
|---|---|---|
| `ENVIRONMENT` | `development` | Environment label. Set to `production` in production deployments. |
| `DEBUG` | `True` | Enable FastAPI debug mode. Set `False` in production. |
| `HOST` | `0.0.0.0` | Uvicorn bind host. |
| `PORT` | `8000` | Uvicorn bind port. |
| `LOG_LEVEL` | `INFO` | Python logging level: `DEBUG`, `INFO`, `WARNING`, `ERROR`. |

### Database

| Variable | Default | Description |
|---|---|---|
| `DATABASE_URL` | `sqlite:///./mushroom.db` | SQLAlchemy connection string. SQLite is used for local/development. For production use PostgreSQL: `postgresql://user:pass@host/dbname` |

> **Note:** When switching to PostgreSQL, ensure the `psycopg2-binary` package is installed (it is already listed in `requirements.txt`).

### Runtime Mode

| Variable | Default | Options | Description |
|---|---|---|---|
| `RUNTIME_MODE_DEFAULT` | `live` | `live`, `mock` | The mode used on first startup (before any runtime switch via the API). Once the mode has been set via the API, this value is ignored — the DB-persisted value takes over. |
| `ALLOW_LIVE_FALLBACK` | `false` | `true`, `false` | If `true`, the backend will fall back to simulating data when the ESP32 is unreachable in live mode. If `false`, requests will return HTTP 502 when the ESP32 is unavailable. |

### ESP32 Connection

| Variable | Default | Description |
|---|---|---|
| `ESP32_BASE_URL` | `http://192.168.1.100` | Base URL of the ESP32 HTTP server (no trailing slash). |
| `ESP32_TIMEOUT` | `10` | Timeout in seconds for all HTTP requests to the ESP32. |

### CORS

| Variable | Default | Description |
|---|---|---|
| `CORS_ORIGINS` | `http://localhost:3000,http://localhost:8501` | Comma-separated list of allowed CORS origins. Always include the Streamlit URL (`http://localhost:8501`). |

### Security (Production)

| Variable | Default | Description |
|---|---|---|
| `SECRET_KEY` | `your-secret-key-change-in-production` | Application secret key. Change this to a long random string in production. Used for future session/JWT signing. |

### Sensor Thresholds (Bootstrap Only)

These `.env` values are NOT used at runtime — thresholds are stored in the `system_settings` database table and managed via the dashboard or API. These values only take effect if you directly seed the database.

| Variable | Default | Description |
|---|---|---|
| `TEMPERATURE_MIN` | `22.0` | Minimum optimal temperature (°C) |
| `TEMPERATURE_MAX` | `26.0` | Maximum optimal temperature (°C) |
| `MOISTURE_MIN` | `60.0` | Minimum optimal moisture (%) |
| `MOISTURE_MAX` | `70.0` | Maximum optimal moisture (%) |
| `PH_MIN` | `6.5` | Minimum optimal pH |
| `PH_MAX` | `7.0` | Maximum optimal pH |

### Unused / Future Variables

These are documented in `.env.example` but not yet consumed by the codebase:

| Variable | Planned Use |
|---|---|
| `REDIS_URL` | Background task queue (Celery + Redis) |
| `INFLUXDB_URL`, `INFLUXDB_TOKEN`, `INFLUXDB_ORG`, `INFLUXDB_BUCKET` | Time-series database for historical data |
| `SMTP_SERVER`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD` | Email alert notifications |
| `UPLOAD_DIR`, `MAX_UPLOAD_SIZE` | File upload endpoints |
| `METRICS_ENABLED` | Prometheus/Grafana metrics export |

---

## Dashboard Environment

The dashboard reads a single environment variable:

| Variable | Default | Description |
|---|---|---|
| `BACKEND_API_URL` | `http://localhost:8000/api` | Full URL to the backend API. The dashboard also allows the operator to change this URL in the UI Connection panel — the UI value overrides the env var within that browser session. |

Set it before running:
```bash
export BACKEND_API_URL=http://localhost:8000/api
streamlit run app.py
```

---

## Firmware Compile-Time Configuration (`firmware/include/config.h`)

All firmware settings are compile-time constants. You must re-flash after changing them.

### WiFi Credentials

```c
#define WIFI_SSID     "your-wifi-ssid"
#define WIFI_PASSWORD "your-wifi-password"
```

> These MUST be changed before flashing. If WiFi fails, the ESP32 starts an AP: SSID `MushroomMonitor`, password `mushroom123`.

### GPIO Pin Assignments

| Define | GPIO | Function |
|---|---|---|
| `TEMP_SENSOR_PIN` | 4 | DS18B20 OneWire data |
| `MOISTURE_SENSOR_PIN` | 34 | Capacitive moisture ADC (ADC1_CH6) |
| `PH_SENSOR_PIN` | 35 | pH sensor ADC (ADC1_CH7) |
| `FAN_PIN` | 26 | Fan relay (active LOW) |
| `HEATER_PIN` | 27 | Heater relay (active LOW) |
| `HUMIDIFIER_PIN` | 14 | Humidifier relay (active LOW) |
| `PUMP_ACID_PIN` | 12 | Acid pH pump — Phase 2 |
| `PUMP_BASE_PIN` | 13 | Base pH pump — Phase 2 |

> **Active LOW relays:** `LOW` signal = relay energised (load ON). `HIGH` signal = relay de-energised (load OFF). All relays initialise to `HIGH` (OFF) at boot.

### Moisture Sensor Calibration

```c
#define MOISTURE_AIR_VALUE   2000   // ADC reading in dry air
#define MOISTURE_WATER_VALUE  900   // ADC reading fully submerged
```

To calibrate:
1. Read ADC with sensor held in air → set `MOISTURE_AIR_VALUE`
2. Read ADC with sensor submerged in water → set `MOISTURE_WATER_VALUE`
3. Re-flash firmware

### Default Thresholds (Hardcoded — match backend defaults)

```c
#define TEMP_MIN     22.0
#define TEMP_MAX     26.0
#define MOISTURE_MIN 60
#define MOISTURE_MAX 70
#define PH_MIN       6.5
#define PH_MAX       7.0
```

> These are used only by the ESP32 auto-control logic. The backend uses database-stored thresholds. When thresholds are updated via the dashboard, the ESP32 auto-control will still use these hardcoded values until re-flashed. This is a known limitation.

### Hysteresis (Dead-Band)

Prevents rapid relay cycling when readings hover near a threshold boundary:

```c
#define TEMP_HYSTERESIS     0.5   // °C
#define MOISTURE_HYSTERESIS 3     // %
#define PH_HYSTERESIS       0.2   // pH units
```

**Example:** With `TEMP_MIN=22.0` and `TEMP_HYSTERESIS=0.5`:
- Heater turns ON below 21.5°C
- Heater turns OFF above 22.0°C (not 21.5°C)

### Timing Intervals

```c
#define SENSOR_UPDATE_INTERVAL   30000   // 30 seconds
#define CONTROL_UPDATE_INTERVAL  60000   // 60 seconds (defined but not independently triggered)
#define DATA_LOG_INTERVAL       300000   // 5 minutes (defined but log fires every sensor cycle)
#define WIFI_RECONNECT_INTERVAL  30000   // 30 seconds
```

### Data Storage

```c
#define MAX_LOG_ENTRIES 1000   // Max circular buffer size in SPIFFS
```

---

## PlatformIO Configuration (`firmware/platformio.ini`)

```ini
[env:esp32dev]
platform         = espressif32
board            = esp32dev
framework        = arduino
monitor_speed    = 115200
upload_speed     = 921600

lib_deps =
    bblanchon/ArduinoJson@^6.21.3
    milesburton/DallasTemperature@^3.11.0
    paulstoffregen/OneWire@^2.3.7

board_build.filesystem = spiffs
board_build.partitions = default_8MB.csv
```

### Changing the Board

If you are using a different ESP32 board variant, change `board`. Common values:
- `esp32dev` — generic 30/38-pin dev board
- `esp32-s3-devkitc-1` — ESP32-S3
- `nodemcu-32s` — NodeMCU-32S

### Serial Monitor Filters

```ini
monitor_filters = log2file, esp32_exception_decoder, time
```

- `log2file` — saves serial output to `.pio/build/log.txt`
- `esp32_exception_decoder` — decodes stack traces on crashes
- `time` — prepends timestamps to serial output

---

## Default Operational Values Summary

| Parameter | Default Min | Default Max | Unit |
|---|---|---|---|
| Temperature | 22.0 | 26.0 | °C |
| Moisture | 60 | 70 | % |
| pH | 6.5 | 7.0 | pH units |

These defaults are appropriate for oyster mushrooms (*Pleurotus ostreatus*). Adjust via the dashboard for other species.

| Species | Temp Range | Moisture Range | pH Range |
|---|---|---|---|
| Oyster (*Pleurotus*) | 18–24°C | 60–70% | 6.0–7.5 |
| Shiitake (*Lentinula*) | 15–21°C | 55–65% | 5.5–6.5 |
| Reishi (*Ganoderma*) | 22–28°C | 60–70% | 5.5–6.5 |
| King Oyster (*P. eryngii*) | 13–18°C | 65–75% | 6.0–7.0 |
