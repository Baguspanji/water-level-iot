import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/sensor_status_service.dart';

/// Background handler — runs in a separate isolate.
/// FCM alert messages (with notification payload) are auto-shown by the system.
/// Data-only status messages are silently ignored here (no UI to update in isolate).
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Only show a local notification for explicit alert messages that lack
  // a server-side notification payload (shouldn't happen with current server,
  // but guard just in case).
  final type = message.data['type'];
  if (type == 'alert' && message.notification == null) {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    await plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '⚠️ Sensor Bahaya! Device ${message.data['device_id'] ?? ''}',
      message.data['status'] ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'water_alert_channel',
          'Water Level Alert',
          channelDescription: 'Alerts for water level sensors',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          sound: RawResourceAndroidNotificationSound('alert_sound'),
        ),
      ),
      payload: message.data.toString(),
    );
  }
  // type == 'status' → no action needed in background
}

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }

  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);
  await NotificationService.init();

  FlutterNativeSplash.remove();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Water Level Alert',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Water Level Monitoring'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  void initState() {
    super.initState();
    sensorStatusService.addListener(_onStatusUpdate);
  }

  @override
  void dispose() {
    sensorStatusService.removeListener(_onStatusUpdate);
    super.dispose();
  }

  void _onStatusUpdate() => setState(() {});

  // ── Helpers ────────────────────────────────────────────────────────────────

  Color _statusColor(String s) => s == 'HIGH' ? Colors.red : Colors.green;
  IconData _statusIcon(String s) =>
      s == 'HIGH' ? Icons.warning_amber_rounded : Icons.check_circle;

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final readings = sensorStatusService.readings;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 12,
                  color: readings.isEmpty ? Colors.grey : Colors.green,
                ),
                const SizedBox(width: 6),
                Text(
                  readings.isEmpty ? 'Menunggu data…' : 'Live',
                  style: TextStyle(
                    fontSize: 12,
                    color: readings.isEmpty ? Colors.grey : Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: readings.isEmpty
          ? _buildEmptyState()
          : _buildReadingsList(readings),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sensors, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Menunggu update dari sensor…',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Data akan muncul otomatis saat\nserver mengirim status berkala.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildReadingsList(Map<String, SensorReading> readings) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: readings.length,
      itemBuilder: (context, index) {
        final reading = readings.values.elementAt(index);
        return _SensorCard(
          reading: reading,
          statusColor: _statusColor,
          statusIcon: _statusIcon,
        );
      },
    );
  }
}

class _SensorCard extends StatelessWidget {
  const _SensorCard({
    required this.reading,
    required this.statusColor,
    required this.statusIcon,
  });

  final SensorReading reading;
  final Color Function(String) statusColor;
  final IconData Function(String) statusIcon;

  @override
  Widget build(BuildContext context) {
    final isAlert = reading.isAlert;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isAlert ? Colors.red.shade300 : Colors.transparent,
          width: 1.5,
        ),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isAlert ? Icons.warning_amber_rounded : Icons.water,
                  color: isAlert ? Colors.red : Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  reading.deviceId,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _StatusBadge(isAlert: isAlert),
              ],
            ),
            const Divider(height: 24),
            _SensorRow(
              label: 'Sensor Min',
              value: reading.sensorMin,
              status: reading.sensorMinStatus,
              statusColor: statusColor(reading.sensorMinStatus),
              icon: statusIcon(reading.sensorMinStatus),
            ),
            const SizedBox(height: 12),
            _SensorRow(
              label: 'Sensor Max',
              value: reading.sensorMax,
              status: reading.sensorMaxStatus,
              statusColor: statusColor(reading.sensorMaxStatus),
              icon: statusIcon(reading.sensorMaxStatus),
            ),
            const SizedBox(height: 12),
            Text(
              'Update: ${_formatTime(reading.receivedAt)}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isAlert});
  final bool isAlert;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isAlert ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAlert ? Colors.red.shade300 : Colors.green.shade300,
        ),
      ),
      child: Text(
        isAlert ? '⚠ BAHAYA' : '✓ AMAN',
        style: TextStyle(
          color: isAlert ? Colors.red : Colors.green,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SensorRow extends StatelessWidget {
  const _SensorRow({
    required this.label,
    required this.value,
    required this.status,
    required this.statusColor,
    required this.icon,
  });

  final String label;
  final double value;
  final String status;
  final Color statusColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Text(
          value.toStringAsFixed(0),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: statusColor),
              const SizedBox(width: 4),
              Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
