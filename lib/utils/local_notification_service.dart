import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tranoo_pro/services/alert_notification_handler.dart';
import 'package:tranoo_pro/utils/notification_sounds.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        AlertNotificationHandler.handleResponse(details);
      },
      onDidReceiveBackgroundNotificationResponse:
          AlertNotificationHandler.handleBackgroundResponse,
    );

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          NotificationSounds.tricycleChannelId,
          'Tricycle',
          description: 'Notifications Tricycle',
          importance: Importance.high,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound(
            NotificationSounds.generalAndroid,
          ),
        ),
      );
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          NotificationSounds.generalChannelId,
          'Notifications Tranoo',
          description: 'Annonces, messages et mises à jour',
          importance: Importance.high,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound(
            NotificationSounds.generalAndroid,
          ),
        ),
      );
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          NotificationSounds.alertCallChannelId,
          'Alertes urgentes',
          description: 'Alertes acheteur — style appel entrant',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          sound: const RawResourceAndroidNotificationSound(
            NotificationSounds.alertRingAndroid,
          ),
        ),
      );
    }

    _initialized = true;
  }

  static Future<Map<String, String>?> getAlertLaunchData() async {
    await initialize();
    final details = await _notifications.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    final payload = details?.notificationResponse?.payload ?? '';
    if (!payload.startsWith('alert:')) return null;
    try {
      final decoded = jsonDecode(payload.substring(6));
      if (decoded is Map) {
        return decoded.map(
          (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
        );
      }
    } catch (_) {}
    return null;
  }

  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse response) {
    print('📩 Background notification: ${response.payload}');
  }

  static Future<void> showOTPNotification(String code) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'otp_channel',
      'Codes OTP',
      channelDescription: 'Notifications pour les codes OTP',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      sound: RawResourceAndroidNotificationSound(
        NotificationSounds.generalAndroid,
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: NotificationSounds.generalIos,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1001,
      'Code de vérification Tranoo',
      'Votre code: $code',
      details,
      payload: 'otp_code',
    );
  }

  static Future<void> showNotification(String title, String body) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      NotificationSounds.generalChannelId,
      'Notifications Tranoo',
      channelDescription: 'Notifications générales',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      sound: RawResourceAndroidNotificationSound(
        NotificationSounds.generalAndroid,
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentSound: true,
      sound: NotificationSounds.generalIos,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
    );
  }

  static Future<void> showAlertIncomingCallNotification({
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    await initialize();

    final payload = 'alert:${jsonEncode(data)}';

    final androidDetails = AndroidNotificationDetails(
      NotificationSounds.alertCallChannelId,
      'Alertes urgentes',
      channelDescription: 'Demandes acheteur — style appel entrant',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      ticker: 'Alerte Tranoo',
      sound: const RawResourceAndroidNotificationSound(
        NotificationSounds.alertRingAndroid,
      ),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Tranoo Pro',
      ),
      icon: '@mipmap/ic_launcher',
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'reject',
          'Refuser',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          'accept',
          'Répondre',
          showsUserInterface: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: NotificationSounds.alertRingIos,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      9001,
      title,
      body,
      details,
      payload: payload,
    );
  }

  static Future<void> showTricycleNotification(
    String title,
    String body,
  ) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      NotificationSounds.tricycleChannelId,
      'Tricycle',
      channelDescription: 'Notifications Tricycle',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      sound: RawResourceAndroidNotificationSound(
        NotificationSounds.generalAndroid,
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: NotificationSounds.generalIos,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
    );
  }
}
