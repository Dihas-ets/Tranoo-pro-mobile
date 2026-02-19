import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:tranoo_pro/config/backend_config.dart';
import 'package:tranoo_pro/data/screens/osm_map_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tranoo_pro/data/screens/chauffeur_ride_completed.dart';
import 'dart:convert';

class ChauffeurWithBuyerScreen extends StatefulWidget {
  final Map<String, dynamic> ride;

  const ChauffeurWithBuyerScreen({super.key, required this.ride});

  @override
  State<ChauffeurWithBuyerScreen> createState() =>
      _ChauffeurWithBuyerScreenState();
}

class _ChauffeurWithBuyerScreenState extends State<ChauffeurWithBuyerScreen> {
  Position? _currentPosition;
  List<OsmMarkerData> _osmMarkers = [];
  Timer? _timer;
  Duration _travelTime = Duration.zero;
  bool _isCollapsed = false;
  double _swipeDestination = 0;
  bool _destinationReached = false;
  bool _isCompleting = false;
  StreamSubscription<Position>? _locationSubscription;

  // Destination saisie
  final TextEditingController _destinationController = TextEditingController();
  String _destinationText = '';

  Map<String, dynamic> get ride => widget.ride;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _startLocationTracking();
    _buildMarkers();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _travelTime = _travelTime + const Duration(seconds: 1);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _locationSubscription?.cancel();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _buildMarkers();
        });
      }
    } catch (_) {}
  }

  void _startLocationTracking() {
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) {
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _buildMarkers();
      });
      _updateLocationOnServer(position);
    });
  }

  Future<void> _updateLocationOnServer(Position position) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return;

      final baseUrl = getBackendBaseUrl();
      await http.post(
        Uri.parse('$baseUrl/api/chauffeurs/location'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {}
  }

  void _buildMarkers() {
    final buyerLocation = ride['buyerLocation'] as Map<String, dynamic>?;
    final list = <OsmMarkerData>[];

    // Position de l'acheteur
    final buyerLatLng = latLngFromMap(buyerLocation);
    if (buyerLatLng != null) {
      list.add(OsmMarkerData(
        point: buyerLatLng,
        iconData: Icons.person_pin_circle,
        color: Colors.blue,
      ));
    }

    // Position actuelle
    if (_currentPosition != null) {
      list.add(OsmMarkerData(
        point: positionToLatLng(_currentPosition!),
        iconData: Icons.local_taxi,
        color: const Color(0xFFF8BF13),
      ));
    }

    setState(() => _osmMarkers = list);
  }

  LatLng _initialTarget() {
    final buyerLocation = ride['buyerLocation'] as Map<String, dynamic>?;
    return latLngFromMap(buyerLocation) ?? const LatLng(6.3654, 2.4183);
  }

  Future<void> _callBuyer() async {
    final acheteur = ride['acheteur'] ?? {};
    final phone = acheteur['telephone']?.toString();
    if (phone == null || phone.isEmpty) {
      _showMessage('Numéro de téléphone non disponible');
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'\s'), ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showMessage('Impossible de passer l\'appel');
    }
  }

  Future<void> _sendVoiceMessage() async {
    // TODO: Implémenter l'enregistrement de message vocal
    _showMessage('Fonctionnalité de message vocal à venir');
  }

  Future<void> _completeRide() async {
    if (_isCompleting || _destinationText.isEmpty) {
      if (_destinationText.isEmpty) {
        _showMessage('Veuillez saisir la destination finale');
      }
      return;
    }

    setState(() => _isCompleting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        _showMessage('Erreur: Utilisateur non connecté');
        setState(() => _isCompleting = false);
        return;
      }

      final rideId = ride['_id']?.toString();
      if (rideId == null) {
        _showMessage('Erreur: ID de course manquant');
        setState(() => _isCompleting = false);
        return;
      }

      final baseUrl = getBackendBaseUrl();
      final res = await http.post(
        Uri.parse('$baseUrl/api/chauffeurs/rides/$rideId/complete'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'destination': _destinationText,
          'duration': _travelTime.inSeconds,
        }),
      );

      if (res.statusCode == 200 && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => ChauffeurRideCompletedScreen(
              ride: ride,
              destination: _destinationText,
            ),
          ),
          (route) => false,
        );
      } else {
        final error = jsonDecode(res.body);
        _showMessage(error['message'] ?? 'Erreur lors de la finalisation');
        setState(() => _isCompleting = false);
      }
    } catch (e) {
      _showMessage('Erreur: ${e.toString()}');
      setState(() => _isCompleting = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildSwipeToCompleteButton() {
    final screenW = MediaQuery.of(context).size.width - 40;
    final threshold = screenW * 0.7;
    final reached = _swipeDestination >= threshold;

    return GestureDetector(
      onHorizontalDragUpdate: !_destinationReached
          ? (d) {
              final newVal =
                  (_swipeDestination + d.delta.dx).clamp(0.0, screenW);
              setState(() => _swipeDestination = newVal);
              if (newVal >= threshold) {
                HapticFeedback.mediumImpact();
                setState(() => _destinationReached = true);
                _completeRide();
              }
            }
          : null,
      onHorizontalDragEnd: !_destinationReached
          ? (_) {
              if (_swipeDestination < threshold * 0.5) {
                setState(() => _swipeDestination = 0);
              }
            }
          : null,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: Colors.grey.shade200,
        ),
        child: Stack(
          children: [
            if (_swipeDestination > 0 || _destinationReached)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: reached || _destinationReached ? screenW : _swipeDestination,
                child: Container(
                  decoration: BoxDecoration(
                    color: reached || _destinationReached
                        ? Colors.green
                        : const Color(0xFFF8BF13),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Center(
                    child: _isCompleting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            reached || _destinationReached
                                ? 'Course terminée ✓'
                                : 'Terminer la course',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ),
            if (!_destinationReached && _swipeDestination < threshold)
              Positioned.fill(
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_forward, color: Colors.white70),
                      const SizedBox(width: 8),
                      const Text(
                        'Glisser pour terminer',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Carte
          OsmMapWidget(
            center: _initialTarget(),
            zoom: 14,
            markers: _osmMarkers,
            onTapMyLocation: _getCurrentLocation,
            navigateToDestination: _initialTarget(),
          ),

          // Bouton retour
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),

          // Panneau d'informations
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildInfoPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    final acheteur = ride['acheteur'] ?? {};
    final name = '${acheteur['prenoms'] ?? ''} ${acheteur['nom'] ?? ''}'.trim();

    final height = _isCollapsed ? 120.0 : 580.0;

    return GestureDetector(
      onVerticalDragUpdate: (d) {
        if (d.delta.dy > 5) setState(() => _isCollapsed = true);
        if (d.delta.dy < -5) setState(() => _isCollapsed = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Poignée de glissement
            GestureDetector(
              onTap: () => setState(() => _isCollapsed = !_isCollapsed),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),

            if (!_isCollapsed)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // En-tête
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.green.shade700,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Avec le client',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timer,
                                    size: 16, color: Colors.orange.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDuration(_travelTime),
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Profil client compact
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: const Color(0xFFF8BF13),
                              backgroundImage: acheteur['photo'] != null &&
                                      (acheteur['photo'] as String).isNotEmpty
                                  ? NetworkImage(acheteur['photo'] as String)
                                  : null,
                              child: acheteur['photo'] == null ||
                                      (acheteur['photo'] as String).isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 28,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                name.isNotEmpty ? name : 'Client',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _callBuyer,
                              icon: const Icon(Icons.phone),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _sendVoiceMessage,
                              icon: const Icon(Icons.mic),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Instructions
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.blue.shade50,
                              Colors.blue.shade100,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade700,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Demandez verbalement la destination au client',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue.shade900,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Saisie de la destination
                      const Text(
                        'Destination finale',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _destinationController,
                        decoration: InputDecoration(
                          hintText: 'Entrez la destination du client',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFF8BF13),
                              width: 2,
                            ),
                          ),
                          prefixIcon: Icon(
                            Icons.location_on,
                            color: Colors.grey.shade600,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (value) {
                          setState(() {
                            _destinationText = value.trim();
                          });
                        },
                      ),

                      const SizedBox(height: 24),

                      // Bouton de finalisation par glissement
                      _buildSwipeToCompleteButton(),

                      const SizedBox(height: 12),

                      // Message d'aide
                      Center(
                        child: Text(
                          'La destination est nécessaire pour terminer',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              // Version réduite
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFFF8BF13),
                          backgroundImage: acheteur['photo'] != null &&
                                  (acheteur['photo'] as String).isNotEmpty
                              ? NetworkImage(acheteur['photo'] as String)
                              : null,
                          child: acheteur['photo'] == null ||
                                  (acheteur['photo'] as String).isEmpty
                              ? const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 24,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Avec le client',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              _formatDuration(_travelTime),
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Icon(
                      Icons.keyboard_arrow_up,
                      color: Colors.grey.shade600,
                      size: 28,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
