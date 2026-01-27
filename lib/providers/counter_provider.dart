import 'package:flutter/foundation.dart';
import '../services/notification_service.dart';

class CounterProvider with ChangeNotifier {
  final NotificationService _notificationService = NotificationService();

  int _unreadNotificationsCount = 0;

  int get unreadNotificationsCount => _unreadNotificationsCount;

  // Charger les compteurs
  Future<void> loadCounters() async {
    try {
      final notificationsCount = await _notificationService.getUnreadCount();

      _unreadNotificationsCount = notificationsCount;

      notifyListeners();
    } catch (e) {
      print('Erreur lors du chargement des compteurs: $e');
    }
  }

  // Mettre à jour le compteur de notifications
  void updateNotificationsCount(int count) {
    _unreadNotificationsCount = count;
    notifyListeners();
  }

  // Incrémenter le compteur de notifications
  void incrementNotificationsCount() {
    _unreadNotificationsCount++;
    notifyListeners();
  }

  // Réinitialiser le compteur de notifications
  void resetNotificationsCount() {
    _unreadNotificationsCount = 0;
    notifyListeners();
  }
}
