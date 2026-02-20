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
