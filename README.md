# IoT Mushroom Substrate Monitor

MVP system for monitoring and controlling mushroom substrate conditions using:

- ESP32 firmware (`firmware/`)
- FastAPI backend (`backend/`)
- Streamlit dashboard (`dashboard/`)

## Quick start

1. Flash firmware from `firmware/` (PlatformIO project).
2. Run backend:

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

3. Run dashboard:

```bash
cd dashboard
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
streamlit run app.py
```
