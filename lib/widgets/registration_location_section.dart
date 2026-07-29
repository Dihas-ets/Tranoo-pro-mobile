import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tranoo_pro/utils/geo_address_helper.dart';
import 'package:tranoo_pro/widgets/location_permission_dialog.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';

class CapturedProfileLocation {
  final double latitude;
  final double longitude;
  final String address;
  final String city;

  const CapturedProfileLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.city,
  });

  static CapturedProfileLocation? fromUserMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    // Chercher l'adresse dans tous les champs possibles (profil user + article)
    final adresse = [
      data['adresse'],
      data['localisation'],
      data['lieu'],
    ].map((v) => (v ?? '').toString().trim()).firstWhere((s) => s.isNotEmpty, orElse: () => '');
    final ville = (data['ville'] ?? '').toString().trim();
    double? lat;
    double? lng;
    final loc = data['location'];
    if (loc is Map && loc['coordinates'] is List) {
      final coords = loc['coordinates'] as List;
      if (coords.length >= 2) {
        lng = (coords[0] as num?)?.toDouble();
        lat = (coords[1] as num?)?.toDouble();
      }
    }
    final fp = data['fournisseurProfil'];
    Map<String, dynamic> fournisseur = {};
    if (fp is Map) fournisseur = Map<String, dynamic>.from(fp);
    final fAddr =
        (fournisseur['adresseTexte'] ?? adresse).toString().trim();
    final fVille = (fournisseur['ville'] ?? ville).toString().trim();
    final fLat = fournisseur['latitude'];
    final fLng = fournisseur['longitude'];
    final resolvedLat = fLat is num
        ? fLat.toDouble()
        : lat ?? double.tryParse('$fLat');
    final resolvedLng = fLng is num
        ? fLng.toDouble()
        : lng ?? double.tryParse('$fLng');
    final hasCoords = resolvedLat != null && resolvedLng != null;
    final hasText = fAddr.isNotEmpty || fVille.isNotEmpty;
    if (!hasCoords && !hasText) return null;
    return CapturedProfileLocation(
      latitude: resolvedLat ?? 0,
      longitude: resolvedLng ?? 0,
      address: fAddr,
      city: fVille,
    );
  }
}

/// Capture la position actuelle pour le profil (inscription vendeur / transitaire).
class RegistrationLocationSection extends StatefulWidget {
  final String userRole;
  final ValueChanged<CapturedProfileLocation?> onChanged;
  final bool showIntro;

  const RegistrationLocationSection({
    super.key,
    required this.userRole,
    required this.onChanged,
    this.showIntro = true,
  });

  @override
  State<RegistrationLocationSection> createState() =>
      _RegistrationLocationSectionState();
}

class _RegistrationLocationSectionState
    extends State<RegistrationLocationSection> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  CapturedProfileLocation? _captured;
  bool _loading = false;
  String? _error;

  Future<void> _capture() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => LocationPermissionDialog(
            userRole: widget.userRole,
            onPermissionGranted: () {},
            onPermissionDenied: () {},
          ),
        );
        permission = await Geolocator.checkPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Autorisez la localisation dans les paramètres.';
          _loading = false;
        });
        widget.onChanged(null);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final geo = await reverseGeocode(pos.latitude, pos.longitude);
      final captured = CapturedProfileLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        address: geo.address,
        city: geo.city,
      );
      if (!mounted) return;
      setState(() {
        _captured = captured;
        _loading = false;
      });
      widget.onChanged(captured);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible d\'obtenir la position.';
        _loading = false;
      });
      widget.onChanged(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showIntro) ...[
          Text(l10n.yourCurrentPosition,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Utilisée pour vos annonces et la localisation fournisseur. '
            'Vous pourrez la mettre à jour dans votre profil.',
            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.35),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _loading ? null : _capture,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            label: Text(_captured == null
                ? 'Enregistrer ma position actuelle'
                : 'Actualiser la position'),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
        ],
        if (_captured != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFCC00).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFCC00)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_captured!.city.isNotEmpty)
                  Text(
                    _captured!.city,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                if (_captured!.address.isNotEmpty)
                  Text(
                    _captured!.address,
                    style: const TextStyle(fontSize: 13),
                  )
                else
                  Text(l10n.positionSavedGps,
                    style: TextStyle(fontSize: 13),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
