#ifndef WIFI_MANAGER_H
#define WIFI_MANAGER_H

void initWiFi();
bool isWiFiConnected();
String getIPAddress();
int getRSSI();
void reconnectWiFi();

#endif // WIFI_MANAGER_H
