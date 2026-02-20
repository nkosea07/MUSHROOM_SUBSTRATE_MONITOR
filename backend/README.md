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
- `GET /api/settings/targets`
- `PUT /api/settings/targets`
- `POST /api/sensor/ingest`
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
