#ifndef CONFIG_H
#define CONFIG_H

// WiFi Configuration
#define WIFI_SSID "YOUR_WIFI_SSID"
#define WIFI_PASSWORD "YOUR_WIFI_PASSWORD"

// Pin Definitions
#define TEMP_SENSOR_PIN 4       // DS18B20 Data pin (GPIO4)
#define MOISTURE_SENSOR_PIN 34  // Capacitive sensor (ADC1_CH6)
#define PH_SENSOR_PIN 35        // pH sensor (ADC1_CH7)

#define FAN_PIN 26              // GPIO26 for Fan control
#define HEATER_PIN 27           // GPIO27 for Heater control
#define HUMIDIFIER_PIN 14       // GPIO14 for Humidifier control
#define PUMP_ACID_PIN 12        // GPIO12 for Acid pump (Phase 2)
#define PUMP_BASE_PIN 13        // GPIO13 for Base pump (Phase 2)

// Sensor Calibration
#define MOISTURE_AIR_VALUE 2000     // Value in air (dry) - calibrate!
#define MOISTURE_WATER_VALUE 900    // Value in water (wet) - calibrate!
#define PH_CALIBRATION_OFFSET 0.0   // pH calibration offset

// Control Thresholds
#define TEMP_MIN 22.0           // Minimum temperature (°C)
#define TEMP_MAX 26.0           // Maximum temperature (°C)
#define MOISTURE_MIN 60         // Minimum moisture (%)
#define MOISTURE_MAX 70         // Maximum moisture (%)
#define PH_MIN 6.5              // Minimum pH
#define PH_MAX 7.0              // Maximum pH

// Hysteresis Values
#define TEMP_HYSTERESIS 0.5     // ±0.5°C hysteresis
#define MOISTURE_HYSTERESIS 3   // ±3% hysteresis
#define PH_HYSTERESIS 0.2       // ±0.2 pH hysteresis

// Timing Configuration
#define SENSOR_UPDATE_INTERVAL 30000    // 30 seconds
#define CONTROL_UPDATE_INTERVAL 60000   // 60 seconds
#define DATA_LOG_INTERVAL 300000        // 5 minutes
#define WIFI_RECONNECT_INTERVAL 30000   // 30 seconds

// System Constants
#define MAX_SENSOR_READINGS 100
#define MAX_ALERTS 50
#define MAX_LOG_ENTRIES 1000

// Debug Settings
#define DEBUG_SERIAL true
#define DEBUG_WIFI true
#define DEBUG_SENSORS true

#endif // CONFIG_H
