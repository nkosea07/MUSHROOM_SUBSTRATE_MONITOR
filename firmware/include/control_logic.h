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
