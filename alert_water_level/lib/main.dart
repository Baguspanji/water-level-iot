import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'pages/home_page.dart';

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
        android: AndroidInitializationSettings('@drawable/ic_notification'),
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
          icon: '@drawable/ic_notification',
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
      debugShowCheckedModeBanner: false,
      title: 'WarWar',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
