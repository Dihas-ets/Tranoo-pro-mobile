import 'package:flutter/material.dart';
import '../services/user_service.dart';

enum UserRole { 
  vendeur,           // ← COMPATIBILITÉ EXISTANTE (mixte)
  vendeurVehicules,  // ← NOUVEAU : uniquement véhicules
  vendeurPieces,     // ← NOUVEAU : uniquement pièces
  transitaire, 
  chauffeur, 
  agentCommercial, 
  livreur 
}

UserRole? stringToUserRole(String? role) {
  switch (role) {
    case 'vendeur':
      return UserRole.vendeur;
    case 'vendeurVehicules':
      return UserRole.vendeurVehicules;
    case 'vendeurPieces':
      return UserRole.vendeurPieces;
    case 'transitaire':
      return UserRole.transitaire;
    case 'chauffeur':
      return UserRole.chauffeur;
    case 'agentCommercial':
      return UserRole.agentCommercial;
    case 'livreur':
      return UserRole.livreur;
    default:
      return null;
  }
}

String userRoleToString(UserRole role) {
  switch (role) {
    case UserRole.vendeur:
      return 'vendeur';
    case UserRole.vendeurVehicules:
      return 'vendeurVehicules';
    case UserRole.vendeurPieces:
      return 'vendeurPieces';
    case UserRole.transitaire:
      return 'transitaire';
    case UserRole.chauffeur:
      return 'chauffeur';
    case UserRole.agentCommercial:
      return 'agentCommercial';
    case UserRole.livreur:
      return 'livreur';
  }
}

class RoleRedirect extends StatelessWidget {
  final Widget child;
  final UserRole requiredRole;

  const RoleRedirect({
    super.key,
    required this.child,
    required this.requiredRole,
  });

  @override
  Widget build(BuildContext context) {
    final userService = UserService();

    if (userService.currentRole != requiredRole) {
      return const Center(child: Text('Accès non autorisé'));
    }

    return child;
  }
}
