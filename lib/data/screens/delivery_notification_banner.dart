import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tranoo_pro/config/backend_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class DeliveryNotificationBanner extends StatefulWidget {
  final Map<String, dynamic> delivery;
  final bool isOnline;
  final Position? currentPosition;

  /// Appelé avec les données de la livraison acceptée (réponse API) pour navigation vers la carte.
  final void Function(Map<String, dynamic>? acceptedDelivery)? onAccepted;
  final VoidCallback? onDismissed;

  const DeliveryNotificationBanner({
    super.key,
    required this.delivery,
    required this.isOnline,
    this.currentPosition,
    this.onAccepted,
    this.onDismissed,
  });

  @override
  State<DeliveryNotificationBanner> createState() =>
      _DeliveryNotificationBannerState();
}

class _DeliveryNotificationBannerState
    extends State<DeliveryNotificationBanner> {
  double _slideValue = 0.0;
  bool _isAccepted = false;
  bool _isDismissed = false;
  double? _calculatedDistanceKm;

  // Calculer la distance depuis la position actuelle du livreur jusqu'au lieu de départ
  double _calculateDistanceToPickup() {
    if (widget.currentPosition == null) {
      // Si pas de position, utiliser la distance fournie par le backend
      return widget.delivery['distanceKm'] ?? 0.0;
    }

    final lieuDepart = widget.delivery['lieuDepart'] ?? {};
    final lat = lieuDepart['latitude'];
    final lng = lieuDepart['longitude'];

    if (lat == null || lng == null) {
      return widget.delivery['distanceKm'] ?? 0.0;
    }

    try {
      final distance = Geolocator.distanceBetween(
        widget.currentPosition!.latitude,
        widget.currentPosition!.longitude,
        (lat as num).toDouble(),
        (lng as num).toDouble(),
      );
      return distance / 1000; // Convertir en km
    } catch (e) {
      debugPrint('Erreur calcul distance: $e');
      return widget.delivery['distanceKm'] ?? 0.0;
    }
  }

  @override
  void initState() {
    super.initState();
    _calculatedDistanceKm = _calculateDistanceToPickup();
    // Auto-dismiss après 60 secondes
    Future.delayed(const Duration(seconds: 60), () {
      if (mounted && !_isAccepted) {
        _dismiss();
      }
    });
  }

  void _dismiss() {
    if (_isDismissed) return;
    setState(() {
      _isDismissed = true;
    });
    widget.onDismissed?.call();
  }

  Future<void> _acceptDelivery() async {
    if (_isAccepted || !widget.isOnline) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return;

      final deliveryId = widget.delivery['_id']?.toString();
      if (deliveryId == null) return;

      final baseUrl = getBackendBaseUrl();
      final res = await http.post(
        Uri.parse('$baseUrl/api/deliveries/$deliveryId/accept'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (res.statusCode == 200) {
        setState(() {
          _isAccepted = true;
        });
        Map<String, dynamic>? accepted;
        try {
          final data = jsonDecode(res.body) as Map<String, dynamic>?;
          accepted = data?['delivery'] as Map<String, dynamic>?;
        } catch (_) {
          accepted = null;
        }
        // Toujours remonter une livraison exploitable (au minimum l'id)
        widget.onAccepted?.call(accepted ?? {'_id': deliveryId});
        // Dismiss après acceptation
        Future.delayed(const Duration(milliseconds: 500), () {
          _dismiss();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'acceptation'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur acceptDelivery: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDistance(double? km) {
    if (km == null || km <= 0) return '--';
    if (km < 1) {
      final meters = (km * 1000).round();
      return '$meters m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  String _formatDuration(double? km) {
    if (km == null || km <= 0) return '--';
    // Vitesse moyenne 25 km/h pour les livreurs
    final minutes = (km / 25 * 60).round();
    if (minutes < 1) return '1 min';
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    final lieuDepart = widget.delivery['lieuDepart'] ?? {};
    final distanceKm = _calculatedDistanceKm ?? widget.delivery['distanceKm'] ?? 0.0;
    final prixEstime =
        widget.delivery['prixEstime'] ?? widget.delivery['fraisLivraison'] ?? 0;
    final acheteur = widget.delivery['acheteur'] ?? {};
    final acheteurNom =
        '${acheteur['prenoms'] ?? ''} ${acheteur['nom'] ?? ''}'.trim().isEmpty
            ? 'Client'
            : '${acheteur['prenoms'] ?? ''} ${acheteur['nom'] ?? ''}'.trim();

    final adresse = lieuDepart['adresse'] ?? '';
    final adresseParts = adresse
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Distance + durée en haut
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF9FAFB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Text(
                    '${_formatDistance(distanceKm)} • ${_formatDuration(distanceKm)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Prise en charge proche',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            // Ligne de séparation fine
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.grey[300],
            ),
            // Détails (activité + prix)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Section Activité avec cercle vert contenant "A"
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2E7D32),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            'A',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Activité',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '+1',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Section Prix avec icône éclair
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bolt,
                              size: 16, color: Colors.purple[400]),
                          const SizedBox(width: 4),
                          Text(
                            '${prixEstime.toStringAsFixed(0)} FCFA',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple[400],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'P x1',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Commentaires (si présents)
            if (widget.delivery['noteAcheteur'] != null &&
                (widget.delivery['noteAcheteur'] as String).isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Commentaires',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.delivery['noteAcheteur'] as String,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Adresse
            if (adresseParts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: adresseParts.map((part) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        part,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          height: 1.3,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            // Bouton glissant ACCEPTER
            _buildSlidingAcceptButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSlidingAcceptButton(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width - 32;
    final maxSlide = screenWidth * 0.85; // 85% pour déclencher l'acceptation
    final isDisabled = !widget.isOnline || _isAccepted;
    
    // Couleur de la partie qui glisse selon l'état
    Color slideColor;
    if (_isAccepted) {
      slideColor = const Color(0xFF2E7D32); // Vert après acceptation
    } else if (_slideValue > 0) {
      slideColor = const Color(0xFF2E7D32); // Vert pendant le glissement
    } else if (widget.isOnline) {
      slideColor = const Color(0xFFFFC107); // Jaune si en ligne
    } else {
      slideColor = Colors.grey[600]!; // Gris si hors ligne
    }

    return GestureDetector(
      onHorizontalDragUpdate: isDisabled ? null : (details) {
        setState(() {
          _slideValue = (_slideValue + details.delta.dx).clamp(0.0, maxSlide);
        });
        // Si glissé assez loin, accepter automatiquement
        if (_slideValue >= maxSlide * 0.8) {
          _acceptDelivery();
        }
      },
      onHorizontalDragEnd: isDisabled ? null : (_) {
        if (!_isAccepted && _slideValue < maxSlide * 0.5) {
          setState(() {
            _slideValue = 0.0;
          });
        } else if (!_isAccepted && _slideValue >= maxSlide * 0.5) {
          // Si glissé à mi-chemin, accepter
          _acceptDelivery();
        }
      },
      child: Container(
        height: 64,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: widget.isOnline && _slideValue == 0 && !_isAccepted
              ? const Color(0xFFFFC107) // Jaune si en ligne et pas encore glissé
              : Colors.grey[800], // Fond gris foncé si hors ligne ou pendant glissement
        ),
        child: Stack(
          children: [
            // Partie verte qui grandit quand on glisse (seulement si en ligne)
            if (widget.isOnline && (_slideValue > 0 || _isAccepted))
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _isAccepted
                    ? screenWidth
                    : _slideValue.clamp(0.0, screenWidth),
                child: Container(
                  decoration: BoxDecoration(
                    color: slideColor,
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
              ),
            // Texte toujours centré
            Positioned.fill(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isAccepted ? 'ACCEPTÉ' : 'Accepter',
                      style: TextStyle(
                        color: _isAccepted
                            ? Colors.white
                            : widget.isOnline
                                ? Colors.black87
                                : Colors.grey[400],
                        fontWeight: FontWeight.bold,
                        fontSize: _isAccepted ? 16 : 17,
                      ),
                    ),
                    if (!_isAccepted) const SizedBox(height: 2),
                    if (!_isAccepted)
                      Text(
                        'Coursier - ${widget.delivery['pieces']?.length ?? 1} arrêt${(widget.delivery['pieces']?.length ?? 1) > 1 ? 's' : ''}',
                        style: TextStyle(
                          color: widget.isOnline
                              ? Colors.black54
                              : Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
