import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tranoo_pro/services/alert_notification_handler.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static const String tricycleChannelId = 'tricycle_channel';
  static const String alertCallChannelId = 'alert_call_channel';
  static const String tricycleSoundAndroid = 'driver_request_sound';
  static const String tricycleSoundIOS = 'driver_request_sound.wav';

  /// INIT
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

    // Android channel setup
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          tricycleChannelId,
          'Tricycle',
          description: 'Notifications Tricycle (demandes, annulations, rejets)',
          importance: Importance.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(
            tricycleSoundAndroid,
          ),
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          alertCallChannelId,
          'Alertes urgentes',
          description: 'Nouvelles demandes acheteur (style appel)',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
      if (androidPlugin != null) {
        await androidPlugin.requestFullScreenIntentPermission();
      }
    }

    _initialized = true;
  }

  /// Lance l'écran appel si l'app a été ouverte via la notif plein écran.
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

  /// BACKGROUND TAP HANDLER
  @pragma('vm:entry-point')
  static void notificationTapBackground(NotificationResponse response) {
    print('📩 Background notification: ${response.payload}');
  }

  /// OTP NOTIFICATION
  static Future<void> showOTPNotification(String code) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'otp_channel',
      'Codes OTP',
      channelDescription: 'Notifications pour les codes OTP',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
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

  /// GENERAL NOTIFICATION
  static Future<void> showNotification(String title, String body) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'general_channel',
      'Notifications générales',
      channelDescription: 'Notifications générales de l\'app',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails();

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

  /// ALERTE ACHETEUR — plein écran / haute priorité (arrière-plan)
  static Future<void> showAlertIncomingCallNotification({
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    await initialize();

    final payload = 'alert:${jsonEncode(data)}';

    final androidDetails = AndroidNotificationDetails(
      alertCallChannelId,
      'Alertes urgentes',
      channelDescription: 'Demandes acheteur — style appel entrant',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      ticker: 'Alerte Tranoo — nouvelle demande',
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

  /// TRICYCLE NOTIFICATION (SOUND CUSTOM)
  static Future<void> showTricycleNotification(
    String title,
    String body,
  ) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      tricycleChannelId,
      'Tricycle',
      channelDescription: 'Notifications Tricycle',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      sound: RawResourceAndroidNotificationSound(
        tricycleSoundAndroid,
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: tricycleSoundIOS,
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