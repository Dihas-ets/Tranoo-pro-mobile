import 'package:flutter/material.dart';
// ——— Google Maps (grisé — réactiver si clé API) ———
// import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:tranoo_pro/config/backend_config.dart';
import 'package:tranoo_pro/data/screens/osm_map_widget.dart';
// url_launcher n'est pas nécessaire ici : la navigation est gérée par `OsmMapWidget.openNavigation`.

class SuiviGpsPage extends StatefulWidget {
  const SuiviGpsPage({super.key});

  @override
  State<SuiviGpsPage> createState() => _SuiviGpsPageState();
}

class _SuiviGpsPageState extends State<SuiviGpsPage> {
  // ——— Google Maps (grisé) ———
  // GoogleMapController? _mapController;
  Position? _currentPosition;
  List<Map<String, dynamic>> _activeDeliveries = [];
  List<OsmMarkerData> _osmMarkers = [];
  List<LatLng>? _polylinePoints;
  bool _loading = true;
  Map<String, dynamic>? _selectedDelivery;
  LatLng? _selectedPickup;
  LatLng? _selectedDropoff;

  LatLng? get _myLatLng =>
      _currentPosition != null ? positionToLatLng(_currentPosition!) : null;

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

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
    final list = <OsmMarkerData>[];

    if (_currentPosition != null) {
      list.add(OsmMarkerData(
        point: positionToLatLng(_currentPosition!),
        iconData: Icons.my_location,
        color: Colors.blue, // légende: ma position
      ));
    }

    final focus = _selectedDelivery;
    if (focus != null) {
      final lieuDepart = _asMap(focus['lieuDepart']);
      final lieuDestination = _asMap(focus['lieuDestination']);

      final p1 = latLngFromMap(lieuDepart);
      final p2 = latLngFromMap(lieuDestination);

      _selectedPickup = p1;
      _selectedDropoff = p2;

      if (p1 != null) {
        list.add(
          OsmMarkerData(
            point: p1,
            iconData: Icons.store,
            color: Colors.green, // légende: départ
            onTap: () => OsmMapWidget.openNavigation(p1),
          ),
        );
      }
      if (p2 != null) {
        list.add(
          OsmMarkerData(
            point: p2,
            iconData: Icons.person_pin,
            color: Colors.red, // légende: destination
            onTap: () => OsmMapWidget.openNavigation(p2),
          ),
        );
      }
    } else {
      _selectedPickup = null;
      _selectedDropoff = null;
    }

    setState(() {
      _osmMarkers = list;
    });
  }

  // ——— Google Maps (grisé) ———
  // void _onMapCreated(GoogleMapController controller) { ... }
  // Future<void> _centerOnCurrentLocation() async { ... }

  Future<void> _centerOnCurrentLocation() async {
    await _getCurrentLocation();
    _setupMap();
  }

  Future<void> _focusOnDelivery(Map<String, dynamic> delivery) async {
    setState(() {
      _selectedDelivery = delivery;
    });
    _setupMap();

    final from = _myLatLng;
    final pickup = _selectedPickup;
    final drop = _selectedDropoff;

    final colisRecupere = delivery['colisRecupere'] == true;
    final nextTarget = colisRecupere ? drop : pickup;

    if (from == null || nextTarget == null) {
      setState(() => _polylinePoints = null);
      return;
    }

    // Dessiner une vraie route (OSRM) pour la prochaine étape.
    final pts = await _fetchOsrmRoute(from, nextTarget);
    if (!mounted) return;
    setState(() {
      _polylinePoints = (pts != null && pts.length >= 2) ? pts : [from, nextTarget];
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            colisRecupere
                ? 'Itinéraire prêt. Appuyez sur le marqueur rouge pour ouvrir Google Maps.'
                : 'Itinéraire prêt. Appuyez sur le marqueur vert pour ouvrir Google Maps.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<List<LatLng>?> _fetchOsrmRoute(LatLng from, LatLng to) async {
    try {
      final url =
          'https://router.project-osrm.org/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
      final res = await http.get(
        Uri.parse('$url?overview=full&geometries=geojson&alternatives=false&steps=true'),
      );
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      if (data is! Map) return null;
      final routes = data['routes'];
      if (routes is! List || routes.isEmpty) return null;
      final geometry = routes.first['geometry'];
      if (geometry is! Map) return null;
      final coords = geometry['coordinates'];
      if (coords is! List) return null;
      final pts = <LatLng>[];
      for (final c in coords) {
        if (c is List && c.length >= 2) {
          final lon = (c[0] as num).toDouble();
          final lat = (c[1] as num).toDouble();
          pts.add(LatLng(lat, lon));
        }
      }
      return pts;
    } catch (e) {
      debugPrint('OSRM route error: $e');
      return null;
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
          OsmMapWidget(
            center: positionToLatLng(_currentPosition!),
            zoom: 14,
            markers: _osmMarkers,
            polylinePoints: _polylinePoints,
            onTapMyLocation: _centerOnCurrentLocation,
          ),
          // ——— Google Maps (grisé) ———
          // GoogleMap( ... ),
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
                    icon: Icons.my_location,
                    color: Colors.blue,
                    label: 'Ma position',
                  ),
                  const SizedBox(height: 8),
                  _buildLegendItem(
                    icon: Icons.store,
                    color: Colors.green,
                    label: 'Départ',
                  ),
                  const SizedBox(height: 8),
                  _buildLegendItem(
                    icon: Icons.person_pin,
                    color: Colors.red,
                    label: 'Destination',
                  ),
                  const SizedBox(height: 8),
                  _buildLegendItem(
                    icon: Icons.alt_route,
                    color: const Color(0xFFF8BF13),
                    label: 'Itinéraire',
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

  Widget _buildLegendItem({
    required IconData icon,
    required Color color,
    required String label,
    bool isLine = false,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
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

    return InkWell(
      onTap: () => _focusOnDelivery(delivery),
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
      ),
    );
  }

  @override
  void dispose() {
    // _mapController?.dispose(); ——— Google Maps (grisé)
    super.dispose();
  }
}
