#ifndef DATA_LOGGER_H
#define DATA_LOGGER_H

void initDataLogger();
void logSensorData();
void saveDataToFile();
String getHistoricalData(int count = 100);
void clearDataLog();
int getDataCount();

#endif // DATA_LOGGER_H
