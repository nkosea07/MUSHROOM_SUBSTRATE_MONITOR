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
