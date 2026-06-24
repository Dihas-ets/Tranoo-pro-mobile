import 'package:flutter/material.dart';
import 'package:tranoo_pro/widgets/transitaire_profile_ui.dart';

/// Profil transitaire — public (acheteur) ou propriétaire (accueil pro).
class TransitaireProfilePage extends StatelessWidget {
  final Map<String, dynamic> transitaire;
  final bool isOwner;

  const TransitaireProfilePage({
    super.key,
    required this.transitaire,
    this.isOwner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          TransitaireProfileHelpers.displayName(transitaire),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: kTransitaireNavy,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kTransitaireNavy,
        elevation: 0,
        centerTitle: true,
      ),
      body: TransitaireProfileView(
        user: transitaire,
        isOwner: isOwner,
      ),
    );
  }
}
