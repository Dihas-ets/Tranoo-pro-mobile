import 'package:flutter/material.dart';
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
  // ——— Google Maps (grisé) ———
  // GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isCollapsed = false;
  int _selectedTab = 0; // 0 = fournisseur/colis, 1 = acheteur
  double _swipePickup = 0;
  double _swipeDeliver = 0;
  bool _pickupDone = false;
  bool _deliverDone = false;
  bool _buyerArrived = false;
  List<OsmMarkerData> _osmMarkers = [];

  Map<String, dynamic> get delivery => widget.delivery;
  bool get colisRecupere => delivery['colisRecupere'] == true;

  /// Normalise une valeur dynamique en `Map<String, dynamic>`.
  /// Certains anciens enregistrements/retours API peuvent renvoyer `[]` au lieu de `{}`.
  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  @override
  void initState() {
    super.initState();
    _pickupDone = colisRecupere;
    if (colisRecupere) _selectedTab = 1;
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

    final pickup = latLngFromMap(lieuDepart);
    if (pickup != null) {
      list.add(OsmMarkerData(
          point: pickup, iconData: Icons.store, color: Colors.blue));
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

  Future<void> _notifyDeliver() async {
    if (_deliverDone) return;
    final id = delivery['_id']?.toString();
    if (id == null) return;
    try {
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
          const SnackBar(content: Text('Colis livré')),
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
          const SnackBar(content: Text('Arrivée notifiée à l\'acheteur')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur arrivée: ${res.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur arrivée: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Destination pour le bouton "Naviguer" : fournisseur (onglet 0) ou acheteur (onglet 1)
    final navDest = _selectedTab == 0
        ? latLngFromMap(_asMap(delivery['lieuDepart']))
        : latLngFromMap(_asMap(delivery['lieuDestination']));
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
                  child: _selectedTab == 0
                      ? _buildFournisseurContent()
                      : _buildAcheteurContent(),
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
          _buildTabIcon(0, Icons.inventory_2_outlined, 'Colis & Fournisseur'),
          const SizedBox(width: 8),
          _buildTabIcon(1, Icons.person_outline, 'Acheteur'),
        ],
      ),
    );
  }

  Widget _buildTabIcon(int index, IconData icon, String tooltip) {
    final selected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
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
    final dest = _selectedTab == 0
        ? (lieuDepart['adresse'] ?? 'Fournisseur')
        : (lieuDestination['adresse'] ?? 'Acheteur');
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
                  _pickupDone ? 'En livraison' : 'En direction du fournisseur',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedTab == 0 ? dest : (name.isNotEmpty ? name : dest),
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
    final lieuDepart = _asMap(delivery['lieuDepart']);
    final fournisseur = _asMap(delivery['fournisseur']);
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
    final orderId =
        delivery['orderId']?.toString() ?? delivery['_id']?.toString() ?? '—';
    final pieces = delivery['pieces'] as List? ?? [];
    final paymentLabel =
        delivery['totalCommande'] != null ? 'Déjà payé en ligne' : '—';
    final exigences = delivery['noteAcheteur']?.toString() ?? 'Porte à porte';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Avant la prise en charge',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    delivery['distanceKm'] != null
                        ? '${(delivery['distanceKm'] as num).toStringAsFixed(1)} km'
                        : '—',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${delivery['fraisLivraison'] ?? 0} FCFA',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${pieces.length} colis',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'À récupérer chez :',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        _buildInfoRow(
          icon: Icons.store,
          title: 'Fournisseur',
          value: supplierName,
          showCallButton: true,
          onCall: () => _callPhone(supplierPhone),
        ),
        _buildInfoRow(
            icon: Icons.location_on, title: 'Adresse', value: supplierAddr),
        if (supplierPhone != null)
          _buildInfoRow(
              icon: Icons.phone, title: 'Téléphone', value: supplierPhone),
        const SizedBox(height: 12),
        const Text(
          'Commande :',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        _buildInfoRow(
            icon: Icons.receipt, title: 'N° Commande', value: orderId),
        _buildInfoRow(
            icon: Icons.person,
            title: 'Acheteur',
            value: buyerName.isNotEmpty ? buyerName : 'Client'),
        _buildInfoRow(
            icon: Icons.payment, title: 'Paiement', value: paymentLabel),
        _buildInfoRow(
            icon: Icons.directions_walk, title: 'Exigences', value: exigences),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _callPhone(supplierPhone),
                icon: const Icon(Icons.phone, color: Colors.green, size: 20),
                label: const Text('Appeler fournisseur'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.message, color: Colors.blue, size: 20),
                label: const Text('Assistance'),
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
          onComplete: () {
            if (_pickupDone) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    PackageValidationScreen(delivery: delivery),
              ),
            );
          },
          enabled: !_pickupDone,
        ),
      ],
    );
  }

  Widget _buildAcheteurContent() {
    final lieuDestination = _asMap(delivery['lieuDestination']);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'En livraison vers l\'acheteur',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.orange[800],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    delivery['distanceKm'] != null
                        ? '${(delivery['distanceKm'] as num).toStringAsFixed(1)} km'
                        : '—',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'À livrer à :',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        _buildInfoRow(
          icon: Icons.person,
          title: 'Acheteur',
          value: name.isNotEmpty ? name : 'Client',
          showCallButton: true,
          onCall: () => _callPhone(phone),
        ),
        _buildInfoRow(
            icon: Icons.location_on,
            title: 'Adresse de livraison',
            value: addr),
        if (phone != null)
          _buildInfoRow(icon: Icons.phone, title: 'Téléphone', value: phone),
        const SizedBox(height: 12),
        const Text(
          'Colis :',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        _buildInfoRow(
          icon: Icons.inventory,
          title: 'Colis à livrer',
          value: '${pieces.length} colis',
        ),
        _buildInfoRow(
            icon: Icons.payment,
            title: 'Paiement en espèces',
            value: paymentLabel),
        _buildInfoRow(
            icon: Icons.directions_walk, title: 'Exigences', value: exigences),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _callPhone(phone),
                icon: const Icon(Icons.phone, color: Colors.green, size: 20),
                label: const Text('Appeler l\'acheteur'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.message, color: Colors.blue, size: 20),
                label: const Text('Message support'),
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
            value: _swipePickup,
            onDrag: (v) => setState(() => _swipePickup = v),
            onComplete: _notifyArrival,
            enabled: true,
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
              final newVal = (value + d.delta.dx).clamp(0.0, screenW);
              onDrag(newVal);
              if (newVal >= threshold) onComplete();
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
                      Icon(icon, color: Colors.white70, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Glisser pour $text',
                        style: const TextStyle(
                          color: Colors.white70,
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
