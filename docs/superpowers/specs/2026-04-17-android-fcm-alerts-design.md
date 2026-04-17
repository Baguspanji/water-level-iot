# Design: Android FCM Alert Notifications for Water Level Sensor

**Date:** 2026-04-17  
**Status:** Approved  

---

## Overview

Bangun sistem notifikasi push untuk aplikasi Android (Flutter) yang menerima alert ketika sensor water level mencapai status HIGH (nilai > 500). Server Node.js mengirim notifikasi via Firebase Cloud Messaging (FCM) menggunakan topic subscription, sehingga semua pengguna yang install aplikasi otomatis menerima alert tanpa login.

---

## Architecture

```
ESP32 → MQTT Broker → mqttClient.js
                           │
                     nilai > 500?
                           │ ya
                    notificationService.js
                           │
                    Firebase Admin SDK
                           │
                    FCM Topic: "water_alert"
                           │
                    ┌──────┴──────┐
               Android A    Android B    (semua subscriber)
               Flutter App  Flutter App
```

---

## Server Side (Node.js)

### New File: `src/notificationService.js`

Modul khusus untuk logika FCM. Tanggung jawab:
- Inisialisasi Firebase Admin SDK dengan `serviceAccountKey.json`
- Fungsi `sendAlert(deviceId, value, status)` — kirim FCM topic message
- Cooldown map per `device_id` di memory (`Map`) — skip kirim jika < 60 detik sejak notifikasi terakhir untuk device yang sama

### Modified: `src/mqttClient.js`

Tambah pemanggilan `sendAlert()` setelah insert ke database, ketika `sensor_min > 500` atau `sensor_max > 500`.

### New File: `serviceAccountKey.json` (root project)

Dari Firebase Console → Project Settings → Service Accounts → Generate new private key.  
**Wajib masuk `.gitignore`.**

### Dependencies

```
npm install firebase-admin
```

---

## FCM Message Payload

```json
{
  "topic": "water_alert",
  "notification": {
    "title": "⚠️ Sensor Bahaya!",
    "body": "Device ESP32-001: nilai sensor 523 (HIGH)"
  },
  "data": {
    "device_id": "ESP32-001",
    "value": "523",
    "status": "HIGH",
    "timestamp": "2026-04-17T09:35:00.000Z"
  },
  "android": {
    "priority": "high",
    "notification": {
      "channel_id": "water_alert_channel",
      "sound": "default"
    }
  }
}
```

---

## Cooldown Logic

- Simpan `Map<device_id, timestamp>` di memory server
- Sebelum kirim: cek apakah `Date.now() - lastSentAt[deviceId] < 60000`
- Jika ya → skip
- Jika tidak → kirim dan update `lastSentAt[deviceId]`

---

## Flutter App Side

### File Structure

```
alert_water_level/
├── lib/
│   ├── main.dart                          ← inisialisasi Firebase, FCM, permission
│   └── services/
│       └── notification_service.dart      ← FCM handler, topic subscription
├── android/
│   └── app/
│       ├── build.gradle.kts               ← google-services plugin
│       └── google-services.json           ← dari Firebase Console (.gitignore)
└── pubspec.yaml                           ← tambah dependencies
```

### Dependencies (pubspec.yaml)

```yaml
dependencies:
  firebase_core: ^3.x.x
  firebase_messaging: ^15.x.x
  flutter_local_notifications: ^17.x.x
```

### Initialization Flow (`main.dart`)

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
3. `FirebaseMessaging.onBackgroundMessage(backgroundHandler)` — top-level function
4. Request notification permission dari user
5. Subscribe ke topic `water_alert`
6. Setup local notification channel untuk foreground messages

### Notification Channel (Android 8+)

- **Channel ID:** `water_alert_channel`
- **Importance:** HIGH (heads-up notification, muncul di atas layar)
- **Sound:** default
- **Vibration:** aktif

### Notification States

| State | Handler | Behavior |
|-------|---------|----------|
| Foreground (app terbuka) | `FirebaseMessaging.onMessage` | Tampil via `flutter_local_notifications` |
| Background (app minimize) | FCM system | Tampil otomatis di notification tray |
| Terminated (app di-kill) | `FirebaseMessaging.onBackgroundMessage` | Tampil otomatis di notification tray |

### UI

Satu halaman sederhana:
- Teks konfirmasi "Monitoring aktif"
- Status subscribe topic (`water_alert`)
- Tidak ada fitur lain

---

## Files NOT Changed

- `src/routes.js` — tidak ada perubahan
- `src/database.js` — tidak ada perubahan
- `public/index.html` — tidak ada perubahan

---

## Security

- `serviceAccountKey.json` → masuk `.gitignore`, TIDAK di-commit
- `google-services.json` → masuk `.gitignore`, TIDAK di-commit
- FCM topic bersifat publik (siapapun yang install app bisa subscribe) — sesuai kebutuhan

---

## Out of Scope

- Login/registrasi user
- Dashboard/monitoring di dalam app
- Notifikasi "sensor kembali normal"
- Antrian/queue notifikasi
- iOS support
