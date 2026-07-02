import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tranoo_pro/data/screens/avant_home.dart';
import 'package:tranoo_pro/data/screens/connexion_page.dart';
import 'package:tranoo_pro/data/screens/second_page.dart';
import 'package:tranoo_pro/providers/auth_provider.dart' as myauth;
import 'package:tranoo_pro/services/blocked_user_service.dart';
import 'package:tranoo_pro/services/user_service.dart';
import 'package:tranoo_pro/utils/role_redirect.dart';
import 'package:tranoo_pro/widgets/first_launch_location_dialog.dart';

/// Démarrage sans UI — avant et pendant la vidéo splash.
class AppBootstrap {
  AppBootstrap._();

  static Future<void>? _warmFuture;
  static SharedPreferences? prefs;
  static bool userBlocked = false;
  static bool hasSeenOnboarding = true;
  static Map<String, dynamic>? cachedUser;
  static String? cachedToken;

  static Future<void> warmUp() {
    return _warmFuture ??= _run();
  }

  static Future<void> _run() async {
    prefs = await SharedPreferences.getInstance();
    try {
      userBlocked = await UserService()
          .checkUserBlockedStatus()
          .timeout(const Duration(seconds: 3), onTimeout: () => false);
    } catch (_) {
      userBlocked = false;
    }
    await refreshRoutingState();
  }

  /// Relit les prefs + Firebase pour décider onboarding / connexion / accueil.
  static Future<void> refreshRoutingState() async {
    prefs ??= await SharedPreferences.getInstance();
    hasSeenOnboarding = prefs!.getBool('hasSeenOnboarding') ?? false;
    cachedToken = prefs!.getString(myauth.AuthProvider.tokenPrefsKey);
    cachedUser = _decodeUser(prefs!.getString(myauth.AuthProvider.userPrefsKey));

    final firebaseUser = FirebaseAuth.instance.currentUser;
    final hadGhostCache =
        (cachedUser != null || (cachedToken?.trim().isNotEmpty ?? false)) &&
            firebaseUser == null;

    // Sauvegarde Android : prefs restaurées sans session Firebase → réinstall propre.
    if (hadGhostCache) {
      await myauth.AuthProvider.clearUserFromPrefs();
      cachedUser = null;
      cachedToken = null;
      await prefs!.setBool('hasSeenOnboarding', false);
      hasSeenOnboarding = false;
    }

    _hydrateUserServiceFromCache();
  }

  static Map<String, dynamic>? _decodeUser(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  static bool get hasValidCachedSession {
    final user = cachedUser;
    final token = cachedToken?.trim() ?? '';
    if (user == null || token.isEmpty) return false;
    final id = user['_id']?.toString().trim() ?? '';
    final role = (user['role'] ?? user['typeUtilisateur'] ?? user['type'])
        ?.toString()
        .trim();
    return id.isNotEmpty || (role != null && role.isNotEmpty);
  }

  static void _hydrateUserServiceFromCache() {
    final user = cachedUser;
    if (user == null) {
      UserService().clearRole();
      return;
    }
    final roleRaw =
        (user['role'] ?? user['typeUtilisateur'] ?? user['type'])?.toString();
    final role = stringToUserRole(roleRaw);
    if (role != null) {
      UserService().setRole(role);
      final vendeurType = user['vendeurType']?.toString();
      UserService().setVendeurType(
        vendeurType != null && vendeurType.trim().isNotEmpty
            ? vendeurType.trim()
            : null,
      );
    } else {
      UserService().clearRole();
    }
  }

  /// Destination immédiate (onboarding / connexion) sans contexte UI.
  static Widget? resolveEntryWidgetSync() {
    if (!hasSeenOnboarding) return const SecondPage();
    if (!hasValidCachedSession) return const ConnexionPage();
    return null;
  }

  static Widget fallbackEntry() {
    if (!hasSeenOnboarding) return const SecondPage();
    return const ConnexionPage();
  }

  /// Résout la destination finale (appelé à la fin de la vidéo).
  static Future<Widget> resolveEntryWidget(BuildContext context) async {
    await refreshRoutingState();
    final instant = resolveEntryWidgetSync();
    if (instant != null) {
      if (instant is ConnexionPage) {
        unawaited(AppBootSession.clearStaleFirebaseSession());
      }
      return instant;
    }
    if (!context.mounted) return fallbackEntry();
    return AppBootSession.finalizeHome(context);
  }
}

/// Finalise le boot accueil (utilisateur en cache valide).
class AppBootSession {
  AppBootSession._();

  static const String welcomeSeenKey = 'tranoo_pro_has_seen_welcome';
  static bool _welcomeFlowStarted = false;

  static Future<void> clearStaleFirebaseSession() async {
    try {
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.signOut();
      }
    } catch (_) {}
    await myauth.AuthProvider.clearUserFromPrefs();
    await AppBootstrap.refreshRoutingState();
  }

  static Future<Widget> finalizeHome(BuildContext context) async {
    if (!AppBootstrap.hasValidCachedSession) {
      return AppBootstrap.fallbackEntry();
    }

    if (!context.mounted) return const AvantHome();
    BlockedUserService.setContext(context);

    if (!_welcomeFlowStarted) {
      _welcomeFlowStarted = true;
      final prefs = AppBootstrap.prefs ?? await SharedPreferences.getInstance();
      final hasSeenWelcome = prefs.getBool(welcomeSeenKey) ?? false;
      final legacySeen = prefs.getBool('is_first_launch') == false;

      if (!hasSeenWelcome && !legacySeen) {
        if (context.mounted) {
          await showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (context) => FirstLaunchLocationDialog(
              onDismissed: () {},
            ),
          );
        }
      } else if (!hasSeenWelcome && legacySeen) {
        await prefs.setBool(welcomeSeenKey, true);
        await prefs.setBool('is_first_launch', false);
      }
    }

    if (AppBootstrap.userBlocked) {
      return const ConnexionPage();
    }

    if (context.mounted) {
      final authProvider =
          Provider.of<myauth.AuthProvider>(context, listen: false);
      await authProvider.checkTypeVendeurMigration(context);
    }

    if (!context.mounted) return const AvantHome();
    return const AvantHome();
  }
}
