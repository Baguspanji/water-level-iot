require('dotenv').config();

const path = require('path');
const express = require('express');
const { connect: connectMqtt } = require('./src/mqttClient');
const apiRoutes = require('./src/routes');

const PORT = parseInt(process.env.HTTP_PORT) || 3000;

// ── Express HTTP server ────────────────────────────────────────────
const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// API routes
app.use('/api', apiRoutes);

// ── SSE – live sensor events ───────────────────────────────────────
const sseClients = new Set();

app.get('/events', (req, res) => {
    res.set({
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
    });
    res.flushHeaders();
    res.write(':\n\n'); // comment keep-alive

    sseClients.add(res);
    req.on('close', () => sseClients.delete(res));
});

// Called by mqttClient after each successful DB insert
function broadcastReading(deviceId, payload) {
    const data = JSON.stringify({ device_id: deviceId, ...payload, received_at: new Date().toISOString() });
    for (const client of sseClients) {
        client.write(`data: ${data}\n\n`);
    }
}

module.exports.broadcastReading = broadcastReading;

// Dashboard (SPA entry)
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({ success: false, error: 'Not found' });
});

app.listen(PORT, () => {
    console.log(`[HTTP] Server listening on http://localhost:${PORT}`);
});

// ── MQTT client ────────────────────────────────────────────────────
connectMqtt();

// ── Graceful shutdown ──────────────────────────────────────────────
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

function shutdown() {
    console.log('\n[App] Shutting down…');
    const { getClient } = require('./src/mqttClient');
    const mqttClient = getClient();
    if (mqttClient) mqttClient.end(true);
    process.exit(0);
}
