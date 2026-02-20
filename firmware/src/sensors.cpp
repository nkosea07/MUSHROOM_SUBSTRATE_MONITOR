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
