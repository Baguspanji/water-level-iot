const express = require('express');
const { getReadings, getLatestPerDevice, getDevices, upsertDevice, getAllDeviceMeta, getDeviceMeta } = require('./database');

const router = express.Router();

/**
 * GET /api/devices
 * List all devices (sensor stats + metadata joined).
 */
router.get('/devices', async (req, res) => {
    try {
        const [stats, meta] = await Promise.all([getDevices(), getAllDeviceMeta()]);
        const metaMap = Object.fromEntries(meta.map(m => [m.device_id, m]));
        const data = stats.map(s => ({ ...s, ...(metaMap[s.device_id] || {}) }));
        // include devices that have meta but no readings yet
        for (const m of meta) {
            if (!data.find(d => d.device_id === m.device_id)) data.push(m);
        }
        res.json({ success: true, data });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

/**
 * PUT /api/devices/:deviceId
 * Create or update device metadata (name, location, lat, lng).
 */
router.put('/devices/:deviceId', async (req, res) => {
    try {
        const device_id = req.params.deviceId;
        const { name, location, lat, lng } = req.body;
        await upsertDevice({ device_id, name, location, lat, lng });
        const updated = await getDeviceMeta(device_id);
        res.json({ success: true, data: updated });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

/**
 * GET /api/sensors/latest
 */
router.get('/sensors/latest', async (req, res) => {
    try {
        const [rows, meta] = await Promise.all([getLatestPerDevice(), getAllDeviceMeta()]);
        const metaMap = Object.fromEntries(meta.map(m => [m.device_id, m]));
        const data = rows.map(r => ({ ...r, ...(metaMap[r.device_id] || {}) }));
        res.json({ success: true, data });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

/**
 * GET /api/sensors
 */
router.get('/sensors', async (req, res) => {
    try {
        const deviceId = req.query.device_id || null;
        const limit = Math.min(parseInt(req.query.limit) || 100, 1000);
        const offset = parseInt(req.query.offset) || 0;
        const rows = await getReadings({ deviceId, limit, offset });
        res.json({ success: true, count: rows.length, data: rows });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

/**
 * GET /api/sensors/:deviceId
 */
router.get('/sensors/:deviceId', async (req, res) => {
    try {
        const deviceId = req.params.deviceId;
        const limit = Math.min(parseInt(req.query.limit) || 100, 1000);
        const offset = parseInt(req.query.offset) || 0;
        const rows = await getReadings({ deviceId, limit, offset });
        res.json({ success: true, count: rows.length, data: rows });
    } catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
});

module.exports = router;
