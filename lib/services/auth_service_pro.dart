import 'package:firebase_auth/firebase_auth.dart';
import 'user_role_service_pro.dart';

/// Rôles disponibles dans le système (selon le backend)
enum UserRole {
  acheteur,        // Acheteur (Tranoo app) - ACCÈS REFUSÉ pour Tranoo Pro
  vendeur,         // Vendeur (Tranoo Pro) - ACCÈS AUTORISÉ
  transitaire,     // Transitaire (Tranoo Pro) - ACCÈS AUTORISÉ
  admin,           // Administrateur (Tranoo Pro) - ACCÈS AUTORISÉ
  chauffeur,       // Chauffeur (Tranoo Pro) - ACCÈS AUTORISÉ
  livreur,         // Livreur (Tranoo Pro) - ACCÈS AUTORISÉ
  agentCommercial, // Agent commercial (Tranoo Pro) - ACCÈS AUTORISÉ
}

/// Service pour gérer l'authentification et les restrictions d'accès pour Tranoo Pro
class AuthServicePro {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Obtenir le rôle de l'utilisateur connecté depuis le backend
  static Future<UserRole?> getUserRole() async {
    try {
      final roleString = await UserRoleServicePro.getUserRole();
      if (roleString == null) return null;
      
      return _parseRole(roleString);
    } catch (e) {
      print('Erreur lors de la récupération du rôle: $e');
      return null;
    }
  }

  /// Vérifier si l'utilisateur a accès à Tranoo Pro (tous sauf acheteur)
  static Future<bool> canAccessTranooPro() async {
    return await UserRoleServicePro.canAccessTranooPro();
  }

  /// Parser le rôle depuis une chaîne de caractères
  static UserRole? _parseRole(String? roleString) {
    if (roleString == null) return null;

    switch (roleString.toLowerCase()) {
      case 'acheteur':
      case 'buyer':
        return UserRole.acheteur;
      case 'vendeur':
      case 'seller':
        return UserRole.vendeur;
      case 'transitaire':
        return UserRole.transitaire;
      case 'admin':
      case 'administrateur':
        return UserRole.admin;
      case 'chauffeur':
      case 'driver':
        return UserRole.chauffeur;
      case 'livreur':
      case 'delivery':
        return UserRole.livreur;
      case 'agentcommercial':
      case 'agent_commercial':
      case 'agent':
        return UserRole.agentCommercial;
      default:
        return null;
    }
  }

  /// Convertir le rôle en chaîne de caractères
  static String roleToString(UserRole role) {
    switch (role) {
      case UserRole.acheteur:
        return 'acheteur';
      case UserRole.vendeur:
        return 'vendeur';
      case UserRole.transitaire:
        return 'transitaire';
      case UserRole.admin:
        return 'admin';
      case UserRole.chauffeur:
        return 'chauffeur';
      case UserRole.livreur:
        return 'livreur';
      case UserRole.agentCommercial:
        return 'agentCommercial';
    }
  }

  /// Déconnecter l'utilisateur
  static Future<void> logout() async {
    await _auth.signOut();
  }

  /// Vérifier si l'utilisateur est authentifié
  static bool get isAuthenticated => _auth.currentUser != null;

  /// Obtenir l'utilisateur actuel
  static User? get currentUser => _auth.currentUser;

  /// Stream des changements d'authentification
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
}
