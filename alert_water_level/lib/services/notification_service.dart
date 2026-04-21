import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'sensor_status_service.dart';

class NotificationService {
  // Notification constants
  static const String _channelId = 'water_alert_channel';
  static const String _channelName = 'Water Level Alert';
  static const String _channelDescription =
      'Alerts for water level sensor thresholds';
  static const String _topicName = 'water_alert';

  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;

  static final FlutterLocalNotificationsPlugin
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // Request notification permission
    try {
      final NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
            alert: true,
            announcement: true,
            badge: true,
            criticalAlert: false,
            provisional: false,
            sound: true,
          );
      debugPrint(
        'User granted notification permission: ${settings.authorizationStatus}',
      );
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }

    // Subscribe to topic
    try {
      await _firebaseMessaging.subscribeToTopic(_topicName);
      debugPrint('Subscribed to $_topicName topic');
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
    }

    // Initialize local notifications
    try {
      await _initLocalNotifications();
    } catch (e) {
      debugPrint('Error initializing local notifications: $e');
    }

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] Foreground: type=${message.data['type']}');
      _handleMessage(message);
    });

    // App opened from background by tapping notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] Opened from background: type=${message.data['type']}');
      sensorStatusService.updateFromFcmData(message.data);
    });

    // App opened from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        debugPrint('[FCM] Initial message: type=${message.data['type']}');
        sensorStatusService.updateFromFcmData(message.data);
      }
    });
  }

  /// Route a message:
  /// - `type == 'status'` → update UI silently, no notification
  /// - `type == 'alert'`  → update UI + show local notification
  static void _handleMessage(RemoteMessage message) {
    final type = message.data['type'];
    sensorStatusService.updateFromFcmData(message.data);
    if (type == 'alert') {
      _showLocalNotification(message);
    }
    // type == 'status' → silent, UI already updated above
  }

  static Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(initSettings);

    // Create notification channel for Android 8+
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      enableVibration: true,
      sound: RawResourceAndroidNotificationSound('alert_sound'),
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  static Future<void> showAlertNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
          enableVibration: true,
          sound: RawResourceAndroidNotificationSound('alert_sound'),
        ),
      ),
      payload: payload,
    );
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title =
        notification?.title ??
        '⚠️ Sensor Bahaya! Device ${message.data['device_id'] ?? ''}';
    final body = notification?.body ?? message.data['status'] ?? '';
    await showAlertNotification(
      title: title,
      body: body,
      payload: message.data.toString(),
    );
  }
}
