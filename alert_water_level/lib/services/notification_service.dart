import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

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

    // Initialize local notifications for foreground
    try {
      await _initLocalNotifications();
      debugPrint('Local notifications initialized successfully');
    } catch (e) {
      debugPrint('Error initializing local notifications: $e');
    }

    // Handle foreground messages
    try {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Foreground message: ${message.notification?.title}');
        _showLocalNotification(message);
      });
      debugPrint('Foreground message listener registered');
    } catch (e) {
      debugPrint('Error registering foreground message listener: $e');
    }

    // Handle message when app is terminated but just opened
    try {
      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null) {
          debugPrint(
            'App opened from terminated state: ${message.notification?.title}',
          );
        }
      });
      debugPrint('Initial message handler registered');
    } catch (e) {
      debugPrint('Error registering initial message handler: $e');
    }

    // Handle notification tap
    try {
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('Notification tapped: ${message.notification?.title}');
      });
      debugPrint('Message opened app listener registered');
    } catch (e) {
      debugPrint('Error registering message opened app listener: $e');
    }
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
      sound: RawResourceAndroidNotificationSound('notification'),
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
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
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
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
}
