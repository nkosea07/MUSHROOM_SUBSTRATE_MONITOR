# Documentation Index

## IoT Mushroom Substrate Monitor

| Document | Contents |
|---|---|
| [ARCHITECTURE.md](ARCHITECTURE.md) | System overview, component breakdown, directory structure, database schema, internal wiring diagram |
| [FLOWCHARTS.md](FLOWCHARTS.md) | Mermaid flowcharts: system startup, sensor collection, alert engine, actuator control, firmware main loop, ESP32 auto-control logic, dashboard render, WiFi manager, runtime mode switch, singleton seeding |
| [SEQUENCE_DIAGRAMS.md](SEQUENCE_DIAGRAMS.md) | Mermaid sequence diagrams: live/mock data collection, actuator commands, environment switch, threshold update, alert resolution, ESP32 sensor cycle, dashboard auto-refresh, monitoring report generation |
| [API_REFERENCE.md](API_REFERENCE.md) | Complete REST API reference for both the FastAPI backend and the ESP32 local API — all endpoints, request/response schemas, error codes |
| [CONFIGURATION.md](CONFIGURATION.md) | All environment variables (backend + dashboard), firmware compile-time constants, pin assignments, calibration, PlatformIO settings, species-specific threshold guide |
| [FIRMWARE.md](FIRMWARE.md) | Firmware module architecture, hardware pin map, sensor wiring, control logic, SPIFFS storage, WiFi manager, local web dashboard, flashing instructions, serial output reference, Phase 2 roadmap |

---

## Quick Reference

### Running the stack

```bash
# Terminal 1 — Backend
cd backend && source .venv/bin/activate
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Terminal 2 — Dashboard
cd dashboard && source .venv/bin/activate
export BACKEND_API_URL=http://localhost:8000/api
streamlit run app.py

# Terminal 3 — Firmware (if ESP32 connected)
cd firmware && pio run -t upload && pio run -t uploadfs && pio device monitor
```

### Access Points

| Service | URL |
|---|---|
| Dashboard | http://localhost:8501 |
| Backend API | http://localhost:8000 |
| Swagger UI | http://localhost:8000/docs |
| ESP32 Local UI | http://\<ESP32_IP\>/ |
| ESP32 mDNS | http://mushroom-monitor.local/ |

### Key API Calls

```bash
# Collect a reading
curl -X POST http://localhost:8000/api/sensor/collect

# Switch to mock mode
curl -X PUT http://localhost:8000/api/runtime/mode \
  -H "Content-Type: application/json" -d '{"mode":"mock"}'

# Get latest reading
curl http://localhost:8000/api/sensor/latest

# Get active alerts
curl "http://localhost:8000/api/alerts?unresolved_only=true"

# Turn heater on manually
curl -X POST http://localhost:8000/api/control \
  -H "Content-Type: application/json" \
  -d '{"mode":"MANUAL","heater":true}'
```
