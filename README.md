# IoT Mushroom Substrate Monitor

MVP system for monitoring and controlling mushroom substrate conditions using:

- ESP32 firmware (`firmware/`)
- FastAPI backend (`backend/`)
- Streamlit dashboard (`dashboard/`)

## IoT device support status

Current firmware and backend integration support:

- `DS18B20` substrate temperature sensor
- Capacitive substrate moisture sensor
- Analog pH sensor
- Relay actuators: fan, heater, humidifier

Note: pH actuator relay control is exposed in backend/dashboard, but firmware-side pH pump logic is still placeholder.

## Run the full project

### 1. Firmware (ESP32)

Update Wi-Fi and pins in `firmware/include/config.h`, then flash:

```bash
cd firmware
pio run -t upload
pio run -t uploadfs
pio device monitor
```

Confirm ESP32 API is reachable:

```bash
curl http://<ESP32_IP>/api/data
```

### 2. Backend (FastAPI)

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp ../.env.example .env
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Set in `backend/.env`:

- `ESP32_BASE_URL=http://<ESP32_IP>`
- `RUNTIME_MODE_DEFAULT=live` (or `mock`)
- `ALLOW_LIVE_FALLBACK=false` (recommended)

### 3. Dashboard (Streamlit)

```bash
cd dashboard
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export BACKEND_API_URL=http://localhost:8000/api
streamlit run app.py
```

## Switching between LIVE and MOCK

You can switch runtime environment in either place:

- Dashboard: `Control Panel -> Environment -> Switch Environment`
- API:

```bash
curl -X PUT http://localhost:8000/api/runtime/mode \
  -H "Content-Type: application/json" \
  -d '{"mode":"live"}'
```

Read using current mode:

```bash
curl -X POST http://localhost:8000/api/sensor/collect
```

Rules:

- `live`: reads/control go to ESP32.
- `mock`: readings are simulated, control is backend-only state.
- `POST /api/sensor/sync` works only in `live`.
- `POST /api/sensor/simulate` works only in `mock`.
