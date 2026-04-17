const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const fs = require('fs');

const DB_PATH = process.env.DB_PATH || './data/water_sensor.db';

// Ensure data directory exists
const dir = path.dirname(DB_PATH);
if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
}

const db = new sqlite3.Database(DB_PATH, (err) => {
    if (err) {
        console.error('[DB] Failed to connect:', err.message);
        process.exit(1);
    }
    console.log('[DB] Connected to SQLite database');
});

db.serialize(() => {
    db.run(`
    CREATE TABLE IF NOT EXISTS devices (
      device_id   TEXT PRIMARY KEY,
      name        TEXT,
      location    TEXT,
      lat         REAL,
      lng         REAL,
      created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at  DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

    db.run(`
    CREATE TABLE IF NOT EXISTS sensor_readings (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      device_id       TEXT NOT NULL,
      sensor_min      REAL,
      sensor_min_status TEXT,
      sensor_max      REAL,
      sensor_max_status TEXT,
      received_at     DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

    db.run(`
    CREATE INDEX IF NOT EXISTS idx_device_time
    ON sensor_readings (device_id, received_at DESC)
  `);
});

/**
 * Insert a sensor reading into the database.
 * @param {string} deviceId
 * @param {object} payload
 */
function insertReading(deviceId, payload) {
    return new Promise((resolve, reject) => {
        const stmt = db.prepare(`
      INSERT INTO sensor_readings
        (device_id, sensor_min, sensor_min_status, sensor_max, sensor_max_status)
      VALUES (?, ?, ?, ?, ?)
    `);
        stmt.run(
            deviceId,
            payload.sensor_min ?? null,
            payload.sensor_min_status ?? null,
            payload.sensor_max ?? null,
            payload.sensor_max_status ?? null,
            function (err) {
                if (err) return reject(err);
                resolve(this.lastID);
            }
        );
        stmt.finalize();
    });
}

/**
 * Get latest N readings for a device (or all devices).
 */
function getReadings({ deviceId, limit = 100, offset = 0 } = {}) {
    return new Promise((resolve, reject) => {
        const params = [];
        let sql = `SELECT id, device_id, sensor_min, sensor_min_status, sensor_max, sensor_max_status, received_at FROM sensor_readings`;
        if (deviceId) {
            sql += ` WHERE device_id = ?`;
            params.push(deviceId);
        }
        sql += ` ORDER BY received_at DESC LIMIT ? OFFSET ?`;
        params.push(limit, offset);
        db.all(sql, params, (err, rows) => {
            if (err) return reject(err);
            resolve(rows);
        });
    });
}

/**
 * Get the latest reading per device.
 */
function getLatestPerDevice() {
    return new Promise((resolve, reject) => {
        db.all(
            `SELECT s.id, s.device_id, s.sensor_min, s.sensor_min_status, s.sensor_max, s.sensor_max_status, s.received_at
       FROM sensor_readings s
       INNER JOIN (
         SELECT device_id, MAX(received_at) AS max_time
         FROM sensor_readings
         GROUP BY device_id
       ) t ON s.device_id = t.device_id AND s.received_at = t.max_time`,
            [],
            (err, rows) => {
                if (err) return reject(err);
                resolve(rows);
            }
        );
    });
}

/**
 * List all known device IDs.
 */
function getDevices() {
    return new Promise((resolve, reject) => {
        db.all(
            `SELECT device_id, COUNT(*) as total_readings, MAX(received_at) as last_seen
       FROM sensor_readings GROUP BY device_id`,
            [],
            (err, rows) => {
                if (err) return reject(err);
                resolve(rows);
            }
        );
    });
}

module.exports = { db, insertReading, getReadings, getLatestPerDevice, getDevices };

// ── Device metadata ────────────────────────────────────────────────

function upsertDevice({ device_id, name, location, lat, lng }) {
    return new Promise((resolve, reject) => {
        db.run(
            `INSERT INTO devices (device_id, name, location, lat, lng)
             VALUES (?, ?, ?, ?, ?)
             ON CONFLICT(device_id) DO UPDATE SET
               name       = excluded.name,
               location   = excluded.location,
               lat        = excluded.lat,
               lng        = excluded.lng,
               updated_at = CURRENT_TIMESTAMP`,
            [device_id, name ?? null, location ?? null, lat ?? null, lng ?? null],
            function (err) {
                if (err) return reject(err);
                resolve(this.changes);
            }
        );
    });
}

function getAllDeviceMeta() {
    return new Promise((resolve, reject) => {
        db.all(`SELECT * FROM devices ORDER BY created_at ASC`, [], (err, rows) => {
            if (err) return reject(err);
            resolve(rows);
        });
    });
}

function getDeviceMeta(deviceId) {
    return new Promise((resolve, reject) => {
        db.get(`SELECT * FROM devices WHERE device_id = ?`, [deviceId], (err, row) => {
            if (err) return reject(err);
            resolve(row || null);
        });
    });
}

module.exports.upsertDevice = upsertDevice;
module.exports.getAllDeviceMeta = getAllDeviceMeta;
module.exports.getDeviceMeta = getDeviceMeta;
