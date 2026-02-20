# Sequence Diagrams

All diagrams use [Mermaid](https://mermaid.js.org/) sequence diagram syntax.

---

## 1. Collect Sensor Reading (Live Mode)

```mermaid
sequenceDiagram
    actor Operator
    participant Dashboard
    participant Backend
    participant DB as SQLite DB
    participant ESP32

    Operator->>Dashboard: Click "Collect Reading"
    Dashboard->>Backend: POST /api/sensor/collect
    Backend->>DB: SELECT runtime_mode WHERE id=1
    DB-->>Backend: mode = "live"
    Backend->>ESP32: GET http://<ESP32_IP>/api/data
    ESP32-->>Backend: {temperature, moisture, ph, actuator_status, alerts...}
    Backend->>DB: SELECT system_settings WHERE id=1
    DB-->>Backend: {temp_min:22, temp_max:26, moisture_min:60, ...}
    Backend->>DB: INSERT INTO sensor_data (temperature, moisture, ph, thresholds...)
    DB-->>Backend: new SensorData row
    Backend->>Backend: build_threshold_alerts(payload)
    alt Any parameter out of range
        Backend->>DB: INSERT INTO alerts (severity, parameter, message, ...)
    end
    Backend-->>Dashboard: SensorOut JSON
    Dashboard->>Dashboard: Re-render with new data
```

---

## 2. Collect Sensor Reading (Mock Mode)

```mermaid
sequenceDiagram
    actor Operator
    participant Dashboard
    participant Backend
    participant DB as SQLite DB

    Operator->>Dashboard: Click "Collect Reading"
    Dashboard->>Backend: POST /api/sensor/collect
    Backend->>DB: SELECT runtime_mode WHERE id=1
    DB-->>Backend: mode = "mock"
    Backend->>DB: SELECT sensor_data ORDER BY timestamp DESC LIMIT 1
    DB-->>Backend: last reading (baseline)
    Backend->>Backend: _build_simulated_payload\nApply random drift to baseline\nClamp to valid sensor ranges
    Backend->>DB: INSERT INTO sensor_data (simulated values)
    DB-->>Backend: new SensorData row
    Backend->>Backend: build_threshold_alerts(payload)
    alt Simulated value crosses threshold
        Backend->>DB: INSERT INTO alerts
    end
    Backend-->>Dashboard: SensorOut JSON
```

---

## 3. Send Actuator Command (Live Mode, Manual)

```mermaid
sequenceDiagram
    actor Operator
    participant Dashboard
    participant Backend
    participant DB as SQLite DB
    participant ESP32

    Operator->>Dashboard: Toggle Heater ON\nClick "Apply Manual Actuators"
    Dashboard->>Backend: POST /api/control\n{mode: "MANUAL", heater: true}
    Backend->>Backend: _build_control_payload\nMap bool → "ON"/"OFF"
    Backend->>DB: SELECT runtime_mode WHERE id=1
    DB-->>Backend: mode = "live"
    Backend->>ESP32: POST /api/control\n{mode: "MANUAL", heater: "ON"}
    ESP32->>ESP32: parseOnOff("ON") → true\nsetHeater(true)\ndigitalWrite(HEATER_PIN, LOW)
    ESP32-->>Backend: {success: true, status: {...}}
    Backend->>DB: UPDATE control_state SET heater=true, updated_at=now()
    Backend->>DB: INSERT INTO actuator_logs\n(actuator_type="heater", action="ON",\ntriggered_by="manual_api")
    Backend-->>Dashboard: ControlResponse {success: true}
    Dashboard->>Dashboard: Refresh actuator state display
```

---

## 4. Send Actuator Command (Mock Mode)

```mermaid
sequenceDiagram
    actor Operator
    participant Dashboard
    participant Backend
    participant DB as SQLite DB

    Operator->>Dashboard: Toggle Fan OFF\nClick "Apply Manual Actuators"
    Dashboard->>Backend: POST /api/control\n{mode: "MANUAL", fan: false}
    Backend->>DB: SELECT runtime_mode WHERE id=1
    DB-->>Backend: mode = "mock"
    Note over Backend: No ESP32 call made
    Backend->>DB: UPDATE control_state SET fan=false
    Backend->>DB: INSERT INTO actuator_logs\n(actuator_type="fan", action="OFF")
    Backend-->>Dashboard: ControlResponse {success: true,\nmessage: "Mock mode - command applied locally"}
```

---

## 5. Switch Runtime Environment

```mermaid
sequenceDiagram
    actor Operator
    participant Dashboard
    participant Backend
    participant DB as SQLite DB

    Operator->>Dashboard: Select "live" radio\nClick "Switch Environment"
    Dashboard->>Backend: PUT /api/runtime/mode\n{mode: "live"}
    Backend->>Backend: _normalize_runtime_mode("live")\nValidate value
    Backend->>DB: SELECT runtime_mode WHERE id=1
    DB-->>Backend: row (current mode)
    Backend->>DB: UPDATE runtime_mode SET mode="live", updated_at=now()
    DB-->>Backend: OK
    Backend-->>Dashboard: {mode: "live", esp32_base_url: "http://...", ...}
    Dashboard->>Dashboard: Update environment indicator
```

---

## 6. Update Threshold Targets

```mermaid
sequenceDiagram
    actor Operator
    participant Dashboard
    participant Backend
    participant DB as SQLite DB

    Operator->>Dashboard: Adjust sliders\nClick "Apply Optimal Conditions"
    Dashboard->>Backend: PUT /api/settings/targets\n{temp_min:21, temp_max:25,\nmoisture_min:55, moisture_max:65,\nph_min:6.0, ph_max:7.5}
    Backend->>Backend: Validate: temp_min < temp_max\nmoisture_min < moisture_max\nph_min < ph_max
    alt Validation fails
        Backend-->>Dashboard: HTTP 422 Unprocessable Entity
    else Validation passes
        Backend->>DB: SELECT system_settings WHERE id=1
        DB-->>Backend: existing row
        Backend->>DB: UPDATE system_settings SET all new values
        DB-->>Backend: OK
        Backend-->>Dashboard: Updated thresholds JSON
        Dashboard->>Dashboard: Re-render sliders + deviation badges
    end
```

---

## 7. Resolve Alert

```mermaid
sequenceDiagram
    actor Operator
    participant Dashboard
    participant Backend
    participant DB as SQLite DB

    Operator->>Dashboard: Click "Resolve" on alert #42
    Dashboard->>Backend: POST /api/alerts/42/resolve
    Backend->>DB: SELECT alerts WHERE id=42
    DB-->>Backend: Alert row (resolved=false)
    Backend->>DB: UPDATE alerts SET resolved=true,\nresolved_at=now() WHERE id=42
    DB-->>Backend: OK
    Backend-->>Dashboard: {success: true, message: "Alert 42 resolved"}
    Dashboard->>Dashboard: Remove alert from list
```

---

## 8. ESP32 Sensor Read Cycle (Internal, every 30s)

```mermaid
sequenceDiagram
    participant Loop as main.cpp loop()
    participant Sensors as sensors.cpp
    participant Control as control_logic.cpp
    participant Logger as data_logger.cpp
    participant HW as Hardware (GPIO/ADC)

    Loop->>Loop: Check SENSOR_UPDATE_INTERVAL elapsed
    Loop->>Sensors: updateAllSensors()
    Sensors->>HW: tempSensors.requestTemperatures()
    HW-->>Sensors: DS18B20 raw value
    Sensors->>Sensors: Apply EMA: 0.7*old + 0.3*new
    Sensors->>HW: analogRead(MOISTURE_SENSOR_PIN)\n× 5 samples averaged
    HW-->>Sensors: raw ADC moisture value
    Sensors->>Sensors: calculateMoisturePercentage\nmap(raw, AIR, WATER, 100, 0)
    Sensors->>HW: analogRead(PH_SENSOR_PIN)
    HW-->>Sensors: raw ADC pH value
    Sensors->>Sensors: pH = 14.0 - (voltage × 3.5)
    Sensors-->>Loop: updated global currentTemperature/Moisture/PH

    alt systemAuto == true
        Loop->>Control: runControlLogic()
        Control->>Sensors: getTemperature(), getMoisture(), getPH()
        Sensors-->>Control: current readings
        Control->>HW: digitalWrite(HEATER_PIN / FAN_PIN / HUMIDIFIER_PIN)
        Control-->>Loop: actuator states updated
    end

    Loop->>Logger: logSensorData()
    Logger->>Logger: Append to circular buffer[bufferIndex]
    Logger->>Logger: bufferIndex++ (wraps at MAX_LOG_ENTRIES)
    alt entryCount % 10 == 0
        Logger->>Logger: saveDataToFile()\nSerialise buffer to /sensor_data.json on SPIFFS
    end
```

---

## 9. Dashboard Auto-Refresh Cycle

```mermaid
sequenceDiagram
    participant Timer as streamlit-autorefresh\nsetInterval(15s)
    participant Streamlit as Streamlit runtime
    participant Backend

    Timer->>Streamlit: Trigger page rerun
    Streamlit->>Backend: GET /api/health
    Backend-->>Streamlit: {status: "ok"}
    Streamlit->>Backend: GET /api/settings/targets
    Backend-->>Streamlit: threshold config
    Streamlit->>Backend: GET /api/control/state
    Backend-->>Streamlit: actuator states
    Streamlit->>Backend: GET /api/runtime/mode
    Backend-->>Streamlit: live/mock mode
    Streamlit->>Backend: GET /api/monitoring/report?points=20&log_items=10
    Backend->>Backend: Compute averages, deviation, live series
    Backend-->>Streamlit: {avg_temp, avg_moisture, avg_ph,\nlive_series: [...], log: [...], ...}
    Streamlit->>Streamlit: Re-render all UI components
```

---

## 10. ESP32 HTTP Request Handling (GET /api/data)

```mermaid
sequenceDiagram
    participant Client as Backend (esp32_client.py)
    participant Server as api_server.cpp
    participant Sensors as sensors.cpp
    participant Control as control_logic.cpp
    participant WiFi as wifi_manager.cpp

    Client->>Server: GET /api/data
    Server->>Sensors: getTemperature()
    Sensors-->>Server: currentTemperature
    Server->>Sensors: getMoisture()
    Sensors-->>Server: currentMoisture
    Server->>Sensors: getPH()
    Sensors-->>Server: currentPH
    Server->>Control: isFanOn(), isHeaterOn(),\nisHumidifierOn(), isAutoMode()
    Control-->>Server: actuator boolean states
    Server->>WiFi: getIPAddress(), getRSSI()
    WiFi-->>Server: IP string, RSSI dBm
    Server->>Server: appendActiveAlerts()\nCheck all readings vs TEMP_MIN/MAX etc.
    Server-->>Client: JSON:\n{temperature, moisture, ph,\nthresholds: {temp_min,...},\nactuators: {fan, heater, humidifier, mode},\nwifi: {ip, rssi},\nalerts: [...]}
```

---

## 11. Monitoring Report Generation

```mermaid
sequenceDiagram
    participant Dashboard
    participant Backend
    participant DB as SQLite DB

    Dashboard->>Backend: GET /api/monitoring/report?points=20&log_items=10
    Backend->>DB: SELECT sensor_data ORDER BY timestamp DESC LIMIT 20
    DB-->>Backend: last 20 readings list
    Backend->>DB: SELECT sensor_data ORDER BY timestamp DESC LIMIT 10
    DB-->>Backend: last 10 readings (for log)
    Backend->>DB: SELECT alerts WHERE resolved=false
    DB-->>Backend: active alert rows
    Backend->>DB: SELECT control_state WHERE id=1
    DB-->>Backend: actuator state
    Backend->>Backend: Compute averages:\navg_temp = mean(temps)\navg_moisture = mean(moistures)\navg_ph = mean(phs)\ntemp_status = "optimal"/"low"/"high"\nActive actuator count
    Backend->>Backend: Build live_series dict:\n{timestamps, temperatures,\nmoistures, ph_values}
    Backend-->>Dashboard: {avg_temp, avg_moisture, avg_ph,\ntemp_status, moisture_status, ph_status,\nlive_series: {timestamps:[...], ...},\nlog: [{timestamp, temperature, ...}×10],\ntotal_readings, active_alerts,\nactuator_history, ...}
```
