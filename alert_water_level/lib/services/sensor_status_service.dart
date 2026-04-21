import 'package:flutter/foundation.dart';

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

  /// Parse from FCM data map. Returns null if required fields are missing.
  static SensorReading? fromFcmData(Map<String, dynamic> data) {
    try {
      final deviceId = data['device_id'] as String?;
      final sMin = double.tryParse(data['sensor_min'] ?? '');
      final sMax = double.tryParse(data['sensor_max'] ?? '');
      if (deviceId == null || sMin == null || sMax == null) return null;
      return SensorReading(
        deviceId: deviceId,
        sensorMin: sMin,
        sensorMinStatus: data['sensor_min_status'] ?? 'LOW',
        sensorMax: sMax,
        sensorMaxStatus: data['sensor_max_status'] ?? 'LOW',
        receivedAt:
            DateTime.tryParse(data['timestamp'] ?? '') ?? DateTime.now(),
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

  Map<String, SensorReading> get readings => Map.unmodifiable(_readings);

  /// Call this from any FCM handler (foreground / background / terminated).
  void updateFromFcmData(Map<String, dynamic> data) {
    final reading = SensorReading.fromFcmData(data);
    if (reading == null) return;
    _readings[reading.deviceId] = reading;
    debugPrint(
      '[Status] ${reading.deviceId} min=${reading.sensorMin}(${reading.sensorMinStatus}) '
      'max=${reading.sensorMax}(${reading.sensorMaxStatus})',
    );
    notifyListeners();
  }

  void clear() {
    _readings.clear();
    notifyListeners();
  }
}

/// Global singleton — accessible from FCM background isolate helpers too.
final sensorStatusService = SensorStatusService();
