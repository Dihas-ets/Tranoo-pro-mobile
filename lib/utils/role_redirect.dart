import 'package:flutter/material.dart';
import '../services/user_service.dart';

enum UserRole { vendeur, transitaire, chauffeur, agentCommercial, livreur }

UserRole? stringToUserRole(String? role) {
  switch (role) {
    case 'vendeur':
      return UserRole.vendeur;
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
