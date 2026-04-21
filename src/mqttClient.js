const mqtt = require('mqtt');
const { insertReading } = require('./database');
const { sendAlert, sendStatusUpdate } = require('./notificationService');

let client = null;
const TOPIC_SENSOR = process.env.MQTT_TOPIC_SENSOR || 'water/sensor/#';

/**
 * Parse MQTT topic to extract device ID.
 * Expected topic pattern: water/sensor/<device_id>
 * e.g.  water/sensor/esp32-001
 */
function extractDeviceId(topic) {
    const parts = topic.split('/');
    return parts[2] || 'unknown';
}

/**
 * Parse incoming MQTT message payload.
 * Expected JSON from ESP32:
 * {
 *   "sensor_min": 280,   // raw ADC/cm value from minimum-level sensor
 *   "sensor_max": 320    // raw ADC/cm value from maximum-level sensor
 * }
 * Status rule: value > 500 => "HIGH", value <= 500 => "LOW"
 */
const THRESHOLD = 500;

function parsePayload(raw) {
    try {
        const json = JSON.parse(raw.toString());
        const sMin = parseFloat(json.sensor_min);
        const sMax = parseFloat(json.sensor_max);
        if (isNaN(sMin) || isNaN(sMax)) return null;
        return {
            sensor_min: sMin,
            sensor_min_status: sMin > THRESHOLD ? 'HIGH' : 'LOW',
            sensor_max: sMax,
            sensor_max_status: sMax > THRESHOLD ? 'HIGH' : 'LOW',
        };
    } catch {
        return null;
    }
}

function connect() {
    const brokerUrl = process.env.MQTT_BROKER || 'mqtt://localhost:1883';
    const clientId = process.env.MQTT_CLIENT_ID || `water-server-${Date.now()}`;

    const options = {
        clientId,
        clean: true,
        reconnectPeriod: 5000,
        connectTimeout: 10000,
    };

    if (process.env.MQTT_USERNAME) options.username = process.env.MQTT_USERNAME;
    if (process.env.MQTT_PASSWORD) options.password = process.env.MQTT_PASSWORD;

    console.log(`[MQTT] Connecting to broker: ${brokerUrl}`);
    client = mqtt.connect(brokerUrl, options);

    client.on('connect', () => {
        console.log(`[MQTT] Connected (clientId: ${clientId})`);
        client.subscribe(TOPIC_SENSOR, { qos: 1 }, (err) => {
            if (err) {
                console.error('[MQTT] Subscribe error:', err.message);
            } else {
                console.log(`[MQTT] Subscribed to: ${TOPIC_SENSOR}`);
            }
        });
    });

    client.on('message', async (topic, message) => {
        const deviceId = extractDeviceId(topic);
        const payload = parsePayload(message);

        if (!payload) {
            console.warn(`[MQTT] Unparseable message on topic "${topic}": ${message.toString()}`);
            return;
        }

        console.log(`[MQTT] Received from ${deviceId}:`, payload);

        try {
            const id = await insertReading(deviceId, payload);
            console.log(`[DB]   Saved reading #${id} for device "${deviceId}"`);

            // Always send silent FCM status update so the app shows realtime data.
            sendStatusUpdate(
                deviceId,
                payload.sensor_min, payload.sensor_min_status,
                payload.sensor_max, payload.sensor_max_status
            ).catch(err => console.error('[STATUS] Failed to send status update:', err.message));

            // Check if alert threshold exceeded — send notification.
            if (payload.sensor_min > THRESHOLD) {
                sendAlert(deviceId, payload.sensor_min, 'HIGH').catch(err =>
                    console.error('[ALERT] Failed to send alert for sensor_min:', err.message)
                );
            }
            if (payload.sensor_max > THRESHOLD) {
                sendAlert(deviceId, payload.sensor_max, 'HIGH').catch(err =>
                    console.error('[ALERT] Failed to send alert for sensor_max:', err.message)
                );
            }

            // broadcast to SSE clients (lazy require to avoid circular dep)
            try { require('../index').broadcastReading(deviceId, payload); } catch (_) { }
        } catch (err) {
            console.error('[DB]   Failed to save reading:', err.message);
        }
    });

    client.on('reconnect', () => console.log('[MQTT] Reconnecting…'));
    client.on('offline', () => console.log('[MQTT] Client offline'));
    client.on('error', (err) => console.error('[MQTT] Error:', err.message));

    return client;
}

function getClient() {
    return client;
}

module.exports = { connect, getClient };
