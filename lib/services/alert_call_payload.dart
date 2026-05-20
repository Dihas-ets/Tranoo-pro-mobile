import 'package:firebase_messaging/firebase_messaging.dart';

class AlertCallPayload {
  final String title;
  final String body;
  final Map<String, String> data;

  const AlertCallPayload({
    required this.title,
    required this.body,
    required this.data,
  });

  factory AlertCallPayload.fromRemoteMessage(RemoteMessage message) {
    final data = message.data.map(
      (k, v) => MapEntry(k, v?.toString() ?? ''),
    );
    return AlertCallPayload(
      title: message.notification?.title ??
          data['title'] ??
          'Nouvelle alerte',
      body: message.notification?.body ??
          data['message'] ??
          'Un acheteur recherche un article',
      data: data,
    );
  }
}
