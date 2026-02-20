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
unsigned long lastSensorUpdate = 0;
unsigned long lastWiFiReconnectCheck = 0;

void handlePeriodicTasks(unsigned long currentMillis) {
  if (currentMillis - lastWiFiReconnectCheck >= WIFI_RECONNECT_INTERVAL) {
    if (!isWiFiConnected()) {
      reconnectWiFi();
    }
    lastWiFiReconnectCheck = currentMillis;
  }
}

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
  setupActuatorPins();
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
    if (isAutoMode()) {
      runControlLogic();
    }
    
    // Log data
    logSensorData();
  }
  
  // Handle other periodic tasks
  handlePeriodicTasks(currentMillis);
}
