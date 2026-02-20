# Dashboard Setup

## Run locally

```bash
cd dashboard
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export BACKEND_API_URL=http://localhost:8000/api
streamlit run app.py
```

The dashboard supports:

- Runtime environment switch (`LIVE` vs `MOCK`)
- Left control panel for target ranges and actuator toggles
- Live metric cards for temperature, humidity, and pH
- Deviation detection panel (current vs target)
- Live chart (last 20 readings)
- Sensor readings log (last 10 readings)
- Monitoring report summary + downloadable report payload
- Environment-aware reading collection (`/api/sensor/collect`)
