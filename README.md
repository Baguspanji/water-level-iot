# Water Level Server

Node.js MQTT server that receives water sensor analytics data from ESP32 devices and exposes a REST API for querying historical readings.

## Architecture

```
ESP32 Sensor  ──MQTT──►  MQTT Broker (e.g. Mosquitto)
                                │
                         Node.js Server
                        ┌───────┴────────┐
                    MQTT Subscriber   HTTP API
                        └───────┬────────┘
                            SQLite DB
```

## Prerequisites

- Node.js 18+
- A running MQTT broker (e.g. [Mosquitto](https://mosquitto.org/))

Install Mosquitto on macOS:
```bash
brew install mosquitto
brew services start mosquitto
```

## Setup

```bash
npm install
cp .env .env.local   # edit as needed
npm start
```

## Configuration (`.env`)

| Variable           | Default                     | Description                  |
|--------------------|-----------------------------|------------------------------|
| `MQTT_BROKER`      | `mqtt://localhost:1883`     | Broker URL                   |
| `MQTT_USERNAME`    | _(empty)_                   | Broker username (optional)   |
| `MQTT_PASSWORD`    | _(empty)_                   | Broker password (optional)   |
| `MQTT_CLIENT_ID`   | `water-level-server`        | MQTT client ID               |
| `MQTT_TOPIC_SENSOR`| `water/sensor/#`            | Topic pattern to subscribe   |
| `HTTP_PORT`        | `3000`                      | HTTP API port                |
| `DB_PATH`          | `./data/water_sensor.db`    | SQLite database file path    |

## ESP32 MQTT Topic & Payload

**Topic:** `water/sensor/<device_id>`
Example: `water/sensor/esp32-001`

**JSON Payload:**
```json
{
  "water_level": 85.5,
  "temperature": 28.3,
  "turbidity": 120,
  "ph": 7.2,
  "tds": 450
}
```

All fields are optional — only send what your sensor supports.
A plain numeric string (e.g. `"85.5"`) is also accepted and stored as `water_level`.

### Sample ESP32 Arduino code

```cpp
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

const char* ssid     = "YOUR_SSID";
const char* password = "YOUR_PASS";
const char* mqttHost = "192.168.1.100";  // Server IP
const int   mqttPort = 1883;
const char* deviceId = "esp32-001";

WiFiClient   wifiClient;
PubSubClient mqtt(wifiClient);

void publishSensorData() {
  StaticJsonDocument<128> doc;
  doc["water_level"] = analogRead(34) * (100.0 / 4095.0); // example ADC
  doc["temperature"] = 28.3;  // replace with actual sensor read
  doc["turbidity"]   = 120;
  doc["ph"]          = 7.2;
  doc["tds"]         = 450;

  char buf[128];
  serializeJson(doc, buf);

  char topic[64];
  snprintf(topic, sizeof(topic), "water/sensor/%s", deviceId);
  mqtt.publish(topic, buf);
}

void setup() {
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) delay(500);

  mqtt.setServer(mqttHost, mqttPort);
  while (!mqtt.connected()) mqtt.connect(deviceId);

  // Publish every 5 seconds via loop
}

void loop() {
  mqtt.loop();
  publishSensorData();
  delay(5000);
}
```

## HTTP API

Base URL: `http://localhost:3000`

| Method | Path                        | Description                            |
|--------|-----------------------------|----------------------------------------|
| GET    | `/health`                   | Health check                           |
| GET    | `/api/devices`              | List all devices + stats               |
| GET    | `/api/sensors/latest`       | Latest reading per device              |
| GET    | `/api/sensors`              | All readings (paginated)               |
| GET    | `/api/sensors/:deviceId`    | Readings for a specific device         |

**Query params for paginated endpoints:** `limit` (max 1000), `offset`, `device_id`

### Example

```bash
# Latest readings from all devices
curl http://localhost:3000/api/sensors/latest

# Last 20 readings from esp32-001
curl "http://localhost:3000/api/sensors/esp32-001?limit=20"
```
