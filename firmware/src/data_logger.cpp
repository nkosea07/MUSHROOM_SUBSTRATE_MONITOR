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
