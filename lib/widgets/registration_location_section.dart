import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tranoo_pro/utils/geo_address_helper.dart';
import 'package:tranoo_pro/widgets/location_permission_dialog.dart';

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
}

/// Capture la position actuelle pour le profil (inscription vendeur / transitaire).
class RegistrationLocationSection extends StatefulWidget {
  final String userRole;
  final ValueChanged<CapturedProfileLocation?> onChanged;

  const RegistrationLocationSection({
    super.key,
    required this.userRole,
    required this.onChanged,
  });

  @override
  State<RegistrationLocationSection> createState() =>
      _RegistrationLocationSectionState();
}

class _RegistrationLocationSectionState
    extends State<RegistrationLocationSection> {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Votre position actuelle',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        const Text(
          'Utilisée pour vos annonces et la localisation fournisseur. '
          'Vous pourrez la mettre à jour dans votre profil.',
          style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.35),
        ),
        const SizedBox(height: 12),
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
                  const Text(
                    'Position enregistrée (coordonnées GPS)',
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
