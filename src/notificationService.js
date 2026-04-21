const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, '../serviceAccountKey.json');
let initialized = false;

function initializeFirebase() {
  if (initialized) return;

  try {
    admin.initializeApp({
      credential: admin.credential.cert(require(serviceAccountPath)),
    });
    initialized = true;
    console.log('Firebase Admin initialized');
  } catch (error) {
    console.error('Firebase Admin init failed:', error.message);
    console.log('Note: Ensure serviceAccountKey.json exists in project root');
  }
}

// Cooldown map: { device_id: lastSentTimestamp }
const cooldownMap = new Map();
const COOLDOWN_MS = 60 * 1000; // 60 seconds

/**
 * Send alert notification via FCM topic
 * @param {string} deviceId - Device ID
 * @param {number} value - Sensor value
 * @param {string} status - Sensor status (HIGH/LOW)
 * @returns {Promise<boolean>} - true if sent, false if cooldown
 */
async function sendAlert(deviceId, value, status) {
  initializeFirebase();

  // Check cooldown
  const now = Date.now();
  const lastSent = cooldownMap.get(deviceId);

  if (lastSent && (now - lastSent) < COOLDOWN_MS) {
    console.log(`[FCM] Cooldown active for ${deviceId}, skipping (${Math.round((COOLDOWN_MS - (now - lastSent)) / 1000)}s remaining)`);
    return false;
  }

  try {
    // Update cooldown
    cooldownMap.set(deviceId, now);

    // Build message
    const message = {
      notification: {
        title: '⚠️ Sensor Bahaya!',
        body: `Device ${deviceId}: nilai sensor ${value} (${status})`,
      },
      data: {
        type: 'alert',
        device_id: deviceId,
        value: String(value),
        status: status,
        timestamp: new Date().toISOString(),
      },
      android: {
        priority: 'high',
        notification: {
          channel_id: 'water_alert_channel',
          sound: 'default',
        },
      },
      topic: 'water_alert',
    };

    // Send to topic
    const response = await admin.messaging().send(message);
    console.log(`[FCM] Alert sent to topic 'water_alert' for ${deviceId}: ${response}`);
    return true;
  } catch (error) {
    console.error(`[FCM] Failed to send alert for ${deviceId}:`, error.message);
    // Reset cooldown on error so retry can happen
    cooldownMap.delete(deviceId);
    return false;
  }
}

module.exports = { sendAlert, sendStatusUpdate, initializeFirebase };

/**
 * Send a silent FCM data-only message with current sensor status.
 * No `notification` key = no system notification shown, app handles it silently.
 *
 * @param {string} deviceId
 * @param {number} sensorMin
 * @param {string} sensorMinStatus  'HIGH' | 'LOW'
 * @param {number} sensorMax
 * @param {string} sensorMaxStatus  'HIGH' | 'LOW'
 */
async function sendStatusUpdate(deviceId, sensorMin, sensorMinStatus, sensorMax, sensorMaxStatus) {
  initializeFirebase();
  try {
    const message = {
      data: {
        type: 'status',
        device_id: deviceId,
        sensor_min: String(sensorMin),
        sensor_min_status: sensorMinStatus,
        sensor_max: String(sensorMax),
        sensor_max_status: sensorMaxStatus,
        timestamp: new Date().toISOString(),
      },
      android: {
        priority: 'normal',
      },
      topic: 'water_alert',
    };
    const response = await admin.messaging().send(message);
    console.log(`[FCM] Status update sent for ${deviceId}: ${response}`);
  } catch (error) {
    console.error(`[FCM] Failed to send status update for ${deviceId}:`, error.message);
  }
}
