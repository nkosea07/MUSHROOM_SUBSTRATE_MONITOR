#include "api_server.h"
#include "config.h"
#include <WebServer.h>
#include <ArduinoJson.h>
#include <SPIFFS.h>
#include "sensors.h"
#include "control_logic.h"
#include "wifi_manager.h"
#include "data_logger.h"

extern WebServer server;

namespace {
bool parseOnOff(JsonVariantConst value, bool *parsedState) {
  if (value.is<bool>()) {
    *parsedState = value.as<bool>();
    return true;
  }

  if (!value.is<const char*>()) {
    return false;
  }

  String text = value.as<const char*>();
  text.toUpperCase();
  if (text == "ON" || text == "TRUE" || text == "1") {
    *parsedState = true;
    return true;
  }
  if (text == "OFF" || text == "FALSE" || text == "0") {
    *parsedState = false;
    return true;
  }
  return false;
}

void appendAlert(JsonArray alerts, const char *parameter, float value, float minValue, float maxValue) {
  if (value >= minValue && value <= maxValue) {
    return;
  }

  JsonObject alert = alerts.createNestedObject();
  alert["parameter"] = parameter;
  alert["severity"] = "critical";
  alert["value"] = value;
  alert["min"] = minValue;
  alert["max"] = maxValue;
  alert["direction"] = (value < minValue) ? "low" : "high";
}

void appendActiveAlerts(JsonArray alerts) {
  appendAlert(alerts, "temperature", getTemperature(), TEMP_MIN, TEMP_MAX);
  appendAlert(alerts, "moisture", static_cast<float>(getMoisture()), MOISTURE_MIN, MOISTURE_MAX);
  appendAlert(alerts, "ph", getPH(), PH_MIN, PH_MAX);
}
}  // namespace

// API endpoint handlers
void handleRoot() {
  if (!SPIFFS.exists("/index.html")) {
    server.send(500, "text/plain", "Dashboard assets missing from SPIFFS");
    return;
  }

  File file = SPIFFS.open("/index.html", "r");
  if (!file) {
    server.send(500, "text/plain", "Unable to open dashboard file");
    return;
  }

  server.streamFile(file, "text/html");
  file.close();
}

void handleApiData() {
  StaticJsonDocument<1024> doc;
  
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

  JsonObject wifi = doc.createNestedObject("wifi");
  wifi["connected"] = isWiFiConnected();
  wifi["rssi"] = getRSSI();
  wifi["ip"] = getIPAddress();

  JsonArray alerts = doc.createNestedArray("alerts");
  appendActiveAlerts(alerts);
  
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

  // Parse and apply mode first, so mode+manual in one payload works in MANUAL mode.
  if (doc.containsKey("mode")) {
    String mode = doc["mode"].as<String>();
    mode.toUpperCase();

    if (mode == "AUTO") {
      setSystemMode(true);
      runControlLogic();
    } else if (mode == "MANUAL") {
      setSystemMode(false);
    } else {
      server.send(400, "application/json", "{\"error\":\"mode must be AUTO or MANUAL\"}");
      return;
    }
  }

  bool hasManualCommand = doc.containsKey("fan") || doc.containsKey("heater") || doc.containsKey("humidifier");
  if (hasManualCommand && isAutoMode()) {
    server.send(409, "application/json", "{\"error\":\"Manual actuator control requires MANUAL mode\"}");
    return;
  }

  bool parsedState = false;
  if (doc.containsKey("fan")) {
    if (!parseOnOff(doc["fan"], &parsedState)) {
      server.send(400, "application/json", "{\"error\":\"fan must be ON/OFF or true/false\"}");
      return;
    }
    setFan(parsedState);
  }

  if (doc.containsKey("heater")) {
    if (!parseOnOff(doc["heater"], &parsedState)) {
      server.send(400, "application/json", "{\"error\":\"heater must be ON/OFF or true/false\"}");
      return;
    }
    setHeater(parsedState);
  }

  if (doc.containsKey("humidifier")) {
    if (!parseOnOff(doc["humidifier"], &parsedState)) {
      server.send(400, "application/json", "{\"error\":\"humidifier must be ON/OFF or true/false\"}");
      return;
    }
    setHumidifier(parsedState);
  }
  
  StaticJsonDocument<256> response;
  response["success"] = true;
  response["message"] = "Control updated";
  JsonObject status = response.createNestedObject("status");
  status["mode"] = isAutoMode() ? "AUTO" : "MANUAL";
  status["fan"] = isFanOn() ? "ON" : "OFF";
  status["heater"] = isHeaterOn() ? "ON" : "OFF";
  status["humidifier"] = isHumidifierOn() ? "ON" : "OFF";
  
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

void handleApiAlerts() {
  StaticJsonDocument<1024> doc;
  JsonArray alerts = doc.createNestedArray("alerts");
  appendActiveAlerts(alerts);
  doc["count"] = alerts.size();
  doc["timestamp"] = millis();

  String response;
  serializeJson(doc, response);
  server.send(200, "application/json", response);
}

void handleApiHistory() {
  int count = server.hasArg("count") ? server.arg("count").toInt() : 100;
  if (count < 1) {
    count = 1;
  }
  if (count > 500) {
    count = 500;
  }

  String history = getHistoricalData(count);
  server.send(200, "application/json", history);
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
    server.serveStatic("/style.css", SPIFFS, "/style.css");
    server.serveStatic("/script.js", SPIFFS, "/script.js");
  }
  
  // API endpoints
  server.on("/", handleRoot);
  server.on("/api/data", HTTP_GET, handleApiData);
  server.on("/api/alerts", HTTP_GET, handleApiAlerts);
  server.on("/api/history", HTTP_GET, handleApiHistory);
  server.on("/api/control", HTTP_POST, handleApiControl);
  server.on("/api/settings", HTTP_POST, handleApiSettings);
  
  server.onNotFound(handleNotFound);
  
  server.begin();
  Serial.println("HTTP server started on port 80");
}
