import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tranoo_pro/config/backend_config.dart';

class SuiviGpsPage extends StatefulWidget {
  const SuiviGpsPage({super.key});

  @override
  State<SuiviGpsPage> createState() => _SuiviGpsPageState();
}

class _SuiviGpsPageState extends State<SuiviGpsPage> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  List<Map<String, dynamic>> _activeDeliveries = [];
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  bool _loading = true;
  bool _isTracking = false;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await _getCurrentLocation();
    await _loadActiveDeliveries();
    _setupMap();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      print('Erreur géolocalisation: $e');
    }
  }

  Future<void> _loadActiveDeliveries() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return;

      final baseUrl = getBackendBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/api/livreurs/deliveries/active'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _activeDeliveries =
              List<Map<String, dynamic>>.from(data['deliveries'] ?? []);
        });
      }
    } catch (e) {
      print('Erreur chargement livraisons: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _setupMap() {
    if (_currentPosition == null) return;

    // Marqueur position actuelle
    _markers.add(
      Marker(
        markerId: const MarkerId('current_position'),
        position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Ma position'),
      ),
    );

    // Marqueurs et tracés pour chaque livraison active
    for (var delivery in _activeDeliveries) {
      final lieuDepart = delivery['lieuDepart'] ?? {};
      final lieuDestination = delivery['lieuDestination'] ?? {};
      final locationHistory = delivery['locationHistory'] ?? [];

      // Marqueur départ
      if (lieuDepart['latitude'] != null && lieuDepart['longitude'] != null) {
        _markers.add(
          Marker(
            markerId: MarkerId('depart_${delivery['_id']}'),
            position: LatLng(
              lieuDepart['latitude'].toDouble(),
              lieuDepart['longitude'].toDouble(),
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: InfoWindow(
              title: 'Départ',
              snippet: lieuDepart['adresse'] ?? '',
            ),
          ),
        );
      }

      // Marqueur destination
      if (lieuDestination['latitude'] != null &&
          lieuDestination['longitude'] != null) {
        _markers.add(
          Marker(
            markerId: MarkerId('destination_${delivery['_id']}'),
            position: LatLng(
              lieuDestination['latitude'].toDouble(),
              lieuDestination['longitude'].toDouble(),
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: 'Destination',
              snippet: lieuDestination['adresse'] ?? '',
            ),
          ),
        );

        // Tracé jaune du départ à la destination
        if (lieuDepart['latitude'] != null &&
            lieuDepart['longitude'] != null) {
          _polylines.add(
            Polyline(
              polylineId: PolylineId('route_${delivery['_id']}'),
              points: [
                LatLng(
                  lieuDepart['latitude'].toDouble(),
                  lieuDepart['longitude'].toDouble(),
                ),
                LatLng(
                  lieuDestination['latitude'].toDouble(),
                  lieuDestination['longitude'].toDouble(),
                ),
              ],
              color: const Color(0xFFF8BF13), // Jaune Tranoo
              width: 5,
              patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            ),
          );
        }
      }

      // Tracé de l'historique GPS (jaune continu)
      if (locationHistory.isNotEmpty) {
        List<LatLng> historyPoints = [];
        for (var location in locationHistory) {
          if (location['latitude'] != null && location['longitude'] != null) {
            historyPoints.add(
              LatLng(
                location['latitude'].toDouble(),
                location['longitude'].toDouble(),
              ),
            );
          }
        }
        if (historyPoints.length > 1) {
          _polylines.add(
            Polyline(
              polylineId: PolylineId('history_${delivery['_id']}'),
              points: historyPoints,
              color: const Color(0xFFF8BF13), // Jaune Tranoo
              width: 4,
            ),
          );
        }
      }
    }

    setState(() {});
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_currentPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          14.0,
        ),
      );
    }
  }

  Future<void> _centerOnCurrentLocation() async {
    await _getCurrentLocation();
    if (_currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          15.0,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _currentPosition == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Suivi GPS'),
          backgroundColor: const Color(0xFFF8BF13),
          foregroundColor: Colors.black,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Suivi GPS',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFF8BF13),
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerOnCurrentLocation,
            tooltip: 'Centrer sur ma position',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              zoom: 14.0,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            markers: _markers,
            polylines: _polylines,
            mapType: MapType.normal,
            zoomControlsEnabled: false,
            compassEnabled: true,
          ),
          // Légende
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLegendItem(
                    Colors.blue,
                    'Ma position',
                  ),
                  const SizedBox(height: 8),
                  _buildLegendItem(
                    Colors.green,
                    'Départ',
                  ),
                  const SizedBox(height: 8),
                  _buildLegendItem(
                    Colors.red,
                    'Destination',
                  ),
                  const SizedBox(height: 8),
                  _buildLegendItem(
                    const Color(0xFFF8BF13),
                    'Itinéraire',
                    isLine: true,
                  ),
                ],
              ),
            ),
          ),
          // Liste des livraisons actives
          if (_activeDeliveries.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Text(
                            'Livraisons actives',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_activeDeliveries.length}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _activeDeliveries.length,
                        itemBuilder: (context, index) {
                          final delivery = _activeDeliveries[index];
                          return _buildDeliveryMiniCard(delivery);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, {bool isLine = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLine)
          Container(
            width: 20,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          )
        else
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDeliveryMiniCard(Map<String, dynamic> delivery) {
    final lieuDestination = delivery['lieuDestination'] ?? {};
    final distanceKm = delivery['distanceKm'] ?? 0;

    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Livraison #${delivery['_id']?.toString().substring(0, 8) ?? 'N/A'}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
              Expanded(
                child: Text(
                  lieuDestination['adresse'] ?? 'Destination',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.straighten, size: 16, color: Colors.grey[600]),
              Text(
                '${distanceKm.toStringAsFixed(1)} km',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
