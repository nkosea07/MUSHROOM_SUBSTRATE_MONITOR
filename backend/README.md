# Backend Setup

## Run locally

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp ../.env.example .env
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## MVP API endpoints

- `GET /api/health`
- `GET /api/runtime/mode`
- `PUT /api/runtime/mode`
- `GET /api/settings/targets`
- `PUT /api/settings/targets`
- `POST /api/sensor/ingest`
- `POST /api/sensor/collect`
- `POST /api/sensor/sync`
- `POST /api/sensor/simulate`
- `GET /api/sensor/latest`
- `GET /api/sensor/history`
- `GET /api/alerts`
- `POST /api/alerts/{id}/resolve`
- `POST /api/control`
- `GET /api/control/state`
- `GET /api/monitoring/report`
- `GET /api/system/overview`

## Runtime mode behavior

- `live`: reads from ESP32 and forwards control commands to ESP32.
- `mock`: reads simulated data and applies controls locally in backend state only.
- Switch mode with `PUT /api/runtime/mode` using payload `{"mode":"live"}` or `{"mode":"mock"}`.
- `POST /api/sensor/collect` reads from whichever runtime mode is active.
- In current firmware, `ph_actuator` is tracked by backend but not forwarded to ESP32 hardware controls.
