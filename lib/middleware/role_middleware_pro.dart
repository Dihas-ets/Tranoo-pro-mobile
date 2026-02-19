import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service_pro.dart';
import '../services/user_role_service_pro.dart';
import '../widgets/role_restriction_dialog_pro.dart';

/// Middleware pour vérifier les restrictions d'accès par rôle pour Tranoo Pro
class RoleMiddlewarePro {
  
  /// URLs des stores (à configurer selon vos besoins)
  static const String tranooPlayStore = 'https://play.google.com/store/apps/details?id=com.tranoo.app';
  static const String tranooAppStore = 'https://apps.apple.com/app/tranoo/id123456789';
  
  /// Vérifier si l'utilisateur peut accéder à Tranoo Pro (sauf acheteurs)
  static Future<bool> checkTranooProAccess(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    
    // Si non connecté, rediriger vers login
    if (user == null) {
      _redirectToLogin(context);
      return false;
    }

    // Vérifier le rôle
    final canAccess = await AuthServicePro.canAccessTranooPro();
    
    if (!canAccess) {
      _showRoleRestrictionDialog(
        context,
        currentApp: 'Tranoo Pro',
        userRole: await UserRoleServicePro.getUserRoleWithFallback(),
        alternativeApp: 'Tranoo',
        playStoreUrl: tranooPlayStore,
        appStoreUrl: tranooAppStore,
      );
      return false;
    }

    return true;
  }

  /// Rediriger vers la page de login
  static void _redirectToLogin(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const _LoginScreen()),
      (route) => false,
    );
  }

  /// Afficher le popup attractif de restriction d'accès
  static void _showRoleRestrictionDialog(
    BuildContext context, {
    required String currentApp,
    required String? userRole,
    required String alternativeApp,
    required String playStoreUrl,
    required String appStoreUrl,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RoleRestrictionDialogPro(
        currentApp: currentApp,
        requiredRole: UserRoleServicePro.getRoleDisplayName(userRole ?? 'inconnu'),
        alternativeApp: alternativeApp,
        playStoreUrl: playStoreUrl,
        appStoreUrl: appStoreUrl,
      ),
    );
  }

  /// Widget wrapper pour protéger les routes Pro
  static Widget TranooProRouteGuard({required Widget child}) {
    return FutureBuilder<bool>(
      future: AuthServicePro.canAccessTranooPro(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data == true) {
          return child;
        }

        // Si l'accès est refusé, afficher un écran de chargement ou d'erreur
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.business_center, size: 64, color: Colors.blue),
                SizedBox(height: 16),
                Text(
                  'Vérification des autorisations professionnelles...',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Redirection en cours si nécessaire',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Widget de login temporaire
class _LoginScreen extends StatelessWidget {
  const _LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connexion')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.login, size: 64),
            SizedBox(height: 16),
            Text('Veuillez vous connecter'),
            SizedBox(height: 8),
            Text('Redirection en cours...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
