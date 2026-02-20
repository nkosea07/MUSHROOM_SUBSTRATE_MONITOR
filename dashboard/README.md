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

- Live sensor metrics
- Manual actuator control commands
- ESP32 sync trigger
- Trend charts from backend history
- Unresolved alert display
