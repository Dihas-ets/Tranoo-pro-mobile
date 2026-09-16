import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'package:tranoo_pro/l10n/app_localizations.dart';
// ——— Google Maps (grisé — réactiver si clé API) ———
// import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:tranoo_pro/config/backend_config.dart';
import 'package:tranoo_pro/data/screens/delivery_flow_screens.dart';
import 'package:tranoo_pro/data/screens/osm_map_widget.dart';
import 'package:url_launcher/url_launcher.dart';

// =============================================================================
// CODE MORT — carte livraison livreur interne (DeliveryMapScreen)
// -----------------------------------------------------------------------------
// Gelé avec l'UI livreur Tranoo Pro. Livraison via Livro. Ne pas supprimer.
// =============================================================================

/// Écran cartographie après acceptation d'une livraison.
/// Carte avec destination fournisseur, overlay rabattable avec 2 onglets :
/// - Colis & Fournisseur (récupération)
/// - Acheteur (livraison finale)
class DeliveryMapScreen extends StatefulWidget {
  final Map<String, dynamic> delivery;

  const DeliveryMapScreen({super.key, required this.delivery});

  @override
  State<DeliveryMapScreen> createState() => _DeliveryMapScreenState();
}

class _DeliveryMapScreenState extends State<DeliveryMapScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  // ——— Google Maps (grisé) ———
  // GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isCollapsed = false;
  int _selectedTab = 0; // 0..(pickups-1) = fournisseurs, last = acheteur
  double _swipePickup = 0;
  double _swipeBuyerArrival = 0;
  double _swipeDeliver = 0;
  bool _pickupDone = false;
  bool _deliverDone = false;
  bool _buyerArrived = false;
  bool _isOpeningPickupFlow = false;
  bool _isCompletingSwipe = false;
  List<OsmMarkerData> _osmMarkers = [];

  Map<String, dynamic> get delivery => widget.delivery;
  bool get colisRecupere => delivery['colisRecupere'] == true;

  List<Map<String, dynamic>> get _pickups {
    final raw = delivery['pickups'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  bool get _hasMultiPickups => _pickups.isNotEmpty;

  int get _buyerTabIndex => _hasMultiPickups ? _pickups.length : 1;

  bool get _isBuyerTab => _selectedTab == _buyerTabIndex;

  int? get _currentPickupIndex {
    if (!_hasMultiPickups) return 0;
    if (_isBuyerTab) return null;
    return _selectedTab.clamp(0, _pickups.length - 1);
  }

  bool get _currentPickupDone {
    if (_isBuyerTab) return false;
    if (!_hasMultiPickups) return _pickupDone;
    final idx = _currentPickupIndex;
    if (idx == null) return false;
    final p = _pickups[idx];
    return p['statut'] == 'picked_up';
  }

  int get _pickedCount {
    if (!_hasMultiPickups) return _pickupDone ? 1 : 0;
    return _pickups.where((p) => p['statut'] == 'picked_up').length;
  }

  /// Normalise une valeur dynamique en `Map<String, dynamic>`.
  /// Certains anciens enregistrements/retours API peuvent renvoyer `[]` au lieu de `{}`.
  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  String _cleanId(String? raw) {
    final s = raw?.replaceAll('"', '').replaceAll("'", '').trim();
    return (s == null || s.isEmpty) ? '—' : s;
  }

  bool _looksLikeMongoId(String s) {
    final clean = _cleanId(s);
    return RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(clean);
  }

  String _formatOrderNumber(String? raw) {
    final clean = _cleanId(raw);
    if (clean == '—') return clean;
    if (_looksLikeMongoId(clean)) {
      return 'CMD #${clean.substring(0, 8).toUpperCase()}';
    }
    return clean;
  }

  double? _haversineKm(LatLng? a, LatLng? b) {
    if (a == null || b == null) return null;
    const r = 6371.0;
    final dLat = (b.latitude - a.latitude) * (3.141592653589793 / 180.0);
    final dLon = (b.longitude - a.longitude) * (3.141592653589793 / 180.0);
    final lat1 = a.latitude * (3.141592653589793 / 180.0);
    final lat2 = b.latitude * (3.141592653589793 / 180.0);
    final h = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(lat1) * cos(lat2) * (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(h), sqrt(1 - h));
    return r * c;
  }

  String _kmLabel(double? km) {
    if (km == null) return '—';
    return '${km.toStringAsFixed(1)} km';
  }

  /// Récupère le "numéro de commande" de façon robuste.
  /// Selon le backend, `orderId` peut être un id (String) OU un objet peuplé (Map).
  String _extractOrderNumberFromDelivery() {
    // Champs directs éventuels
    final direct = delivery['orderNumber'] ??
        delivery['numeroCommande'] ??
        delivery['numero_commande'] ??
        delivery['referenceCommande'] ??
        delivery['reference_commande'];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return _formatOrderNumber(direct.toString());
    }

    // Champs "order" / "commande" / "orderId" (peut être Map ou String)
    final ref = delivery['order'] ?? delivery['commande'] ?? delivery['orderId'];
    if (ref is Map) {
      final m = _asMap(ref);
      final code = m['orderNumber'] ??
          m['numeroCommande'] ??
          m['numero_commande'] ??
          m['reference'] ??
          m['code'];
      if (code != null && code.toString().trim().isNotEmpty) {
        return _formatOrderNumber(code.toString());
      }
      final id = m['_id'] ?? m['id'];
      if (id != null && id.toString().trim().isNotEmpty) {
        return _formatOrderNumber(id.toString());
      }
    } else if (ref != null && ref.toString().trim().isNotEmpty) {
      return _formatOrderNumber(ref.toString());
    }

    return '—';
  }

  Widget _cardSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
    Color? tint,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: (tint ?? Colors.transparent).withOpacity(0.10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (tint ?? const Color(0xFFF8BF13)).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: tint ?? const Color(0xFFF8BF13)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _pickupDone = colisRecupere;
    if (colisRecupere) _selectedTab = _buyerTabIndex;
    _buyerArrived = delivery['dateArrivee'] != null;
    _getCurrentLocation();
    _buildMarkers();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() => _currentPosition = position);
        _buildMarkers();
        // _fitBounds(); ——— Google Maps (grisé)
      }
    } catch (e) {
      if (mounted) setState(() {});
    }
  }

  void _buildMarkers() {
    final lieuDepart = _asMap(delivery['lieuDepart']);
    final lieuDestination = _asMap(delivery['lieuDestination']);
    final list = <OsmMarkerData>[];

    if (_hasMultiPickups) {
      for (int i = 0; i < _pickups.length; i++) {
        final p = _pickups[i];
        final dep = _asMap(p['lieuDepart']);
        final ll = latLngFromMap(dep);
        if (ll != null) {
          list.add(OsmMarkerData(
              point: ll, iconData: Icons.store, color: Colors.blue));
        }
      }
    } else {
      final pickup = latLngFromMap(lieuDepart);
      if (pickup != null) {
        list.add(OsmMarkerData(
            point: pickup, iconData: Icons.store, color: Colors.blue));
      }
    }
    final dest = latLngFromMap(lieuDestination);
    if (dest != null) {
      list.add(OsmMarkerData(
          point: dest, iconData: Icons.person_pin, color: Colors.green));
    }
    if (_currentPosition != null) {
      list.add(OsmMarkerData(
        point: positionToLatLng(_currentPosition!),
        iconData: Icons.my_location,
        color: Colors.orange,
      ));
    }
    setState(() => _osmMarkers = list);
  }

  // ——— Google Maps _fitBounds (grisé) ———
  // void _fitBounds() { ... }

  LatLng _initialTarget() {
    if (_hasMultiPickups) {
      final idx = _currentPickupIndex ?? 0;
      final dep = _asMap(_pickups[idx]['lieuDepart']);
      final p = latLngFromMap(dep);
      return p ?? const LatLng(14.716677, -17.467686);
    }
    final p = latLngFromMap(_asMap(delivery['lieuDepart']));
    return p ?? const LatLng(14.716677, -17.467686);
  }

  Future<void> _callPhone(String? phone) async {
    final tel = phone?.trim();
    if (tel == null || tel.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: tel.replaceAll(RegExp(r'\s'), ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openOptimizedRouteTo({
    required LatLng? destination,
    LatLng? waypoint,
  }) async {
    if (destination == null) return;
    final origin = _currentPosition != null
        ? positionToLatLng(_currentPosition!)
        : null;

    final query = <String, String>{
      'api': '1',
      'destination': '${destination.latitude},${destination.longitude}',
      'travelmode': 'driving',
    };
    if (origin != null) {
      query['origin'] = '${origin.latitude},${origin.longitude}';
    }
    if (waypoint != null) {
      query['waypoints'] = '${waypoint.latitude},${waypoint.longitude}';
    }

    final uri = Uri.https('www.google.com', '/maps/dir/', query);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _notifyDeliver() async {
    if (_deliverDone) return;
    final id = delivery['_id']?.toString();
    if (id == null) return;
    try {
      // QR obligatoire avant livraison (fin)
      final expectedOrderId = _extractOrderId();
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => DeliveryQrScannerScreen(
            expectedOrderId: expectedOrderId,
            expectedDeliveryId: id,
          ),
        ),
      );
      if (ok != true) return;

      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      if (token == null) return;
      final res = await http.post(
        Uri.parse('${getBackendBaseUrl()}/api/deliveries/$id/deliver'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200 && mounted) {
        setState(() => _deliverDone = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.packageDelivered)),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  String _extractOrderId() {
    final order = delivery['orderId'];
    if (order is Map) {
      return (order['_id'] ?? order['id'] ?? '').toString();
    }
    return (order ?? '').toString();
  }

  Future<void> _notifyPickup() async {
    if (_isBuyerTab) return;
    if (_currentPickupDone || _isOpeningPickupFlow) return;
    setState(() {
      _isOpeningPickupFlow = true;
      _swipePickup = 0;
    });
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PackageValidationScreen(
          delivery: delivery,
          pickupIndex: _currentPickupIndex,
        ),
      ),
    );
    await _refreshDeliveryState();
    if (mounted) {
      setState(() => _isOpeningPickupFlow = false);
    }
  }

  Future<void> _refreshDeliveryState() async {
    final id = delivery['_id']?.toString();
    if (id == null) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      if (token == null) return;
      final res = await http.get(
        Uri.parse('${getBackendBaseUrl()}/api/deliveries/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final updated = (jsonDecode(res.body) as Map<String, dynamic>)['delivery']
            as Map<String, dynamic>?;
        if (updated != null && mounted) {
          setState(() {
            delivery
              ..clear()
              ..addAll(updated);
            _pickupDone = delivery['colisRecupere'] == true;
            _buyerArrived = delivery['dateArrivee'] != null;
            if (_pickupDone) {
              _selectedTab = _buyerTabIndex;
            } else if (_hasMultiPickups) {
              final next =
                  _pickups.indexWhere((p) => p['statut'] != 'picked_up');
              if (next >= 0) _selectedTab = next;
            }
          });
          _buildMarkers();
        }
      }
    } catch (_) {}
  }

  Future<void> _notifyArrival() async {
    final id = delivery['_id']?.toString();
    if (id == null) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      if (token == null) return;
      final res = await http.post(
        Uri.parse('${getBackendBaseUrl()}/api/deliveries/$id/arrived'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200 && mounted) {
        setState(() => _buyerArrived = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.arrivalNotified)),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.arrivalError(res.statusCode.toString()))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.arrivalError(e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Destination "Naviguer" selon l'onglet courant
    LatLng? navDest;
    if (_isBuyerTab) {
      navDest = latLngFromMap(_asMap(delivery['lieuDestination']));
    } else if (_hasMultiPickups) {
      final idx = _currentPickupIndex ?? 0;
      navDest = latLngFromMap(_asMap(_pickups[idx]['lieuDepart']));
    } else {
      navDest = latLngFromMap(_asMap(delivery['lieuDepart']));
    }
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ——— Carte gratuite OpenStreetMap (Flutter Map) ———
          OsmMapWidget(
            center: _initialTarget(),
            zoom: 14,
            markers: _osmMarkers,
            onTapMyLocation: _getCurrentLocation,
            navigateToDestination: navDest,
          ),
          // ——— Google Maps (grisé — réactiver si clé API) ———
          // GoogleMap(
          //   initialCameraPosition: CameraPosition(
          //     target: _initialTarget(),
          //     zoom: 14,
          //   ),
          //   onMapCreated: (c) {
          //     _mapController = c;
          //     _fitBounds();
          //   },
          //   myLocationEnabled: true,
          //   myLocationButtonEnabled: true,
          //   markers: _markers,
          //   mapType: MapType.normal,
          //   zoomControlsEnabled: false,
          // ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: SafeArea(
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildOverlay(),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    final screenH = MediaQuery.of(context).size.height;
    final expandedH = (screenH * 0.62).clamp(420.0, 620.0);
    final height = _isCollapsed ? 100.0 : expandedH;
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildDragHandle(),
            if (!_isCollapsed) ...[
              _buildTabSwitcher(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    MediaQuery.of(context).padding.bottom + 140,
                  ),
                  child: _isBuyerTab
                      ? _buildAcheteurContent()
                      : _buildFournisseurContent(),
                ),
              ),
            ] else
              _buildCollapsedContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return GestureDetector(
      onTap: () => setState(() => _isCollapsed = !_isCollapsed),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (_hasMultiPickups) ...[
            for (int i = 0; i < _pickups.length; i++) ...[
              _buildTabIcon(i, Icons.inventory_2_outlined, 'Fournisseur ${i + 1}'),
              const SizedBox(width: 8),
            ],
            _buildTabIcon(_buyerTabIndex, Icons.person_outline, 'Acheteur'),
          ] else ...[
            _buildTabIcon(0, Icons.inventory_2_outlined, 'Colis & Fournisseur'),
            const SizedBox(width: 8),
            _buildTabIcon(1, Icons.person_outline, 'Acheteur'),
          ],
        ],
      ),
    );
  }

  Widget _buildTabIcon(int index, IconData icon, String tooltip) {
    final selected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        if (index == _buyerTabIndex && !_pickupDone) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Validez "Sur place" chez le fournisseur avant l\'étape acheteur.',
              ),
            ),
          );
          return;
        }
        setState(() => _selectedTab = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF8BF13) : Colors.grey[200],
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 22, color: selected ? Colors.black87 : Colors.grey),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: selected ? Colors.black54 : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedContent() {
    final lieuDepart = _asMap(delivery['lieuDepart']);
    final lieuDestination = _asMap(delivery['lieuDestination']);
    String dest;
    if (_isBuyerTab) {
      dest = (lieuDestination['adresse'] ?? 'Acheteur').toString();
    } else if (_hasMultiPickups) {
      final idx = _currentPickupIndex ?? 0;
      dest = (_asMap(_pickups[idx]['lieuDepart'])['adresse'] ?? 'Fournisseur')
          .toString();
    } else {
      dest = (lieuDepart['adresse'] ?? 'Fournisseur').toString();
    }
    final acheteur = _asMap(delivery['acheteur']);
    final name = '${acheteur['prenoms'] ?? ''} ${acheteur['nom'] ?? ''}'.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pickupDone
                      ? 'En livraison'
                      : (_hasMultiPickups
                          ? 'Pickups ${_pickedCount}/${_pickups.length}'
                          : 'En direction du fournisseur'),
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  _isBuyerTab ? (name.isNotEmpty ? name : dest) : dest,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              delivery['distanceKm'] != null
                  ? '${(delivery['distanceKm'] as num).toStringAsFixed(1)} km'
                  : '—',
              style: TextStyle(
                color: Colors.orange[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFournisseurContent() {
    final pickup = _hasMultiPickups && _currentPickupIndex != null
        ? _pickups[_currentPickupIndex!]
        : null;
    final lieuDepart = pickup != null ? _asMap(pickup['lieuDepart']) : _asMap(delivery['lieuDepart']);
    final fournisseur = pickup != null ? _asMap(pickup['fournisseur']) : _asMap(delivery['fournisseur']);
    final acheteur = _asMap(delivery['acheteur']);
    final supplierName = fournisseur['nom']?.toString() ??
        fournisseur['entreprise']?.toString() ??
        lieuDepart['nom']?.toString() ??
        'Fournisseur';
    final supplierAddr = lieuDepart['adresse']?.toString() ??
        fournisseur['adresse']?.toString() ??
        '—';
    final supplierPhone = lieuDepart['telephone']?.toString() ??
        fournisseur['telephone']?.toString();
    final buyerName =
        '${acheteur['prenoms'] ?? ''} ${acheteur['nom'] ?? ''}'.trim();
    final orderNumber = _extractOrderNumberFromDelivery();
    final pieces = pickup != null ? (pickup['pieces'] as List? ?? []) : (delivery['pieces'] as List? ?? []);
    final exigences = delivery['noteAcheteur']?.toString() ?? 'Porte à porte';
    final supplierLatLng = latLngFromMap(lieuDepart);
    final buyerLatLng = latLngFromMap(_asMap(delivery['lieuDestination']));
    final currentLatLng =
        _currentPosition != null ? positionToLatLng(_currentPosition!) : null;
    final kmToSupplier = _haversineKm(currentLatLng, supplierLatLng);
    final supplierToBuyerKm = _haversineKm(supplierLatLng, buyerLatLng);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cardSection(
          icon: Icons.local_shipping,
          title: 'Résumé',
          tint: Colors.red,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildInfoRow(
                    icon: Icons.route,
                    title: 'Vers fournisseur',
                    value: _kmLabel(kmToSupplier),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInfoRow(
                    icon: Icons.payments_outlined,
                    title: 'Gain livraison',
                    value: '${delivery['fraisLivraison'] ?? 0} FCFA',
                  ),
                ),
              ],
            ),
            _buildInfoRow(
              icon: Icons.compare_arrows,
              title: 'Fournisseur -> Acheteur',
              value: _kmLabel(supplierToBuyerKm),
            ),
            _buildInfoRow(
              icon: Icons.inventory_2_outlined,
              title: 'Colis',
              value: '${pieces.length} colis',
            ),
          ],
        ),

        _cardSection(
          icon: Icons.store,
          title: 'Fournisseur',
          tint: Colors.blue,
          children: [
            _buildInfoRow(
              icon: Icons.store,
              title: 'Nom',
              value: supplierName,
              showCallButton: true,
              onCall: () => _callPhone(supplierPhone),
            ),
            _buildInfoRow(
              icon: Icons.location_on,
              title: 'Adresse',
              value: supplierAddr,
            ),
            if (supplierPhone != null)
              _buildInfoRow(
                icon: Icons.phone,
                title: 'Téléphone',
                value: supplierPhone,
              ),
          ],
        ),

        _cardSection(
          icon: Icons.receipt_long,
          title: 'Commande',
          tint: const Color(0xFFF8BF13),
          children: [
            _buildInfoRow(
              icon: Icons.receipt,
              title: 'N° Commande',
              value: orderNumber,
            ),
            _buildInfoRow(
              icon: Icons.person,
              title: 'Acheteur',
              value: buyerName.isNotEmpty ? buyerName : 'Client',
            ),
            _buildInfoRow(
              icon: Icons.rule,
              title: 'Exigences',
              value: exigences,
            ),
          ],
        ),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openOptimizedRouteTo(destination: supplierLatLng),
                icon: const Icon(Icons.near_me, color: Colors.green, size: 20),
                label: Text(l10n.geolocateSupplier),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _callPhone(supplierPhone),
                icon: const Icon(Icons.phone, color: Colors.blue, size: 20),
                label: const Text('Contacter'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSwipeButton(
          text: 'Sur place',
          icon: Icons.location_on,
          value: _swipePickup,
          onDrag: (v) => setState(() => _swipePickup = v),
          onComplete: _notifyPickup,
          enabled: !_pickupDone && !_currentPickupDone,
        ),
      ],
    );
  }

  Widget _buildAcheteurContent() {
    final lieuDestination = _asMap(delivery['lieuDestination']);
    final lieuDepart = _asMap(delivery['lieuDepart']);
    final acheteur = _asMap(delivery['acheteur']);
    final name = '${acheteur['prenoms'] ?? ''} ${acheteur['nom'] ?? ''}'.trim();
    final addr = lieuDestination['adresse']?.toString() ?? '—';
    // Priorité au numéro du COMPTE acheteur (BDD), puis fallback adresse destination.
    final phone = acheteur['telephone']?.toString() ??
        lieuDestination['telephone']?.toString();
    final pieces = delivery['pieces'] as List? ?? [];
    final paymentLabel =
        delivery['fraisLivraison'] != null ? 'Espèces à la livraison' : '—';
    final exigences = delivery['noteAcheteur']?.toString() ?? 'Porte à porte';
    final buyerLatLng = latLngFromMap(lieuDestination);
    final supplierLatLng = latLngFromMap(lieuDepart);
    final currentLatLng =
        _currentPosition != null ? positionToLatLng(_currentPosition!) : null;
    final kmToBuyer = _haversineKm(currentLatLng, buyerLatLng);
    final supplierToBuyerKm = _haversineKm(supplierLatLng, buyerLatLng);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cardSection(
          icon: Icons.navigation,
          title: 'En livraison',
          tint: Colors.orange,
          children: [
            _buildInfoRow(
              icon: Icons.route,
              title: 'Vers acheteur',
              value: _kmLabel(kmToBuyer),
            ),
            _buildInfoRow(
              icon: Icons.compare_arrows,
              title: 'Fournisseur -> Acheteur',
              value: _kmLabel(supplierToBuyerKm),
            ),
            _buildInfoRow(
              icon: Icons.payments_outlined,
              title: 'Gain livraison',
              value: '${delivery['fraisLivraison'] ?? 0} FCFA',
            ),
          ],
        ),

        _cardSection(
          icon: Icons.person_outline,
          title: 'À livrer à',
          tint: Colors.green,
          children: [
            _buildInfoRow(
              icon: Icons.person,
              title: 'Acheteur',
              value: name.isNotEmpty ? name : 'Client',
              showCallButton: true,
              onCall: () => _callPhone(phone),
            ),
            _buildInfoRow(
              icon: Icons.location_on,
              title: 'Adresse',
              value: addr,
            ),
            if (phone != null)
              _buildInfoRow(
                icon: Icons.phone,
                title: 'Téléphone',
                value: phone,
              ),
          ],
        ),

        _cardSection(
          icon: Icons.inventory_2_outlined,
          title: 'Colis',
          tint: const Color(0xFFF8BF13),
          children: [
            _buildInfoRow(
              icon: Icons.inventory,
              title: 'Colis à livrer',
              value: '${pieces.length} colis',
            ),
            _buildInfoRow(
              icon: Icons.payment,
              title: 'Paiement en espèces',
              value: paymentLabel,
            ),
            _buildInfoRow(
              icon: Icons.rule,
              title: 'Exigences',
              value: exigences,
            ),
          ],
        ),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickupDone
                    ? () => _openOptimizedRouteTo(
                          destination: buyerLatLng,
                          waypoint: (!_pickupDone && supplierLatLng != null)
                              ? supplierLatLng
                              : null,
                        )
                    : null,
                icon: const Icon(Icons.near_me, color: Colors.green, size: 20),
                label: Text(l10n.geolocateBuyer),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _callPhone(phone),
                icon: const Icon(Icons.phone, color: Colors.blue, size: 20),
                label: const Text('Contacter'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Chez l'acheteur : d'abord "Sur place", ensuite seulement "Colis livré".
        if (!_buyerArrived) ...[
          _buildSwipeButton(
            text: 'Sur place',
            icon: Icons.location_on,
            value: _swipeBuyerArrival,
            onDrag: (v) => setState(() => _swipeBuyerArrival = v),
            onComplete: _notifyArrival,
            enabled: _pickupDone,
          ),
        ] else ...[
          _buildSwipeButton(
            text: 'Colis livré',
            icon: Icons.check,
            value: _swipeDeliver,
            onDrag: (v) => setState(() => _swipeDeliver = v),
            onComplete: _notifyDeliver,
            enabled: !_deliverDone,
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    bool showCallButton = false,
    VoidCallback? onCall,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (showCallButton && onCall != null)
            IconButton(
              icon: const Icon(Icons.phone, color: Colors.green),
              onPressed: onCall,
            ),
        ],
      ),
    );
  }

  Widget _buildSwipeButton({
    required String text,
    required IconData icon,
    required double value,
    required ValueChanged<double> onDrag,
    required VoidCallback onComplete,
    required bool enabled,
  }) {
    final screenW = MediaQuery.of(context).size.width - 32;
    final threshold = screenW * 0.7;
    final reached = value >= threshold;

    return GestureDetector(
      onHorizontalDragUpdate: enabled
          ? (d) {
              if (_isCompletingSwipe) return;
              final newVal = (value + d.delta.dx).clamp(0.0, screenW);
              onDrag(newVal);
              if (newVal >= threshold) {
                _isCompletingSwipe = true;
                onComplete();
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) {
                    setState(() => _isCompletingSwipe = false);
                  } else {
                    _isCompletingSwipe = false;
                  }
                });
              }
            }
          : null,
      onHorizontalDragEnd: enabled
          ? (_) {
              if (value < threshold * 0.5) onDrag(0);
            }
          : null,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: Colors.grey[200],
        ),
        child: Stack(
          children: [
            if (value > 0 || !enabled)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: reached || !enabled ? screenW : value,
                child: Container(
                  decoration: BoxDecoration(
                    color: reached || !enabled
                        ? const Color(0xFF2E7D32)
                        : Colors.green[300],
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Center(
                    child: Text(
                      reached || !enabled ? '$text ✓' : text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            if (enabled && value < threshold)
              Positioned.fill(
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: Colors.black54, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Glisser pour $text',
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (!enabled)
              const Positioned.fill(
                child: Center(
                  child: Text(
                    'Terminé',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
