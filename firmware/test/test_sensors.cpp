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
