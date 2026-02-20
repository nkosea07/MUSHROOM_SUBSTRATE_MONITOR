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
