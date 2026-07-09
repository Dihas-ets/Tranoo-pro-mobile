import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tranoo_pro/services/user_service.dart';
import 'package:tranoo_pro/widgets/registration_location_section.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';

/// Met à jour la position du vendeur / transitaire sur le profil.
class ProfileLocationTile extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final VoidCallback? onUpdated;

  const ProfileLocationTile({super.key, this.userData, this.onUpdated});

  @override
  State<ProfileLocationTile> createState() => _ProfileLocationTileState();
}

class _ProfileLocationTileState extends State<ProfileLocationTile> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  bool _saving = false;
  bool _editing = false;
  CapturedProfileLocation? _savedLocation;

  @override
  void initState() {
    super.initState();
    _applyUserData(widget.userData);
  }

  @override
  void didUpdateWidget(ProfileLocationTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userData != oldWidget.userData) {
      _applyUserData(widget.userData);
    }
  }

  void _applyUserData(Map<String, dynamic>? data) {
    _savedLocation = CapturedProfileLocation.fromUserMap(data);
    if (_savedLocation != null) {
      _editing = false;
    }
  }

  bool get _hasSavedPosition => _savedLocation != null;

  Future<void> _save(CapturedProfileLocation loc) async {
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await user.getIdToken();
      final dio = Dio(
        BaseOptions(
          baseUrl: UserService().dio.options.baseUrl,
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      final me = await dio.get('/protected/me');
      final tel = (me.data['user']?['telephone'] ?? '').toString();
      await dio.patch(
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
        setState(() {
          _savedLocation = loc;
          _editing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profilePositionUpdated)),
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

  Widget _buildSavedLocationRow() {
    final loc = _savedLocation!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.location_on, color: Color(0xFFF8BF13)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.yourCurrentPosition,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              if (loc.city.isNotEmpty)
                Text(
                  loc.city,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              if (loc.address.isNotEmpty)
                Text(
                  loc.address,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                )
              else if (loc.latitude != 0 || loc.longitude != 0)
                Text(
                  l10n.positionSavedGps,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Modifier la position',
          onPressed: _saving ? null : () => setState(() => _editing = true),
          icon: const Icon(Icons.edit_outlined, color: Colors.black87),
        ),
      ],
    );
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
            if (_hasSavedPosition && !_editing)
              _buildSavedLocationRow()
            else ...[
              RegistrationLocationSection(
                userRole: 'vendeur',
                showIntro: !_hasSavedPosition,
                onChanged: (loc) async {
                  if (loc != null && !_saving) await _save(loc);
                },
              ),
              if (_hasSavedPosition && _editing)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() => _editing = false),
                    child: Text(l10n.cancel),
                  ),
                ),
            ],
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
