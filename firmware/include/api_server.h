#ifndef API_SERVER_H
#define API_SERVER_H

void initWebServer();
void handleRoot();
void handleApiData();
void handleApiControl();
void handleApiSettings();
void handleNotFound();

#endif // API_SERVER_H
