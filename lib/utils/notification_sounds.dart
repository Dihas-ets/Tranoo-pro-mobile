/// Sons des notifications (fichiers dans android/app/src/main/res/raw/ et assets/sounds/).
class NotificationSounds {
  NotificationSounds._();

  static const String alertRingAndroid = 'alert_ring';
  static const String alertRingAsset = 'sounds/alert_ring.mp3';
  static const String alertRingIos = 'alert_ring.mp3';

  static const String generalAndroid = 'notification_chime';
  static const String generalAsset = 'sounds/notification_chime.mp3';
  static const String generalIos = 'notification_chime.mp3';

  /// Nouveaux IDs de canal (Android fige le son à la création du canal).
  static const String alertCallChannelId = 'alert_call_channel_v2';
  static const String generalChannelId = 'general_channel_v2';
  static const String tricycleChannelId = 'tricycle_channel_v2';
}
