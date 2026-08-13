import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tranoo_pro/data/screens/notifications.dart';
import 'package:tranoo_pro/main.dart';
import 'package:tranoo_pro/services/alert_call_payload.dart';
import 'package:tranoo_pro/services/alert_pending_store.dart';
import 'package:tranoo_pro/utils/notification_tap_router.dart';
import 'package:tranoo_pro/widgets/alert_incoming_call_overlay.dart';

class AlertNotificationHandler {
  static Future<void> handleResponse(NotificationResponse response) async {
    final payload = response.payload ?? '';
    if (payload.startsWith('fcm:')) {
      try {
        final decoded = jsonDecode(payload.substring(4));
        if (decoded is Map) {
          final data = decoded.map(
            (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
          );
          await NotificationTapRouter.openFromData(
            NotificationService.navigatorKey.currentContext,
            data,
            navigatorKey: NotificationService.navigatorKey,
          );
        }
      } catch (_) {}
      return;
    }
    if (!payload.startsWith('alert:')) return;

    Map<String, String> data = {};
    try {
      final decoded = jsonDecode(payload.substring(6));
      if (decoded is Map) {
        data = decoded.map(
          (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
        );
      }
    } catch (_) {
      return;
    }

    if (response.actionId == 'reject') {
      await AlertPendingStore.clear();
      return;
    }

    final nav = NotificationService.navigatorKey.currentState;
    if (nav == null) return;

    await AlertPendingStore.clear();

    final notificationId = data['notificationId'] ?? '';

    if (NotificationTapRouter.opensArticleDetail(data)) {
      await NotificationTapRouter.openFromData(
        NotificationService.navigatorKey.currentContext,
        data,
        navigatorKey: NotificationService.navigatorKey,
      );
      return;
    }

    if (response.actionId == 'accept') {
      nav.push(
        MaterialPageRoute(
          builder: (_) => Notifications(
            openNotificationId:
                notificationId.isNotEmpty ? notificationId : null,
          ),
        ),
      );
      return;
    }

    // Tap sur la bannière : plein écran dans l'app
    await AlertIncomingCallService.showPayload(
      AlertCallPayload(
        title: data['title'] ?? 'Nouvelle alerte',
        body: data['message'] ?? 'Un acheteur recherche un article',
        data: data,
      ),
      navigatorKey: NotificationService.navigatorKey,
    );
  }

  @pragma('vm:entry-point')
  static void handleBackgroundResponse(NotificationResponse response) {
    handleResponse(response);
  }
}
