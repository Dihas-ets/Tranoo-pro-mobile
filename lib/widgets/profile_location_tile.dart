import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tranoo_pro/services/user_service.dart';
import 'package:tranoo_pro/widgets/registration_location_section.dart';

/// Met à jour la position du vendeur / transitaire sur le profil.
class ProfileLocationTile extends StatefulWidget {
  final VoidCallback? onUpdated;

  const ProfileLocationTile({super.key, this.onUpdated});

  @override
  State<ProfileLocationTile> createState() => _ProfileLocationTileState();
}

class _ProfileLocationTileState extends State<ProfileLocationTile> {
  bool _saving = false;

  Future<void> _save(CapturedProfileLocation loc) async {
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await user.getIdToken();
      final me = await Dio(
        BaseOptions(
          baseUrl: UserService().dio.options.baseUrl,
          headers: {'Authorization': 'Bearer $token'},
        ),
      ).get('/protected/me');
      final tel = (me.data['user']?['telephone'] ?? '').toString();
      await Dio(
        BaseOptions(
          baseUrl: UserService().dio.options.baseUrl,
          headers: {'Authorization': 'Bearer $token'},
        ),
      ).patch(
        '/users/me',
        data: {
          'adresse': loc.address,
          'ville': loc.city,
          'latitude': loc.latitude,
          'longitude': loc.longitude,
          'fournisseurProfil': {
            if (tel.isNotEmpty) 'telephone': tel,
            'adresseTexte': loc.address,
            'ville': loc.city,
            'latitude': loc.latitude,
            'longitude': loc.longitude,
          },
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Position du profil mise à jour')),
        );
        widget.onUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RegistrationLocationSection(
              userRole: 'vendeur',
              onChanged: (loc) async {
                if (loc != null && !_saving) await _save(loc);
              },
            ),
            if (_saving)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
