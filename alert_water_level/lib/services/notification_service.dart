import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // Request notification permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('User granted notification permission: ${settings.authorizationStatus}');

    // Subscribe to topic
    await _firebaseMessaging.subscribeToTopic('water_alert');
    debugPrint('Subscribed to water_alert topic');

    // Initialize local notifications for foreground
    await _initLocalNotifications();

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground message: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // Handle message when app is terminated but just opened
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        debugPrint('App opened from terminated state: ${message.notification?.title}');
      }
    });

    // Handle notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification tapped: ${message.notification?.title}');
    });
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
      'water_alert_channel',
      'Water Level Alert',
      description: 'Alerts for water level sensor thresholds',
      importance: Importance.high,
      enableVibration: true,
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;

    if (notification != null) {
      await _flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'water_alert_channel',
            'Water Level Alert',
            channelDescription: 'Alerts for water level sensors',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
            enableVibration: true,
          ),
        ),
        payload: message.data.toString(),
      );
    }
  }

  static Future<void> _backgroundMessageHandler(RemoteMessage message) async {
    debugPrint('Background message: ${message.notification?.title}');
    // FCM automatically shows notification in background
    // This handler is for custom logic if needed
  }
}
