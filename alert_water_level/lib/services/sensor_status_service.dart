import 'package:flutter/foundation.dart';

/// Connection state for FCM signal.
enum ConnectionStatus { waiting, connected, disconnected }

/// Holds the latest sensor status received via FCM data messages.
class SensorReading {
  final String deviceId;
  final double sensorMin;
  final String sensorMinStatus; // 'HIGH' | 'LOW'
  final double sensorMax;
  final String sensorMaxStatus; // 'HIGH' | 'LOW'
  final DateTime receivedAt;

  SensorReading({
    required this.deviceId,
    required this.sensorMin,
    required this.sensorMinStatus,
    required this.sensorMax,
    required this.sensorMaxStatus,
    required this.receivedAt,
  });

  bool get isAlert => sensorMinStatus == 'HIGH' || sensorMaxStatus == 'HIGH';

  /// Parse from FCM data map.
  ///
  /// Handles two server formats:
  /// - **status**: `sensor_min`, `sensor_min_status`, `sensor_max`, `sensor_max_status`
  /// - **alert**:  `value`, `status` (single sensor value)
  ///
  /// For alert messages the single value is stored in both min and max fields
  /// so the UI always has something to display. If an [existing] reading is
  /// provided the alert value is merged into it instead.
  static SensorReading? fromFcmData(
    Map<String, dynamic> data, {
    SensorReading? existing,
  }) {
    try {
      final deviceId = data['device_id'] as String?;
      if (deviceId == null) return null;

      final type = data['type'] as String?;
      final receivedAt =
          DateTime.tryParse(data['timestamp'] ?? '') ?? DateTime.now();

      if (type == 'alert') {
        // Alert format: { value, status }
        final alertValue = double.tryParse(data['value'] ?? '');
        final alertStatus = data['status'] as String? ?? 'HIGH';

        if (alertValue != null) {
          // Merge into existing reading if available
          return SensorReading(
            deviceId: deviceId,
            sensorMin: existing?.sensorMin ?? alertValue,
            sensorMinStatus: existing?.sensorMinStatus ?? alertStatus,
            sensorMax: existing?.sensorMax ?? alertValue,
            sensorMaxStatus: existing?.sensorMaxStatus ?? alertStatus,
            receivedAt: receivedAt,
          );
        }
        // Alert without parseable value — still mark device as alert
        return SensorReading(
          deviceId: deviceId,
          sensorMin: existing?.sensorMin ?? 0,
          sensorMinStatus: alertStatus,
          sensorMax: existing?.sensorMax ?? 0,
          sensorMaxStatus: alertStatus,
          receivedAt: receivedAt,
        );
      }

      // Status format: { sensor_min, sensor_min_status, sensor_max, sensor_max_status }
      final sMin = double.tryParse(data['sensor_min'] ?? '');
      final sMax = double.tryParse(data['sensor_max'] ?? '');
      if (sMin == null || sMax == null) return null;

      return SensorReading(
        deviceId: deviceId,
        sensorMin: sMin,
        sensorMinStatus: data['sensor_min_status'] ?? 'LOW',
        sensorMax: sMax,
        sensorMaxStatus: data['sensor_max_status'] ?? 'LOW',
        receivedAt: receivedAt,
      );
    } catch (_) {
      return null;
    }
  }
}

/// ChangeNotifier that stores the latest reading per device ID.
/// Updated whenever a FCM `type: status` or `type: alert` message is received.
class SensorStatusService extends ChangeNotifier {
  final Map<String, SensorReading> _readings = {};
  ConnectionStatus _connectionStatus = ConnectionStatus.waiting;
  DateTime? _lastMessageAt;

  Map<String, SensorReading> get readings => Map.unmodifiable(_readings);
  ConnectionStatus get connectionStatus => _connectionStatus;
  DateTime? get lastMessageAt => _lastMessageAt;

  /// Whether any sensor is in alert state.
  bool get hasAlert => _readings.values.any((r) => r.isAlert);

  /// Number of sensors currently in alert.
  int get alertCount => _readings.values.where((r) => r.isAlert).length;

  /// Total number of tracked sensors.
  int get totalCount => _readings.length;

  /// Call this from any FCM handler (foreground / background / terminated).
  void updateFromFcmData(Map<String, dynamic> data) {
    final deviceId = data['device_id'] as String?;
    final existing = deviceId != null ? _readings[deviceId] : null;
    final reading = SensorReading.fromFcmData(data, existing: existing);
    if (reading == null) return;
    _readings[reading.deviceId] = reading;
    _lastMessageAt = DateTime.now();
    if (_connectionStatus != ConnectionStatus.connected) {
      _connectionStatus = ConnectionStatus.connected;
    }
    debugPrint(
      '[Status] ${reading.deviceId} min=${reading.sensorMin}(${reading.sensorMinStatus}) '
      'max=${reading.sensorMax}(${reading.sensorMaxStatus})',
    );
    notifyListeners();
  }

  /// Mark FCM as connected (called when subscription succeeds).
  void markConnected() {
    if (_connectionStatus != ConnectionStatus.connected) {
      _connectionStatus = ConnectionStatus.connected;
      notifyListeners();
    }
  }

  /// Mark FCM as disconnected.
  void markDisconnected() {
    if (_connectionStatus != ConnectionStatus.disconnected) {
      _connectionStatus = ConnectionStatus.disconnected;
      notifyListeners();
    }
  }

  void clear() {
    _readings.clear();
    _connectionStatus = ConnectionStatus.waiting;
    _lastMessageAt = null;
    notifyListeners();
  }
}

/// Global singleton — accessible from FCM background isolate helpers too.
final sensorStatusService = SensorStatusService();
