# Firmware Reference

## Overview

The ESP32 firmware runs on the physical IoT device. It is an Arduino-framework C++ application built with PlatformIO. It operates independently of the Python backend — it can run standalone with its own local web dashboard.

---

## Module Architecture

```
main.cpp (setup + loop)
    │
    ├── wifi_manager.cpp     WiFi connection, mDNS, AP fallback
    ├── sensors.cpp          DS18B20 temp, capacitive moisture, pH ADC
    ├── control_logic.cpp    Relay actuator states + auto-control
    ├── api_server.cpp       HTTP server (port 80) + route handlers
    └── data_logger.cpp      In-memory circular buffer + SPIFFS persistence
```

Each module has a corresponding header in `include/`.

---

## Hardware Pin Map

```
┌─────────────────────────────────────────────────────┐
│                     ESP32 Dev Board                 │
│                                                     │
│  GPIO  4 ──── DS18B20 Data (OneWire)                │
│  GPIO 34 ──── Capacitive Moisture Sensor (ADC)      │
│  GPIO 35 ──── pH Sensor Analog Output (ADC)         │
│                                                     │
│  GPIO 26 ──── Fan Relay        IN (active LOW)      │
│  GPIO 27 ──── Heater Relay     IN (active LOW)      │
│  GPIO 14 ──── Humidifier Relay IN (active LOW)      │
│  GPIO 12 ──── pH Acid Pump     (Phase 2, unused)    │
│  GPIO 13 ──── pH Base Pump     (Phase 2, unused)    │
│                                                     │
│  3.3V  ─────── DS18B20 VCC + 4.7kΩ pull-up to GPIO4│
│  GND   ─────── All sensor grounds                  │
└─────────────────────────────────────────────────────┘
```

### Active LOW Relay Wiring

The relay modules used are active LOW — a LOW signal from the ESP32 energises the relay (turning the load ON). All relay pins are initialised to HIGH (OFF) at boot.

```
ESP32 GPIO 26 ──── Relay IN
                   Relay COM ──── Load+
                   Relay NO  ──── Supply+
                   GND       ──── Load-
```

---

## Sensor Details

### DS18B20 Temperature Sensor

- **Interface:** OneWire protocol on GPIO 4
- **Library:** `DallasTemperature` + `OneWire`
- **Resolution:** 12-bit (0.0625°C resolution)
- **Range:** -55°C to +125°C
- **Smoothing:** Exponential moving average: `new = 0.7 × old + 0.3 × reading`

**Wiring:**
```
VCC  ──── 3.3V
GND  ──── GND
DATA ──── GPIO 4 (with 4.7kΩ pull-up to 3.3V)
```

---

### Capacitive Moisture Sensor

- **Interface:** Analog voltage on GPIO 34 (ADC1_CH6)
- **Reading:** 5-sample average to reduce noise
- **Calibration values** (in `config.h`):
  - `MOISTURE_AIR_VALUE = 2000` — ADC count in dry air
  - `MOISTURE_WATER_VALUE = 900` — ADC count fully submerged
- **Formula:** `moisture% = map(raw, AIR, WATER, 0, 100)`, clamped 0–100

**Calibration procedure:**
1. Hold sensor in open air, read serial output → update `MOISTURE_AIR_VALUE`
2. Place sensor tip in water, read serial output → update `MOISTURE_WATER_VALUE`
3. Re-flash firmware

---

### pH Sensor

- **Interface:** Analog voltage on GPIO 35 (ADC1_CH7)
- **Formula:** `pH = 14.0 - (voltage × 3.5)`
  - voltage = `analogRead(pin) × 3.3 / 4095`
- **Note:** The linear formula is a coarse approximation. A proper calibration with two-point buffer solutions (pH 4.0 and pH 7.0) is required for accuracy in production.

---

## Control Logic

### AUTO Mode

In AUTO mode the ESP32 continuously evaluates sensor readings against hardcoded thresholds and applies hysteresis:

**Temperature control:**

| Condition | Action |
|---|---|
| temp < (TEMP_MIN − hysteresis) i.e. < 21.5°C | Heater ON, Fan OFF |
| temp > (TEMP_MAX + hysteresis) i.e. > 26.5°C | Fan ON, Heater OFF |
| Within range | Both OFF |

**Moisture control:**

| Condition | Action |
|---|---|
| moisture < (MOISTURE_MIN − hysteresis) i.e. < 57% | Humidifier ON |
| moisture > (MOISTURE_MAX + hysteresis) i.e. > 73% | Humidifier OFF, Fan ON (to aid drying) |
| Within range | Humidifier OFF |

**pH control:** No hardware action. Serial warning only. Phase 2.

### MANUAL Mode

In MANUAL mode, actuator states are set directly via the HTTP API (`POST /api/control`). The auto-control loop is bypassed. Manual mode persists until explicitly switched back to AUTO.

### Hysteresis Explained

Without hysteresis, a sensor reading hovering at exactly the threshold boundary would cause the relay to switch ON and OFF hundreds of times per second (relay chatter), damaging the hardware. Hysteresis introduces a dead-band:

```
Heater ON  ────────────────────────────────────
             21.5°C (TEMP_MIN - HYSTERESIS)
                     ↑ heater turns ON here

Heater OFF ──────────────────────────────────────
             22.0°C (TEMP_MIN)
                     ↑ heater turns OFF here
```

---

## Data Storage (SPIFFS)

The ESP32 uses SPIFFS (SPI Flash File System) for two purposes:

1. **Static web UI files** (`/data/` directory):
   - `/index.html` — local dashboard
   - `/style.css` — styling
   - `/script.js` — client-side JavaScript

2. **Historical sensor data** (`/sensor_data.json`):
   - Written every 10 sensor readings (every ~5 minutes)
   - Contains last 1000 readings in parallel arrays
   - Survives reboot

### Circular Buffer

```c
DataPoint dataBuffer[1000];  // Fixed-size array
int bufferIndex = 0;          // Current write position
int dataCount = 0;            // Total entries (caps at 1000)

// Each DataPoint contains:
// - unsigned long timestamp (millis since boot)
// - float temperature
// - int moisture
// - float ph
```

When `bufferIndex` reaches 1000, it wraps back to 0, overwriting the oldest entry (FIFO circular buffer).

---

## WiFi Manager

### Normal Boot (Router Available)

1. Connect to configured SSID/PASSWORD
2. Poll `WL_CONNECTED` up to 30 × 500ms = 15 seconds
3. On success: print IP to Serial, start mDNS as `mushroom-monitor.local`
4. Accessible via `http://mushroom-monitor.local/` or `http://<IP>/`

### Fallback (AP Mode)

If WiFi fails:
1. Start soft AP: SSID `MushroomMonitor`, Password `mushroom123`
2. Default AP gateway IP: `192.168.4.1`
3. Connect your laptop directly to `MushroomMonitor` WiFi
4. Access dashboard at `http://192.168.4.1/`

### Reconnection

Every 30 seconds the loop checks `WiFi.status()`. If disconnected, calls `reconnectWiFi()` which re-runs the connection sequence with up to 20 attempts.

---

## Local Web Dashboard

The ESP32 serves a full dashboard at `http://<ESP32_IP>/` from SPIFFS. This is independent of the Python stack.

**Features:**
- Live sensor cards (temperature, moisture, pH) with optimal/critical badges
- Control panel: AUTO/MANUAL mode toggle
- Manual actuator buttons (hidden in AUTO mode)
- Active alerts list (auto-expires non-critical alerts after 30 seconds)
- WiFi info (IP, RSSI) and uptime counter
- Auto-refresh every 5 seconds via `setInterval`

**Technology:** Vanilla JavaScript, no frameworks. All in `firmware/data/script.js`.

---

## Flashing the Firmware

### Prerequisites

- [PlatformIO CLI](https://platformio.org/install/cli): `pip install platformio`
- ESP32 connected via USB

### Steps

```bash
cd firmware

# 1. Edit WiFi credentials
#    Open include/config.h and set WIFI_SSID and WIFI_PASSWORD

# 2. Compile and upload firmware
pio run -t upload

# 3. Upload SPIFFS filesystem (web UI files)
pio run -t uploadfs

# 4. Open serial monitor (Ctrl+C to exit)
pio device monitor
```

### Compile Database Commands

PlatformIO generates a compile commands database at:
```
firmware/.pio/build/esp32dev/compile_commands.json
```

This is used by VSCode C++ IntelliSense (`c_cpp_properties.json` is pre-configured to use it).

---

## Serial Monitor Output

At boot you will see:
```
Mushroom Substrate Monitor v1.0
Connecting to WiFi...
WiFi connected!
IP Address: 192.168.1.100
RSSI: -58 dBm
mDNS responder started: mushroom-monitor.local
SPIFFS mounted successfully
Web server started on port 80
```

Every 30 seconds during normal operation:
```
[12:00:30] Sensors updated - Temp: 24.3°C  Moisture: 65%  pH: 6.72
[12:00:30] Control: Heater=OFF  Fan=OFF  Humidifier=OFF  Mode=AUTO
[12:01:00] Sensors updated - Temp: 24.4°C  Moisture: 64%  pH: 6.71
```

---

## Firmware Limitations / Phase 2 Roadmap

| Feature | Status | Notes |
|---|---|---|
| DS18B20 temperature | Done | |
| Capacitive moisture | Done | Calibration needed per sensor |
| pH measurement | Done | Coarse linear formula, needs calibration |
| Fan control | Done | |
| Heater control | Done | |
| Humidifier control | Done | |
| pH pump (acid/base) | Phase 2 | GPIO pins assigned, logic placeholder |
| EEPROM settings persistence | Phase 2 | `POST /api/settings` is a stub |
| OTA (over-the-air update) | Phase 2 | Not implemented |
| Multiple ESP32 devices | Phase 2 | Single device only |
| Sensor calibration API | Phase 2 | Manual code change + reflash required |
