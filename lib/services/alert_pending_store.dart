import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stocke une alerte reçue en arrière-plan pour afficher l'écran « appel » au retour sur l'app.
class AlertPendingStore {
  static const _key = 'tranoo_pro_pending_alert_v1';

  static Future<void> save(RemoteMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, dynamic>{
      'messageId': message.messageId,
      'title': message.notification?.title,
      'body': message.notification?.body,
      'data': message.data,
    };
    await prefs.setString(_key, jsonEncode(map));
  }

  static Future<RemoteMessage?> peek() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final data = Map<String, String>.from(
        (map['data'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
            ) ??
            {},
      );
      return RemoteMessage(
        messageId: map['messageId']?.toString(),
        notification: RemoteNotification(
          title: map['title']?.toString(),
          body: map['body']?.toString(),
        ),
        data: data,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<RemoteMessage?> take() async {
    final msg = await peek();
    if (msg != null) await clear();
    return msg;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
