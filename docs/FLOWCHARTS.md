# Flowcharts

All diagrams use [Mermaid](https://mermaid.js.org/) syntax, rendered natively in GitHub, GitLab, and most markdown viewers.

---

## 1. System Startup Flow

```mermaid
flowchart TD
    A([Start]) --> B[Load .env file]
    B --> C[Initialise Settings singleton]
    C --> D[Create SQLAlchemy engine]
    D --> E[Run Base.metadata.create_all\nAuto-create all DB tables]
    E --> F{Tables existed?}
    F -- No --> G[Seed singleton rows\nsystem_settings, control_state,\nruntime_mode from env defaults]
    F -- Yes --> H[Load existing singleton rows]
    G --> I[Register API routes under /api]
    H --> I
    I --> J[Start Uvicorn server\n0.0.0.0:8000]
    J --> K([Ready to accept requests])
```

---

## 2. Sensor Data Collection Flow

```mermaid
flowchart TD
    A([POST /api/sensor/collect]) --> B[Fetch RuntimeMode from DB]
    B --> C{Mode?}

    C -- mock --> D[_build_simulated_payload\nFetch last reading baseline\nApply random drift ±0.5°C etc.\nClamp to valid ranges]
    C -- live --> E[esp32_client.fetch_current_data\nGET http://ESP32_IP/api/data]

    E --> F{ESP32 reachable?}
    F -- No --> G{ALLOW_LIVE_FALLBACK?}
    G -- false --> H[Raise HTTP 502\nESP32 unreachable]
    G -- true --> D

    F -- Yes --> I[Raw ESP32 JSON payload]
    D --> I

    I --> J[_normalize_sensor_payload\nMerge with stored threshold defaults]
    J --> K[sensor_crud.create\nInsert into sensor_data table\nSnapshot thresholds]
    K --> L[build_threshold_alerts\nCheck temp / moisture / pH\nvs min/max thresholds]
    L --> M{Any violations?}
    M -- Yes --> N[alert_crud.create\nInsert Alert row\nseverity = critical]
    M -- No --> O[No alert created]
    N --> P[Return SensorOut JSON]
    O --> P
```

---

## 3. Alert Engine Flow

```mermaid
flowchart TD
    A([build_threshold_alerts called\nwith sensor payload dict]) --> B[Extract temperature, moisture, pH\nExtract thresholds from payload]

    B --> C{temperature < temp_min?}
    C -- Yes --> D[Alert: temperature below threshold\nboundary = temp_min]
    C -- No --> E{temperature > temp_max?}
    E -- Yes --> F[Alert: temperature above threshold\nboundary = temp_max]
    E -- No --> G[No temp alert]

    D --> H
    F --> H
    G --> H

    H{moisture < moisture_min?}
    H -- Yes --> I[Alert: moisture below threshold]
    H -- No --> J{moisture > moisture_max?}
    J -- Yes --> K[Alert: moisture above threshold]
    J -- No --> L[No moisture alert]

    I --> M
    K --> M
    L --> M

    M{ph present AND ph < ph_min?}
    M -- Yes --> N[Alert: pH below threshold]
    M -- No --> O{ph > ph_max?}
    O -- Yes --> P[Alert: pH above threshold]
    O -- No --> Q[No pH alert]

    N --> R[Return list of alert dicts\neach with severity=critical]
    P --> R
    Q --> R
```

---

## 4. Actuator Control Flow

```mermaid
flowchart TD
    A([POST /api/control\nControlCommand payload]) --> B[_build_control_payload\nMap bool → ON/OFF strings]
    B --> C[Fetch RuntimeMode from DB]
    C --> D{Mode?}

    D -- mock --> E[Skip ESP32 forwarding\nLog as simulated]

    D -- live --> F[esp32_client.send_control\nPOST http://ESP32_IP/api/control]
    F --> G{ESP32 reachable?}
    G -- No --> H{ALLOW_LIVE_FALLBACK?}
    H -- false --> I[Raise HTTP 502]
    H -- true --> J[Degrade: apply locally only\nAdd warning to response]
    G -- Yes --> K[ESP32 applies to GPIO relays]

    E --> L[_update_control_state\nUpdate control_state singleton in DB]
    J --> L
    K --> L

    L --> M[Log changed actuators\nInsert ActuatorLog rows\nfor each changed actuator]
    M --> N[Return ControlResponse\nwith success + payload + warnings]
```

---

## 5. ESP32 Firmware Main Loop

```mermaid
flowchart TD
    A([setup]) --> B[initWiFi\nConnect or fallback to AP]
    B --> C[initSensors\nDS18B20 begin, pin modes]
    C --> D[setupActuatorPins\nAll relays HIGH = OFF]
    D --> E[initDataLogger\nMount SPIFFS]
    E --> F[initWebServer\nMount routes + server.begin]
    F --> G([loop])

    G --> H[server.handleClient\nProcess any pending HTTP request]
    H --> I{SENSOR_UPDATE_INTERVAL\n30s elapsed?}
    I -- No --> J{WIFI_RECONNECT_INTERVAL\n30s elapsed?}
    I -- Yes --> K[updateAllSensors\nreadTemperature + readMoisture + readPH]
    K --> L{systemAuto == true?}
    L -- Yes --> M[runControlLogic\nEvaluate thresholds\nSet relay states]
    L -- No --> N[Relays stay at last manual state]
    M --> O[logSensorData\nAppend to circular buffer\nSave to SPIFFS every 10 entries]
    N --> O
    O --> J
    J -- No --> G
    J -- Yes --> P{WiFi connected?}
    P -- Yes --> G
    P -- No --> Q[reconnectWiFi]
    Q --> G
```

---

## 6. ESP32 Auto-Control Logic

```mermaid
flowchart TD
    A([runControlLogic]) --> B{systemAuto?}
    B -- No --> Z([Return immediately])
    B -- Yes --> C[Read currentTemperature]

    C --> D{temp < TEMP_MIN - hysteresis\n< 21.5°C}
    D -- Yes --> E[setHeater ON\nsetFan OFF]
    D -- No --> F{temp > TEMP_MAX + hysteresis\n> 26.5°C}
    F -- Yes --> G[setFan ON\nsetHeater OFF]
    F -- No --> H[setFan OFF\nsetHeater OFF]

    E --> I[Read currentMoisture]
    G --> I
    H --> I

    I --> J{moisture < MOISTURE_MIN - hysteresis\n< 57%}
    J -- Yes --> K[setHumidifier ON]
    J -- No --> L{moisture > MOISTURE_MAX + hysteresis\n> 73%}
    L -- Yes --> M[setHumidifier OFF\nsetFan ON\naiding evaporation]
    L -- No --> N[setHumidifier OFF]

    K --> O[Read currentPH]
    M --> O
    N --> O

    O --> P{pH out of range?}
    P -- Yes --> Q[Serial.println warning only\nNo hardware control yet\nPhase 2 placeholder]
    P -- No --> R([Done])
    Q --> R
```

---

## 7. Dashboard Render Flow

```mermaid
flowchart TD
    A([Page render / auto-refresh]) --> B[GET /api/health]
    B --> C{Backend reachable?}
    C -- No --> D[Show error banner\nStop render]
    C -- Yes --> E[GET /api/settings/targets]
    E --> F[GET /api/control/state]
    F --> G[GET /api/runtime/mode]
    G --> H[GET /api/monitoring/report\n?points=20&log_items=10]

    H --> I[Render LEFT panel]
    I --> I1[Connection expander\nURL input + auto-refresh toggle]
    I1 --> I2[Environment panel\nlive/mock radio + switch button]
    I2 --> I3[Set Optimal Conditions\ntemp / moisture / pH sliders]
    I3 --> I4[System Mode\nAUTO / MANUAL radio]
    I4 --> I5[Actuator toggles\nheater / humidifier / pH / fan]
    I5 --> I6[Collect Reading button]

    H --> J[Render RIGHT panel]
    J --> J1[Metric cards\nTemperature / Humidity / pH]
    J1 --> J2[Deviation detection\ncurrent vs target badges]
    J2 --> J3[Live Sensor chart\nPlotly line chart 20 points]
    J3 --> J4[Sensor Log table\nlast 10 readings]
    J4 --> J5[Monitoring Report\n3x2 summary tiles]
    J5 --> J6[Download Report button\nJSON export]
```

---

## 8. WiFi Manager Flow (ESP32 Startup)

```mermaid
flowchart TD
    A([initWiFi]) --> B[WiFi.begin SSID PASSWORD]
    B --> C[Poll WL_CONNECTED\nmax 30 attempts × 500ms]
    C --> D{Connected?}
    D -- Yes --> E[Print IP address to Serial]
    E --> F[Start mDNS\nmushroom-monitor.local\nHTTP service port 80]
    F --> G([Connected - normal operation])

    D -- No after 30 attempts --> H[Start Access Point\nSSID: MushroomMonitor\nPass: mushroom123]
    H --> I[Print AP IP to Serial\nusually 192.168.4.1]
    I --> J([AP mode - local access only])
```

---

## 9. Runtime Mode Switch Flow

```mermaid
flowchart TD
    A([PUT /api/runtime/mode\nbody: mode=live or mock]) --> B[_normalize_runtime_mode\nValidate value]
    B --> C{Valid mode?}
    C -- No --> D[Return HTTP 400\nInvalid mode value]
    C -- Yes --> E[_get_or_create_runtime_mode\nFetch singleton row id=1]
    E --> F[Update row.mode]
    F --> G[db.commit]
    G --> H[Return updated runtime mode response\nIncludes esp32_base_url + allow_live_fallback]
```

---

## 10. Backend Startup Singleton Seeding

```mermaid
flowchart TD
    A([on_startup event]) --> B[Base.metadata.create_all\nCreate tables if not exist]
    B --> C[First request to any route\nthat calls _get_or_create_*]

    C --> D[_get_or_create_settings]
    D --> E{system_settings id=1 exists?}
    E -- No --> F[INSERT with defaults\ntemp 22-26 / moisture 60-70 / pH 6.5-7.0]
    E -- Yes --> G[Return existing row]

    C --> H[_get_or_create_control_state]
    H --> I{control_state id=1 exists?}
    I -- No --> J[INSERT: mode=AUTO\nall actuators OFF]
    I -- Yes --> K[Return existing row]

    C --> L[_get_or_create_runtime_mode]
    L --> M{runtime_mode id=1 exists?}
    M -- No --> N[INSERT: mode from RUNTIME_MODE_DEFAULT env var]
    M -- Yes --> O[Return existing row]
```
