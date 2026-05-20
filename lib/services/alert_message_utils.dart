import 'package:firebase_messaging/firebase_messaging.dart';

bool isAlertFcmMessage(RemoteMessage message) {
  final type = (message.data['type'] ?? '').toString();
  if (type == 'alerte') return true;
  final rt = (message.data['requestType'] ?? '').toString();
  return rt == 'vehicle_search' || rt == 'piece_search';
}
