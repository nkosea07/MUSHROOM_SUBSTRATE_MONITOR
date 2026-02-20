#!/bin/bash

# Create the firmware directory structure
mkdir -p firmware/src
mkdir -p firmware/include
mkdir -p firmware/data
mkdir -p firmware/test

# Create main ESP32 firmware file
cat > firmware/src/main.cpp << 'MAIN_EOF'
/*
  Mushroom Substrate Monitor - Main ESP32 Firmware
  Complete system for monitoring mushroom substrate conditions
*/

#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <ArduinoJson.h>
#include <SPIFFS.h>
#include "config.h"
#include "sensors.h"
#include "wifi_manager.h"
#include "api_server.h"
#include "control_logic.h"
#include "data_logger.h"

// Global objects
WebServer server(80);
OneWire oneWire(TEMP_SENSOR_PIN);
DallasTemperature tempSensors(&oneWire);

// Global variables
float currentTemperature = 0.0;
int currentMoisture = 0;
float currentPH = 7.0;
unsigned long lastSensorUpdate = 0;
bool fanState = false;
bool heaterState = false;
bool humidifierState = false;
bool systemAuto = true;

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n=================================");
  Serial.println("Mushroom Substrate Monitor");
  Serial.println("ESP32 Firmware v1.0");
  Serial.println("=================================\n");
  
  // Initialize components
  initWiFi();
  initSensors();
  initDataLogger();
  initWebServer();
  
  Serial.println("\nSystem initialized successfully!");
  Serial.print("Dashboard URL: http://");
  Serial.println(WiFi.localIP());
}

void loop() {
  server.handleClient();
  
  unsigned long currentMillis = millis();
  
  // Update sensors every SENSOR_UPDATE_INTERVAL
  if (currentMillis - lastSensorUpdate >= SENSOR_UPDATE_INTERVAL) {
    updateAllSensors();
    lastSensorUpdate = currentMillis;
    
    // Run control logic in auto mode
    if (systemAuto) {
      runControlLogic();
    }
    
    // Log data
    logSensorData();
  }
  
  // Handle other periodic tasks
  handlePeriodicTasks(currentMillis);
}
MAIN_EOF

# Create sensors.cpp
cat > firmware/src/sensors.cpp << 'SENSORS_EOF'
#include "sensors.h"
#include "config.h"
#include <OneWire.h>
#include <DallasTemperature.h>

extern OneWire oneWire;
extern DallasTemperature tempSensors;

// Global sensor variables
float currentTemperature = 0.0;
int currentMoisture = 0;
float currentPH = 7.0;

void initSensors() {
  Serial.println("Initializing sensors...");
  
  // Initialize temperature sensor
  tempSensors.begin();
  Serial.printf("Found %d temperature sensor(s)\n", tempSensors.getDeviceCount());
  
  // Initialize moisture sensor pin
  pinMode(MOISTURE_SENSOR_PIN, INPUT);
  
  // Initialize pH sensor pin
  pinMode(PH_SENSOR_PIN, INPUT);
  
  Serial.println("Sensors initialized");
}

void updateAllSensors() {
  readTemperature();
  readMoisture();
  readPH();
}

void readTemperature() {
  tempSensors.requestTemperatures();
  float temp = tempSensors.getTempCByIndex(0);
  
  if (temp != DEVICE_DISCONNECTED_C) {
    // Apply moving average filter
    currentTemperature = (currentTemperature * 0.7) + (temp * 0.3);
    Serial.printf("Temperature: %.2f°C\n", currentTemperature);
  } else {
    Serial.println("ERROR: Temperature sensor disconnected!");
  }
}

void readMoisture() {
  // Read multiple times and average
  int readings = 5;
  long sum = 0;
  
  for (int i = 0; i < readings; i++) {
    sum += analogRead(MOISTURE_SENSOR_PIN);
    delay(10);
  }
  
  int rawValue = sum / readings;
  currentMoisture = calculateMoisturePercentage(rawValue);
  
  Serial.printf("Moisture Raw: %d, Percentage: %d%%\n", rawValue, currentMoisture);
}

int calculateMoisturePercentage(int rawValue) {
  // Map raw value to percentage (inverted because higher raw = drier)
  int percentage = map(rawValue, MOISTURE_AIR_VALUE, MOISTURE_WATER_VALUE, 0, 100);
  
  // Constrain to 0-100%
  percentage = constrain(percentage, 0, 100);
  
  return percentage;
}

void readPH() {
  // Read pH sensor (simplified for MVP)
  int rawValue = analogRead(PH_SENSOR_PIN);
  float voltage = rawValue * (3.3 / 4095.0);
  
  // Simple linear conversion (calibrate properly in production)
  currentPH = 14.0 - (voltage * 3.5);
  currentPH = constrain(currentPH, 0.0, 14.0);
  
  Serial.printf("pH Raw: %d, Voltage: %.2fV, pH: %.2f\n", rawValue, voltage, currentPH);
}

float getTemperature() {
  return currentTemperature;
}

int getMoisture() {
  return currentMoisture;
}

float getPH() {
  return currentPH;
}
SENSORS_EOF

# Create wifi_manager.cpp
cat > firmware/src/wifi_manager.cpp << 'WIFI_EOF'
#include "wifi_manager.h"
#include "config.h"
#include <WiFi.h>
#include <ESPmDNS.h>

void initWiFi() {
  Serial.print("Connecting to WiFi: ");
  Serial.println(WIFI_SSID);
  
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi Connected!");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
    Serial.print("RSSI: ");
    Serial.print(WiFi.RSSI());
    Serial.println(" dBm");
    
    // Initialize mDNS
    if (!MDNS.begin("mushroom-monitor")) {
      Serial.println("Error setting up mDNS responder!");
    } else {
      Serial.println("mDNS responder started");
      MDNS.addService("http", "tcp", 80);
    }
  } else {
    Serial.println("\nERROR: WiFi connection failed!");
    Serial.println("Starting Access Point mode...");
    
    // Start Access Point
    WiFi.softAP("MushroomMonitor", "mushroom123");
    Serial.print("AP IP Address: ");
    Serial.println(WiFi.softAPIP());
  }
}

bool isWiFiConnected() {
  return WiFi.status() == WL_CONNECTED;
}

String getIPAddress() {
  return WiFi.localIP().toString();
}

int getRSSI() {
  return WiFi.RSSI();
}

void reconnectWiFi() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("Reconnecting to WiFi...");
    WiFi.disconnect();
    WiFi.reconnect();
    
    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 20) {
      delay(500);
      Serial.print(".");
      attempts++;
    }
    
    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("\nWiFi reconnected!");
    }
  }
}
WIFI_EOF

# Create api_server.cpp
cat > firmware/src/api_server.cpp << 'API_EOF'
#include "api_server.h"
#include "config.h"
#include <WebServer.h>
#include <ArduinoJson.h>
#include "sensors.h"
#include "control_logic.h"

extern WebServer server;

// API endpoint handlers
void handleRoot() {
  String html = "<html><head><title>Mushroom Monitor</title>";
  html += "<style>";
  html += "body { font-family: Arial, sans-serif; margin: 40px; }";
  html += ".card { border: 1px solid #ddd; padding: 20px; margin: 10px; border-radius: 5px; }";
  html += ".value { font-size: 24px; font-weight: bold; }";
  html += "</style></head>";
  html += "<body>";
  html += "<h1>Mushroom Substrate Monitor</h1>";
  html += "<div class='card'>";
  html += "<h2>Temperature: <span class='value'>" + String(getTemperature(), 1) + "°C</span></h2>";
  html += "</div>";
  html += "<div class='card'>";
  html += "<h2>Moisture: <span class='value'>" + String(getMoisture()) + "%</span></h2>";
  html += "</div>";
  html += "<div class='card'>";
  html += "<h2>pH: <span class='value'>" + String(getPH(), 1) + "</span></h2>";
  html += "</div>";
  html += "<p>Use /api endpoints for programmatic access</p>";
  html += "</body></html>";
  
  server.send(200, "text/html", html);
}

void handleApiData() {
  StaticJsonDocument<512> doc;
  
  doc["timestamp"] = millis();
  doc["temperature"] = getTemperature();
  doc["moisture"] = getMoisture();
  doc["ph"] = getPH();
  
  JsonObject thresholds = doc.createNestedObject("thresholds");
  thresholds["temp_min"] = TEMP_MIN;
  thresholds["temp_max"] = TEMP_MAX;
  thresholds["moisture_min"] = MOISTURE_MIN;
  thresholds["moisture_max"] = MOISTURE_MAX;
  thresholds["ph_min"] = PH_MIN;
  thresholds["ph_max"] = PH_MAX;
  
  JsonObject status = doc.createNestedObject("status");
  status["fan"] = isFanOn() ? "ON" : "OFF";
  status["heater"] = isHeaterOn() ? "ON" : "OFF";
  status["humidifier"] = isHumidifierOn() ? "ON" : "OFF";
  status["mode"] = isAutoMode() ? "AUTO" : "MANUAL";
  
  String response;
  serializeJson(doc, response);
  server.send(200, "application/json", response);
}

void handleApiControl() {
  if (server.method() != HTTP_POST) {
    server.send(405, "application/json", "{\"error\":\"Method not allowed\"}");
    return;
  }
  
  String body = server.arg("plain");
  StaticJsonDocument<256> doc;
  DeserializationError error = deserializeJson(doc, body);
  
  if (error) {
    server.send(400, "application/json", "{\"error\":\"Invalid JSON\"}");
    return;
  }
  
  // Parse control commands
  if (doc.containsKey("mode")) {
    setSystemMode(doc["mode"] == "AUTO");
  }
  
  if (doc.containsKey("fan")) {
    setFan(doc["fan"] == "ON");
  }
  
  if (doc.containsKey("heater")) {
    setHeater(doc["heater"] == "ON");
  }
  
  if (doc.containsKey("humidifier")) {
    setHumidifier(doc["humidifier"] == "ON");
  }
  
  StaticJsonDocument<128> response;
  response["success"] = true;
  response["message"] = "Control updated";
  
  String responseStr;
  serializeJson(response, responseStr);
  server.send(200, "application/json", responseStr);
}

void handleApiSettings() {
  if (server.method() != HTTP_POST) {
    server.send(405, "application/json", "{\"error\":\"Method not allowed\"}");
    return;
  }
  
  String body = server.arg("plain");
  StaticJsonDocument<256> doc;
  DeserializationError error = deserializeJson(doc, body);
  
  if (error) {
    server.send(400, "application/json", "{\"error\":\"Invalid JSON\"}");
    return;
  }
  
  // Update settings (in a real implementation, these would be saved to EEPROM)
  if (doc.containsKey("temp_min")) {
    // TEMP_MIN = doc["temp_min"].as<float>();
  }
  
  StaticJsonDocument<128> response;
  response["success"] = true;
  response["message"] = "Settings updated (simulated)";
  
  String responseStr;
  serializeJson(response, responseStr);
  server.send(200, "application/json", responseStr);
}

void handleNotFound() {
  String message = "File Not Found\n\n";
  message += "URI: ";
  message += server.uri();
  message += "\nMethod: ";
  message += (server.method() == HTTP_GET) ? "GET" : "POST";
  
  server.send(404, "text/plain", message);
}

void initWebServer() {
  // Serve static files from SPIFFS
  if (SPIFFS.begin(true)) {
    server.serveStatic("/", SPIFFS, "/index.html");
    server.serveStatic("/style.css", SPIFFS, "/style.css");
    server.serveStatic("/script.js", SPIFFS, "/script.js");
  }
  
  // API endpoints
  server.on("/", handleRoot);
  server.on("/api/data", HTTP_GET, handleApiData);
  server.on("/api/control", HTTP_POST, handleApiControl);
  server.on("/api/settings", HTTP_POST, handleApiSettings);
  
  server.onNotFound(handleNotFound);
  
  server.begin();
  Serial.println("HTTP server started on port 80");
}
API_EOF

# Create control_logic.cpp
cat > firmware/src/control_logic.cpp << 'CONTROL_EOF'
#include "control_logic.h"
#include "config.h"
#include "sensors.h"

// Control states
bool fanState = false;
bool heaterState = false;
bool humidifierState = false;
bool systemAuto = true;

void runControlLogic() {
  if (!systemAuto) return;
  
  float temp = getTemperature();
  int moisture = getMoisture();
  float ph = getPH();
  
  // Temperature control with hysteresis
  if (temp < (TEMP_MIN - TEMP_HYSTERESIS)) {
    // Too cold - turn on heater, turn off fan
    setHeater(true);
    setFan(false);
  } else if (temp > (TEMP_MAX + TEMP_HYSTERESIS)) {
    // Too hot - turn on fan, turn off heater
    setFan(true);
    setHeater(false);
  } else {
    // Within optimal range - turn everything off
    setHeater(false);
    setFan(false);
  }
  
  // Moisture control
  if (moisture < (MOISTURE_MIN - MOISTURE_HYSTERESIS)) {
    // Too dry - turn on humidifier
    setHumidifier(true);
  } else if (moisture > (MOISTURE_MAX + MOISTURE_HYSTERESIS)) {
    // Too wet - turn off humidifier, turn on fan to dry
    setHumidifier(false);
    if (!fanState) {
      setFan(true);
    }
  } else {
    // Within optimal range
    setHumidifier(false);
  }
  
  // pH control (simplified - will be enhanced with pumps in Phase 2)
  if (ph < (PH_MIN - PH_HYSTERESIS)) {
    // pH too low (acidic)
    Serial.println("WARNING: pH too low. Manual adjustment needed.");
  } else if (ph > (PH_MAX + PH_HYSTERESIS)) {
    // pH too high (alkaline)
    Serial.println("WARNING: pH too high. Manual adjustment needed.");
  }
}

void setFan(bool state) {
  if (fanState != state) {
    fanState = state;
    digitalWrite(FAN_PIN, fanState ? LOW : HIGH); // Active LOW relay
    Serial.printf("Fan %s\n", fanState ? "ON" : "OFF");
  }
}

void setHeater(bool state) {
  if (heaterState != state) {
    heaterState = state;
    digitalWrite(HEATER_PIN, heaterState ? LOW : HIGH); // Active LOW relay
    Serial.printf("Heater %s\n", heaterState ? "ON" : "OFF");
  }
}

void setHumidifier(bool state) {
  if (humidifierState != state) {
    humidifierState = state;
    digitalWrite(HUMIDIFIER_PIN, humidifierState ? LOW : HIGH); // Active LOW relay
    Serial.printf("Humidifier %s\n", humidifierState ? "ON" : "OFF");
  }
}

void setSystemMode(bool autoMode) {
  systemAuto = autoMode;
  Serial.printf("System mode: %s\n", systemAuto ? "AUTO" : "MANUAL");
}

bool isFanOn() {
  return fanState;
}

bool isHeaterOn() {
  return heaterState;
}

bool isHumidifierOn() {
  return humidifierState;
}

bool isAutoMode() {
  return systemAuto;
}

void setupActuatorPins() {
  pinMode(FAN_PIN, OUTPUT);
  pinMode(HEATER_PIN, OUTPUT);
  pinMode(HUMIDIFIER_PIN, OUTPUT);
  
  // Turn all actuators off initially
  digitalWrite(FAN_PIN, HIGH);
  digitalWrite(HEATER_PIN, HIGH);
  digitalWrite(HUMIDIFIER_PIN, HIGH);
  
  Serial.println("Actuator pins initialized");
}
CONTROL_EOF

# Create data_logger.cpp
cat > firmware/src/data_logger.cpp << 'LOGGER_EOF'
#include "data_logger.h"
#include "config.h"
#include "sensors.h"
#include <SPIFFS.h>
#include <ArduinoJson.h>

#define MAX_DATA_POINTS 1000
#define LOG_FILE "/sensor_data.json"

// Circular buffer for data logging
struct DataPoint {
  unsigned long timestamp;
  float temperature;
  int moisture;
  float ph;
};

DataPoint dataBuffer[MAX_DATA_POINTS];
int dataIndex = 0;
int dataCount = 0;

void initDataLogger() {
  Serial.println("Initializing data logger...");
  
  if (!SPIFFS.begin(true)) {
    Serial.println("ERROR: SPIFFS initialization failed!");
    return;
  }
  
  // Initialize data buffer
  for (int i = 0; i < MAX_DATA_POINTS; i++) {
    dataBuffer[i] = {0, 0.0, 0, 7.0};
  }
  
  Serial.println("Data logger initialized");
}

void logSensorData() {
  unsigned long currentTime = millis();
  
  // Store data in buffer
  dataBuffer[dataIndex].timestamp = currentTime;
  dataBuffer[dataIndex].temperature = getTemperature();
  dataBuffer[dataIndex].moisture = getMoisture();
  dataBuffer[dataIndex].ph = getPH();
  
  // Update indices
  dataIndex = (dataIndex + 1) % MAX_DATA_POINTS;
  if (dataCount < MAX_DATA_POINTS) {
    dataCount++;
  }
  
  // Save to file every 10 data points
  if (dataIndex % 10 == 0) {
    saveDataToFile();
  }
}

void saveDataToFile() {
  File file = SPIFFS.open(LOG_FILE, "w");
  if (!file) {
    Serial.println("ERROR: Failed to open log file for writing");
    return;
  }
  
  StaticJsonDocument<4096> doc;
  JsonArray dataArray = doc.createNestedArray("data");
  
  int startIndex = (dataIndex - dataCount + MAX_DATA_POINTS) % MAX_DATA_POINTS;
  
  for (int i = 0; i < dataCount; i++) {
    int idx = (startIndex + i) % MAX_DATA_POINTS;
    JsonObject dataPoint = dataArray.createNestedObject();
    dataPoint["timestamp"] = dataBuffer[idx].timestamp;
    dataPoint["temperature"] = dataBuffer[idx].temperature;
    dataPoint["moisture"] = dataBuffer[idx].moisture;
    dataPoint["ph"] = dataBuffer[idx].ph;
  }
  
  doc["count"] = dataCount;
  doc["last_update"] = millis();
  
  serializeJson(doc, file);
  file.close();
  
  Serial.printf("Saved %d data points to file\n", dataCount);
}

String getHistoricalData(int count) {
  if (count > dataCount) count = dataCount;
  
  StaticJsonDocument<8192> doc;
  JsonArray timestamps = doc.createNestedArray("timestamps");
  JsonArray temperatures = doc.createNestedArray("temperatures");
  JsonArray moistures = doc.createNestedArray("moistures");
  JsonArray phValues = doc.createNestedArray("ph_values");
  
  int startIndex = (dataIndex - count + MAX_DATA_POINTS) % MAX_DATA_POINTS;
  
  for (int i = 0; i < count; i++) {
    int idx = (startIndex + i) % MAX_DATA_POINTS;
    timestamps.add(dataBuffer[idx].timestamp);
    temperatures.add(dataBuffer[idx].temperature);
    moistures.add(dataBuffer[idx].moisture);
    phValues.add(dataBuffer[idx].ph);
  }
  
  doc["count"] = count;
  doc["current_index"] = dataIndex;
  
  String output;
  serializeJson(doc, output);
  return output;
}

void clearDataLog() {
  dataIndex = 0;
  dataCount = 0;
  
  for (int i = 0; i < MAX_DATA_POINTS; i++) {
    dataBuffer[i] = {0, 0.0, 0, 7.0};
  }
  
  if (SPIFFS.exists(LOG_FILE)) {
    SPIFFS.remove(LOG_FILE);
  }
  
  Serial.println("Data log cleared");
}

int getDataCount() {
  return dataCount;
}
LOGGER_EOF

# Create config.h
cat > firmware/include/config.h << 'CONFIG_EOF'
#ifndef CONFIG_H
#define CONFIG_H

// WiFi Configuration
#define WIFI_SSID "YOUR_WIFI_SSID"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"

// Pin Definitions
#define TEMP_SENSOR_PIN 4       // DS18B20 Data pin (GPIO4)
#define MOISTURE_SENSOR_PIN 34  // Capacitive sensor (ADC1_CH6)
#define PH_SENSOR_PIN 35        // pH sensor (ADC1_CH7)

#define FAN_PIN 26              // GPIO26 for Fan control
#define HEATER_PIN 27           // GPIO27 for Heater control
#define HUMIDIFIER_PIN 14       // GPIO14 for Humidifier control
#define PUMP_ACID_PIN 12        // GPIO12 for Acid pump (Phase 2)
#define PUMP_BASE_PIN 13        // GPIO13 for Base pump (Phase 2)

// Sensor Calibration
#define MOISTURE_AIR_VALUE 2000     // Value in air (dry) - calibrate!
#define MOISTURE_WATER_VALUE 900    // Value in water (wet) - calibrate!
#define PH_CALIBRATION_OFFSET 0.0   // pH calibration offset

// Control Thresholds
#define TEMP_MIN 22.0           // Minimum temperature (°C)
#define TEMP_MAX 26.0           // Maximum temperature (°C)
#define MOISTURE_MIN 60         // Minimum moisture (%)
#define MOISTURE_MAX 70         // Maximum moisture (%)
#define PH_MIN 6.5              // Minimum pH
#define PH_MAX 7.0              // Maximum pH

// Hysteresis Values
#define TEMP_HYSTERESIS 0.5     // ±0.5°C hysteresis
#define MOISTURE_HYSTERESIS 3   // ±3% hysteresis
#define PH_HYSTERESIS 0.2       // ±0.2 pH hysteresis

// Timing Configuration
#define SENSOR_UPDATE_INTERVAL 30000    // 30 seconds
#define CONTROL_UPDATE_INTERVAL 60000   // 60 seconds
#define DATA_LOG_INTERVAL 300000        // 5 minutes
#define WIFI_RECONNECT_INTERVAL 30000   // 30 seconds

// System Constants
#define MAX_SENSOR_READINGS 100
#define MAX_ALERTS 50
#define MAX_LOG_ENTRIES 1000

// Debug Settings
#define DEBUG_SERIAL true
#define DEBUG_WIFI true
#define DEBUG_SENSORS true

#endif // CONFIG_H
CONFIG_EOF

# Create all header files
cat > firmware/include/sensors.h << 'SENSORS_H_EOF'
#ifndef SENSORS_H
#define SENSORS_H

void initSensors();
void updateAllSensors();
void readTemperature();
void readMoisture();
void readPH();
int calculateMoisturePercentage(int rawValue);
float getTemperature();
int getMoisture();
float getPH();

#endif // SENSORS_H
SENSORS_H_EOF

cat > firmware/include/wifi_manager.h << 'WIFI_H_EOF'
#ifndef WIFI_MANAGER_H
#define WIFI_MANAGER_H

void initWiFi();
bool isWiFiConnected();
String getIPAddress();
int getRSSI();
void reconnectWiFi();

#endif // WIFI_MANAGER_H
WIFI_H_EOF

cat > firmware/include/api_server.h << 'API_H_EOF'
#ifndef API_SERVER_H
#define API_SERVER_H

void initWebServer();
void handleRoot();
void handleApiData();
void handleApiControl();
void handleApiSettings();
void handleNotFound();

#endif // API_SERVER_H
API_H_EOF

cat > firmware/include/control_logic.h << 'CONTROL_H_EOF'
#ifndef CONTROL_LOGIC_H
#define CONTROL_LOGIC_H

void runControlLogic();
void setFan(bool state);
void setHeater(bool state);
void setHumidifier(bool state);
void setSystemMode(bool autoMode);
bool isFanOn();
bool isHeaterOn();
bool isHumidifierOn();
bool isAutoMode();
void setupActuatorPins();

#endif // CONTROL_LOGIC_H
CONTROL_H_EOF

cat > firmware/include/data_logger.h << 'LOGGER_H_EOF'
#ifndef DATA_LOGGER_H
#define DATA_LOGGER_H

void initDataLogger();
void logSensorData();
void saveDataToFile();
String getHistoricalData(int count = 100);
void clearDataLog();
int getDataCount();

#endif // DATA_LOGGER_H
LOGGER_H_EOF

# Create PlatformIO configuration
cat > firmware/platformio.ini << 'PLATFORMIO_EOF'
[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino
monitor_speed = 115200
upload_speed = 921600

; Libraries
lib_deps = 
    bblanchon/ArduinoJson@^6.21.3
    milesburton/DallasTemperature@^3.11.0
    paulstoffregen/OneWire@^2.3.7

; Build flags
build_flags = 
    -Wl,-Tesp32.rom.ld
    -Wl,-Tesp32.rom.libgcc.ld
    -Wl,-Tesp32.rom.spiram_incompatible_fns.ld

; Upload using SPIFFS
board_build.filesystem = spiffs
board_build.partitions = default_8MB.csv
board_build.spiffs_start = 0x290000
board_build.spiffs_end = 0x3F0000

; Monitor configuration
monitor_filters = 
    log2file
    esp32_exception_decoder
    time
PLATFORMIO_EOF

# Create test files
cat > firmware/test/test_sensors.cpp << 'TEST_EOF'
// Test file for sensor functions
#include <Arduino.h>
#include "sensors.h"

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("Starting sensor tests...");
  
  initSensors();
}

void loop() {
  updateAllSensors();
  
  Serial.printf("Temp: %.2f°C, Moisture: %d%%, pH: %.2f\n", 
                getTemperature(), getMoisture(), getPH());
  
  delay(5000);
}
TEST_EOF

# Create the web dashboard files for SPIFFS
cat > firmware/data/index.html << 'HTML_EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Mushroom Monitor - ESP32 Dashboard</title>
    <link rel="stylesheet" href="style.css">
    <script src="script.js" defer></script>
</head>
<body>
    <div class="container">
        <header class="header">
            <h1>🍄 Mushroom Substrate Monitor</h1>
            <div class="subtitle">ESP32 Local Dashboard</div>
            <div class="status-bar">
                <span id="wifi-status" class="status-connected">Connected</span>
                <span id="last-update">Last Update: --:--:--</span>
            </div>
        </header>

        <main class="dashboard">
            <div class="sensor-grid">
                <div class="card temperature-card">
                    <h2>🌡️ Temperature</h2>
                    <div class="value-large" id="temp-value">--.-°C</div>
                    <div class="range">Range: <span id="temp-range">22-26°C</span></div>
                    <div class="status" id="temp-status">--</div>
                </div>

                <div class="card moisture-card">
                    <h2>💧 Moisture</h2>
                    <div class="value-large" id="moisture-value">--%</div>
                    <div class="range">Range: <span id="moisture-range">60-70%</span></div>
                    <div class="status" id="moisture-status">--</div>
                </div>

                <div class="card ph-card">
                    <h2>🧪 pH Level</h2>
                    <div class="value-large" id="ph-value">-.--</div>
                    <div class="range">Range: <span id="ph-range">6.5-7.0</span></div>
                    <div class="status" id="ph-status">--</div>
                </div>
            </div>

            <div class="control-section">
                <div class="card">
                    <h2>⚙️ Control Panel</h2>
                    <div class="mode-selector">
                        <button id="mode-auto" class="btn active">AUTO</button>
                        <button id="mode-manual" class="btn">MANUAL</button>
                    </div>
                    
                    <div class="actuator-controls" id="manual-controls" style="display: none;">
                        <div class="actuator-row">
                            <span>Fan:</span>
                            <button id="fan-btn" class="actuator-btn off">OFF</button>
                        </div>
                        <div class="actuator-row">
                            <span>Heater:</span>
                            <button id="heater-btn" class="actuator-btn off">OFF</button>
                        </div>
                        <div class="actuator-row">
                            <span>Humidifier:</span>
                            <button id="humidifier-btn" class="actuator-btn off">OFF</button>
                        </div>
                    </div>
                    
                    <button id="refresh-btn" class="btn refresh">Refresh Data</button>
                </div>

                <div class="card">
                    <h2>🔄 System Status</h2>
                    <div class="status-list">
                        <div class="status-item">
                            <span>Fan:</span>
                            <span id="system-fan" class="status-off">OFF</span>
                        </div>
                        <div class="status-item">
                            <span>Heater:</span>
                            <span id="system-heater" class="status-off">OFF</span>
                        </div>
                        <div class="status-item">
                            <span>Humidifier:</span>
                            <span id="system-humidifier" class="status-off">OFF</span>
                        </div>
                        <div class="status-item">
                            <span>Mode:</span>
                            <span id="system-mode" class="status-auto">AUTO</span>
                        </div>
                    </div>
                </div>
            </div>

            <div class="card alerts-card">
                <h2>⚠️ Alerts</h2>
                <div class="alerts-list" id="alerts-list">
                    <div class="alert info">System initialized</div>
                </div>
            </div>
        </main>

        <footer class="footer">
            <div class="info">
                <span>ESP32 IP: <span id="esp-ip">192.168.1.100</span></span>
                <span>Signal: <span id="wifi-rssi">-65</span> dBm</span>
                <span>Uptime: <span id="uptime">00:00:00</span></span>
            </div>
        </footer>
    </div>
</body>
</html>
HTML_EOF

cat > firmware/data/style.css << 'CSS_EOF'
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    min-height: 100vh;
    padding: 20px;
    color: #333;
}

.container {
    max-width: 1200px;
    margin: 0 auto;
    background: white;
    border-radius: 20px;
    box-shadow: 0 20px 40px rgba(0,0,0,0.1);
    overflow: hidden;
}

.header {
    background: linear-gradient(135deg, #2c3e50 0%, #3498db 100%);
    color: white;
    padding: 30px;
    text-align: center;
}

.header h1 {
    font-size: 2.5rem;
    margin-bottom: 10px;
    font-weight: 600;
}

.subtitle {
    font-size: 1.2rem;
    opacity: 0.9;
    margin-bottom: 20px;
}

.status-bar {
    display: flex;
    justify-content: space-between;
    background: rgba(255,255,255,0.1);
    padding: 10px 20px;
    border-radius: 10px;
    font-size: 0.9rem;
}

.status-connected {
    color: #2ecc71;
    font-weight: 500;
}

.dashboard {
    padding: 30px;
}

.sensor-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 25px;
    margin-bottom: 30px;
}

.card {
    background: white;
    border-radius: 15px;
    padding: 25px;
    box-shadow: 0 10px 20px rgba(0,0,0,0.05);
    transition: transform 0.3s ease, box-shadow 0.3s ease;
    border: 1px solid #e0e0e0;
}

.card:hover {
    transform: translateY(-5px);
    box-shadow: 0 15px 30px rgba(0,0,0,0.1);
}

.card h2 {
    color: #2c3e50;
    margin-bottom: 20px;
    font-size: 1.3rem;
    border-bottom: 2px solid #f0f0f0;
    padding-bottom: 10px;
}

.value-large {
    font-size: 3.5rem;
    font-weight: 700;
    margin: 20px 0;
    text-align: center;
}

.temperature-card .value-large { color: #e74c3c; }
.moisture-card .value-large { color: #3498db; }
.ph-card .value-large { color: #9b59b6; }

.range {
    font-size: 1rem;
    color: #666;
    text-align: center;
    margin: 10px 0;
}

.status {
    font-size: 1.1rem;
    font-weight: 500;
    padding: 8px 15px;
    border-radius: 20px;
    text-align: center;
    display: inline-block;
    width: 100%;
}

.status-optimal { background: #d4edda; color: #155724; }
.status-warning { background: #fff3cd; color: #856404; }
.status-critical { background: #f8d7da; color: #721c24; }

.control-section {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 25px;
    margin-bottom: 30px;
}

.mode-selector {
    display: flex;
    gap: 10px;
    margin: 20px 0;
}

.btn {
    flex: 1;
    padding: 12px;
    border: none;
    border-radius: 10px;
    background: #e0e0e0;
    color: #666;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.3s ease;
}

.btn.active {
    background: #3498db;
    color: white;
    box-shadow: 0 5px 15px rgba(52, 152, 219, 0.3);
}

.btn.refresh {
    background: #2ecc71;
    color: white;
    width: 100%;
    margin-top: 20px;
    font-size: 1.1rem;
}

.actuator-controls {
    margin-top: 20px;
    padding-top: 20px;
    border-top: 2px solid #f0f0f0;
}

.actuator-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 10px 0;
    border-bottom: 1px solid #f0f0f0;
}

.actuator-btn {
    padding: 8px 20px;
    border: none;
    border-radius: 8px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.3s ease;
}

.actuator-btn.on {
    background: #2ecc71;
    color: white;
}

.actuator-btn.off {
    background: #e74c3c;
    color: white;
}

.status-list {
    display: flex;
    flex-direction: column;
    gap: 15px;
}

.status-item {
    display: flex;
    justify-content: space-between;
    padding: 10px 0;
    border-bottom: 1px solid #f0f0f0;
}

.status-on { color: #2ecc71; font-weight: 600; }
.status-off { color: #e74c3c; font-weight: 600; }
.status-auto { color: #3498db; font-weight: 600; }

.alerts-card {
    grid-column: 1 / -1;
}

.alerts-list {
    max-height: 200px;
    overflow-y: auto;
}

.alert {
    padding: 12px;
    margin: 8px 0;
    border-radius: 8px;
    font-size: 0.9rem;
    border-left: 4px solid;
}

.alert.info {
    background: #d1ecf1;
    border-left-color: #3498db;
    color: #0c5460;
}

.alert.warning {
    background: #fff3cd;
    border-left-color: #f39c12;
    color: #856404;
}

.alert.critical {
    background: #f8d7da;
    border-left-color: #e74c3c;
    color: #721c24;
}

.footer {
    background: #f8f9fa;
    padding: 20px 30px;
    border-top: 1px solid #e0e0e0;
    text-align: center;
}

.info {
    display: flex;
    justify-content: center;
    gap: 30px;
    flex-wrap: wrap;
    color: #666;
    font-size: 0.9rem;
}

@media (max-width: 768px) {
    .sensor-grid,
    .control-section {
        grid-template-columns: 1fr;
    }
    
    .header h1 {
        font-size: 2rem;
    }
    
    .value-large {
        font-size: 3rem;
    }
}
CSS_EOF

cat > firmware/data/script.js << 'JS_EOF'
class MushroomDashboard {
    constructor() {
        this.apiBase = '/api';
        this.refreshInterval = 5000; // 5 seconds
        this.refreshTimer = null;
        this.startTime = Date.now();
        
        this.init();
    }
    
    init() {
        console.log('Initializing Mushroom Dashboard...');
        
        // Load initial data
        this.fetchData();
        
        // Setup event listeners
        this.setupEventListeners();
        
        // Start auto-refresh
        this.startAutoRefresh();
        
        // Update uptime every second
        setInterval(() => this.updateUptime(), 1000);
    }
    
    async fetchData() {
        try {
            const response = await fetch(`${this.apiBase}/data`);
            if (!response.ok) throw new Error(`HTTP ${response.status}`);
            
            const data = await response.json();
            this.updateDashboard(data);
            this.updateLastUpdateTime();
            
        } catch (error) {
            console.error('Error fetching data:', error);
            this.addAlert(`Connection error: ${error.message}`, 'critical');
            document.getElementById('wifi-status').className = 'status-critical';
            document.getElementById('wifi-status').textContent = 'Disconnected';
        }
    }
    
    updateDashboard(data) {
        // Update temperature
        const temp = data.temperature || 0;
        const tempMin = data.thresholds?.temp_min || 22;
        const tempMax = data.thresholds?.temp_max || 26;
        
        document.getElementById('temp-value').textContent = `${temp.toFixed(1)}°C`;
        this.updateStatus('temp', temp, tempMin, tempMax);
        document.getElementById('temp-range').textContent = `${tempMin}-${tempMax}°C`;
        
        // Update moisture
        const moisture = data.moisture || 0;
        const moistureMin = data.thresholds?.moisture_min || 60;
        const moistureMax = data.thresholds?.moisture_max || 70;
        
        document.getElementById('moisture-value').textContent = `${moisture}%`;
        this.updateStatus('moisture', moisture, moistureMin, moistureMax);
        document.getElementById('moisture-range').textContent = `${moistureMin}-${moistureMax}%`;
        
        // Update pH
        const ph = data.ph || 7.0;
        const phMin = data.thresholds?.ph_min || 6.5;
        const phMax = data.thresholds?.ph_max || 7.0;
        
        document.getElementById('ph-value').textContent = ph.toFixed(2);
        this.updateStatus('ph', ph, phMin, phMax);
        document.getElementById('ph-range').textContent = `${phMin}-${phMax}`;
        
        // Update system status
        document.getElementById('system-fan').textContent = data.status?.fan || 'OFF';
        document.getElementById('system-fan').className = 
            data.status?.fan === 'ON' ? 'status-on' : 'status-off';
            
        document.getElementById('system-heater').textContent = data.status?.heater || 'OFF';
        document.getElementById('system-heater').className = 
            data.status?.heater === 'ON' ? 'status-on' : 'status-off';
            
        document.getElementById('system-humidifier').textContent = data.status?.humidifier || 'OFF';
        document.getElementById('system-humidifier').className = 
            data.status?.humidifier === 'ON' ? 'status-on' : 'status-off';
            
        document.getElementById('system-mode').textContent = data.status?.mode || 'AUTO';
        document.getElementById('system-mode').className = 'status-auto';
        
        // Update WiFi info
        if (data.wifi) {
            document.getElementById('wifi-rssi').textContent = data.wifi.rssi || '-';
            document.getElementById('esp-ip').textContent = data.wifi.ip || 'Unknown';
        }
    }
    
    updateStatus(type, value, min, max) {
        const element = document.getElementById(`${type}-status`);
        
        if (value < min) {
            element.textContent = 'TOO LOW';
            element.className = 'status-critical';
            this.addAlert(`${type.charAt(0).toUpperCase() + type.slice(1)} too low: ${value}`, 'critical');
        } else if (value > max) {
            element.textContent = 'TOO HIGH';
            element.className = 'status-critical';
            this.addAlert(`${type.charAt(0).toUpperCase() + type.slice(1)} too high: ${value}`, 'critical');
        } else if (value >= min && value <= max) {
            element.textContent = 'OPTIMAL';
            element.className = 'status-optimal';
        } else {
            element.textContent = 'UNKNOWN';
            element.className = '';
        }
    }
    
    async sendControl(command) {
        try {
            const response = await fetch(`${this.apiBase}/control`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(command)
            });
            
            if (!response.ok) throw new Error(`HTTP ${response.status}`);
            
            this.addAlert(`Control command sent: ${JSON.stringify(command)}`, 'info');
            this.fetchData(); // Refresh data
            
        } catch (error) {
            console.error('Error sending control:', error);
            this.addAlert(`Control failed: ${error.message}`, 'critical');
        }
    }
    
    addAlert(message, type = 'info') {
        const alertsList = document.getElementById('alerts-list');
        const alertDiv = document.createElement('div');
        alertDiv.className = `alert ${type}`;
        
        const time = new Date().toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'});
        alertDiv.textContent = `[${time}] ${message}`;
        
        alertsList.insertBefore(alertDiv, alertsList.firstChild);
        
        // Limit to 10 alerts
        while (alertsList.children.length > 10) {
            alertsList.removeChild(alertsList.lastChild);
        }
        
        // Auto-remove after 30 seconds for non-critical alerts
        if (type !== 'critical') {
            setTimeout(() => {
                if (alertDiv.parentNode) {
                    alertDiv.style.opacity = '0.5';
                    setTimeout(() => {
                        if (alertDiv.parentNode) {
                            alertsList.removeChild(alertDiv);
                        }
                    }, 1000);
                }
            }, 30000);
        }
    }
    
    updateLastUpdateTime() {
        const now = new Date();
        const timeString = now.toLocaleTimeString([], {hour: '2-digit', minute:'2-digit', second:'2-digit'});
        document.getElementById('last-update').textContent = `Last Update: ${timeString}`;
    }
    
    updateUptime() {
        const elapsed = Date.now() - this.startTime;
        const hours = Math.floor(elapsed / 3600000);
        const minutes = Math.floor((elapsed % 3600000) / 60000);
        const seconds = Math.floor((elapsed % 60000) / 1000);
        
        document.getElementById('uptime').textContent = 
            `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
    }
    
    startAutoRefresh() {
        if (this.refreshTimer) {
            clearInterval(this.refreshTimer);
        }
        
        this.refreshTimer = setInterval(() => {
            this.fetchData();
        }, this.refreshInterval);
    }
    
    setupEventListeners() {
        // Mode selector
        document.getElementById('mode-auto').addEventListener('click', () => {
            document.getElementById('mode-auto').classList.add('active');
            document.getElementById('mode-manual').classList.remove('active');
            document.getElementById('manual-controls').style.display = 'none';
            this.sendControl({ mode: 'AUTO' });
        });
        
        document.getElementById('mode-manual').addEventListener('click', () => {
            document.getElementById('mode-manual').classList.add('active');
            document.getElementById('mode-auto').classList.remove('active');
            document.getElementById('manual-controls').style.display = 'block';
            this.sendControl({ mode: 'MANUAL' });
        });
        
        // Actuator buttons
        document.getElementById('fan-btn').addEventListener('click', (e) => {
            const isOn = e.target.classList.contains('on');
            const newState = !isOn;
            e.target.textContent = newState ? 'ON' : 'OFF';
            e.target.className = `actuator-btn ${newState ? 'on' : 'off'}`;
            this.sendControl({ fan: newState ? 'ON' : 'OFF' });
        });
        
        document.getElementById('heater-btn').addEventListener('click', (e) => {
            const isOn = e.target.classList.contains('on');
            const newState = !isOn;
            e.target.textContent = newState ? 'ON' : 'OFF';
            e.target.className = `actuator-btn ${newState ? 'on' : 'off'}`;
            this.sendControl({ heater: newState ? 'ON' : 'OFF' });
        });
        
        document.getElementById('humidifier-btn').addEventListener('click', (e) => {
            const isOn = e.target.classList.contains('on');
            const newState = !isOn;
            e.target.textContent = newState ? 'ON' : 'OFF';
            e.target.className = `actuator-btn ${newState ? 'on' : 'off'}`;
            this.sendControl({ humidifier: newState ? 'ON' : 'OFF' });
        });
        
        // Refresh button
        document.getElementById('refresh-btn').addEventListener('click', () => {
            this.fetchData();
        });
    }
}

// Initialize dashboard when page loads
document.addEventListener('DOMContentLoaded', () => {
    new MushroomDashboard();
});
JS_EOF

echo "✅ All firmware files created successfully!"
echo ""
echo "📁 Directory structure created:"
echo "firmware/"
echo "├── src/"
echo "│   ├── main.cpp"
echo "│   ├── sensors.cpp"
echo "│   ├── wifi_manager.cpp"
echo "│   ├── api_server.cpp"
echo "│   ├── control_logic.cpp"
echo "│   └── data_logger.cpp"
echo "├── include/"
echo "│   ├── config.h"
echo "│   ├── sensors.h"
echo "│   ├── wifi_manager.h"
echo "│   ├── api_server.h"
echo "│   ├── control_logic.h"
echo "│   └── data_logger.h"
echo "├── data/"
echo "│   ├── index.html"
echo "│   ├── style.css"
echo "│   └── script.js"
echo "├── test/"
echo "│   └── test_sensors.cpp"
echo "└── platformio.ini"
echo ""
echo "📋 Next steps:"
echo "1. Update WiFi credentials in firmware/include/config.h"
echo "2. Upload files to ESP32 using PlatformIO:"
echo "   cd firmware && pio run --target upload"
echo "3. Upload web files to SPIFFS:"
echo "   pio run --target uploadfs"
echo "4. Access dashboard at http://[ESP32_IP]/"
echo ""
echo "🔧 To compile and upload:"
echo "cd firmware"
echo "pio run --target upload      # Upload firmware"
echo "pio run --target uploadfs    # Upload web files"
echo "pio device monitor           # View serial output"