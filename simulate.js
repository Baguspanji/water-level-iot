#!/usr/bin/env node
/**
 * ESP32 Water Sensor Simulator
 * Publishes fake sensor data to the MQTT broker at regular intervals,
 * simulating one or more ESP32 devices.
 *
 * Usage:
 *   node simulate.js [options]
 *
 * Options (all optional, env vars also accepted):
 *   --broker   <url>      MQTT broker URL         (default: from .env or mqtt://localhost:1883)
 *   --devices  <n>        Number of virtual ESP32 devices (default: 2)
 *   --interval <ms>       Publish interval in ms  (default: 3000)
 *   --count    <n>        Total messages per device, 0 = infinite (default: 0)
 *   --scenario <name>     Data scenario: normal | flood | drought | spike (default: normal)
 */

require('dotenv').config();
const mqtt = require('mqtt');

// ── CLI arg parser ────────────────────────────────────────────────
function arg(name, fallback) {
    const idx = process.argv.indexOf(`--${name}`);
    return idx !== -1 ? process.argv[idx + 1] : fallback;
}

const BROKER = arg('broker', process.env.MQTT_BROKER || 'mqtt://localhost:1883');
const DEVICES = parseInt(arg('devices', '3'));
const INTERVAL = parseInt(arg('interval', '3000'));
const COUNT = parseInt(arg('count', '0'));
const SCENARIO = arg('scenario', 'random');

// ── Sensor logic ──────────────────────────────────────────────────
// Aturan:
//   - Jika sensor_min < 500 (LOW)  → sensor_max PASTI juga < 500 (LOW)
//   - Jika sensor_min > 500 (HIGH) → sensor_max BOLEH > 500 atau < 500
//   - Tidak mungkin: sensor_min < 500 tapi sensor_max > 500
const THRESHOLD = 500;

const scenarios = {
    // Keduanya LOW (air tidak ada / sangat rendah)
    both_low: () => {
        const sMin = rand(100, 495);
        return { sensor_min: sMin, sensor_max: rand(100, 495) };
    },
    // Keduanya HIGH (air penuh / banjir)
    both_high: () => ({
        sensor_min: rand(505, 1000),
        sensor_max: rand(505, 1000),
    }),
    // sensor_min HIGH, sensor_max LOW (air di tengah-tengah)
    min_high_max_low: () => ({
        sensor_min: rand(505, 1000),
        sensor_max: rand(100, 495),
    }),
    // Acak, mengikuti aturan di atas
    random: () => {
        const r = Math.random();
        if (r < 0.33) {
            // both LOW
            return { sensor_min: rand(100, 495), sensor_max: rand(100, 495) };
        } else if (r < 0.66) {
            // both HIGH
            return { sensor_min: rand(505, 1000), sensor_max: rand(505, 1000) };
        } else {
            // min HIGH, max LOW
            return { sensor_min: rand(505, 1000), sensor_max: rand(100, 495) };
        }
    },
};

function status(val) {
    return val > THRESHOLD ? 'HIGH' : 'LOW';
}

function rand(min, max) {
    return parseFloat((Math.random() * (max - min) + min).toFixed(1));
}

function buildPayload(deviceIdx) {
    const gen = scenarios[SCENARIO] || scenarios.normal;
    const values = gen();
    return {
        device_id: `esp32-${String(deviceIdx).padStart(3, '0')}`,
        sensor_min: values.sensor_min,
        sensor_min_status: status(values.sensor_min),
        sensor_max: values.sensor_max,
        sensor_max_status: status(values.sensor_max),
    };
}

// ── Connect & simulate ────────────────────────────────────────────
console.log(`\n🔌 ESP32 Simulator`);
console.log(`   Broker   : ${BROKER}`);
console.log(`   Devices  : ${DEVICES}`);
console.log(`   Interval : ${INTERVAL} ms`);
console.log(`   Count    : ${COUNT === 0 ? '∞' : COUNT} messages/device`);
console.log(`   Scenario : ${SCENARIO}\n`);

const client = mqtt.connect(BROKER, {
    clientId: `esp32-simulator-${Date.now()}`,
    clean: true,
    reconnectPeriod: 3000,
    ...(process.env.MQTT_USERNAME && { username: process.env.MQTT_USERNAME }),
    ...(process.env.MQTT_PASSWORD && { password: process.env.MQTT_PASSWORD }),
});

const counters = Array(DEVICES).fill(0);
let timers = [];

client.on('connect', () => {
    console.log('[MQTT] Connected to broker\n');

    for (let i = 1; i <= DEVICES; i++) {
        const deviceIdx = i;
        const topic = `water/sensor/esp32-${String(deviceIdx).padStart(3, '0')}`;

        const t = setInterval(() => {
            if (COUNT > 0 && counters[deviceIdx - 1] >= COUNT) {
                clearInterval(t);
                // Check if all devices done
                if (counters.every((c) => COUNT > 0 && c >= COUNT)) {
                    console.log('\n[Sim] All devices reached message count. Disconnecting…');
                    client.end();
                }
                return;
            }

            const payload = buildPayload(deviceIdx);
            counters[deviceIdx - 1]++;

            client.publish(topic, JSON.stringify(payload), { qos: 1 }, (err) => {
                if (err) {
                    console.error(`[${topic}] Publish error:`, err.message);
                } else {
                    console.log(`[${topic}] #${counters[deviceIdx - 1]}`, JSON.stringify(payload));
                }
            });
        }, INTERVAL + (deviceIdx - 1) * 200); // slight stagger per device

        timers.push(t);
    }
});

client.on('error', (err) => console.error('[MQTT] Error:', err.message));
client.on('offline', () => console.log('[MQTT] Offline'));
client.on('reconnect', () => console.log('[MQTT] Reconnecting…'));

process.on('SIGINT', () => {
    console.log('\n[Sim] Interrupted. Disconnecting…');
    timers.forEach(clearInterval);
    client.end(true, () => process.exit(0));
});
