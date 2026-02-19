import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ——— Google Maps (grisé — réactiver si clé API) ———
// import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:tranoo_pro/config/backend_config.dart';
import 'package:tranoo_pro/data/screens/livreur_home.dart';
import 'package:tranoo_pro/data/screens/osm_map_widget.dart';
import 'package:url_launcher/url_launcher.dart';

// ——— ÉTAPE 2 : VALIDATION DU COLIS ———
class PackageValidationScreen extends StatelessWidget {
  final Map<String, dynamic> delivery;

  const PackageValidationScreen({super.key, required this.delivery});

  int get _colisCount {
    final pieces = delivery['pieces'] as List? ?? [];
    return pieces.isEmpty ? 1 : pieces.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validation du colis'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Prise en charge de $_colisCount colis',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(Icons.inventory_2,
                  size: 60, color: Colors.blue.shade700),
            ),
            const SizedBox(height: 20),
            Text(
              '$_colisCount colis',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.grey),
                    ),
                    child: const Text('Retour', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PackagePickupConfirmationScreen(
                            delivery: delivery,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF8BF13),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Valider',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ——— ÉTAPE 3 : CONFIRMATION PRISE COLIS ———
class PackagePickupConfirmationScreen extends StatelessWidget {
  final Map<String, dynamic> delivery;

  const PackagePickupConfirmationScreen({super.key, required this.delivery});

  int get _colisCount {
    final pieces = delivery['pieces'] as List? ?? [];
    return pieces.isEmpty ? 1 : pieces.length;
  }

  int get _articleCount {
    final pieces = delivery['pieces'] as List? ?? [];
    if (pieces.isEmpty) return 1;
    int n = 0;
    for (final p in pieces) {
      n += (p is Map && p['quantite'] != null)
          ? (p['quantite'] as num).toInt()
          : 1;
    }
    return n > 0 ? n : 1;
  }

  String get _totalLabel {
    final total = delivery['totalCommande'] ?? delivery['fraisLivraison'];
    if (total != null) return '${(total as num).toStringAsFixed(0)} FCFA';
    return '—';
  }

  Future<void> _confirmPickup(BuildContext context) async {
    final id = delivery['_id']?.toString();
    if (id == null) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      if (token == null) return;
      final res = await http.post(
        Uri.parse('${getBackendBaseUrl()}/api/deliveries/$id/pickup'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200 && context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => InTransitToBuyerScreen(delivery: delivery),
          ),
        );
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: ${res.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prise en charge'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Prendre en charge',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_colisCount colis',
              style: TextStyle(fontSize: 20, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildDetailItem(
                      context, '$_colisCount Colis', Icons.inventory_2),
                  const SizedBox(height: 16),
                  _buildDetailItem(
                      context, '$_articleCount article(s)', Icons.shopping_bag),
                  const SizedBox(height: 16),
                  _buildDetailItem(context, _totalLabel, Icons.payment),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _confirmPickup(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Colis pris en charge',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ——— ÉTAPE 4 : EN ROUTE VERS L'ACHETEUR ———
class InTransitToBuyerScreen extends StatefulWidget {
  final Map<String, dynamic> delivery;

  const InTransitToBuyerScreen({super.key, required this.delivery});

  @override
  State<InTransitToBuyerScreen> createState() => _InTransitToBuyerScreenState();
}

class _InTransitToBuyerScreenState extends State<InTransitToBuyerScreen> {
  Position? _currentPosition;
  List<OsmMarkerData> _osmMarkers = [];
  Timer? _timer;
  Duration _remainingTime = const Duration(minutes: 15);
  bool _isCollapsed = false;
  double _progress = 0.3;

  Map<String, dynamic> get delivery => widget.delivery;

  @override
  void initState() {
    super.initState();
    _initRemainingTime();
    _getCurrentLocation();
    _buildMarkers();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _remainingTime.inSeconds > 0) {
        setState(
            () => _remainingTime = _remainingTime - const Duration(seconds: 1));
      }
    });
  }

  void _initRemainingTime() {
    final km = delivery['distanceKm'] as num?;
    if (km != null && km > 0) {
      final minutes = (km.toDouble() / 25 * 60).round().clamp(1, 120);
      setState(() => _remainingTime = Duration(minutes: minutes));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
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

  void _buildMarkers() {
    final lieuDestination =
        delivery['lieuDestination'] as Map<String, dynamic>?;
    final list = <OsmMarkerData>[];
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

  LatLng _initialTarget() {
    final p =
        latLngFromMap(delivery['lieuDestination'] as Map<String, dynamic>?);
    return p ?? const LatLng(14.716677, -17.467686);
  }

  Future<void> _callBuyer() async {
    final lieuDestination = delivery['lieuDestination'] ?? {};
    final acheteur = delivery['acheteur'] ?? {};
    final phone = lieuDestination['telephone']?.toString() ??
        acheteur['telephone']?.toString();
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'\s'), ''));
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          OsmMapWidget(
            center: _initialTarget(),
            zoom: 14,
            markers: _osmMarkers,
            onTapMyLocation: _getCurrentLocation,
            navigateToDestination: latLngFromMap(
                delivery['lieuDestination'] as Map<String, dynamic>?),
          ),
          // ——— Google Maps (grisé) ———
          // GoogleMap( ... ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: SafeArea(
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
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
    final height = _isCollapsed ? 100.0 : 380.0;
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
            if (!_isCollapsed) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _formatDuration(_remainingTime),
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'En route vers l\'acheteur',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: _progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.grey.shade200,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.green),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          delivery['distanceKm'] != null
                              ? '${(delivery['distanceKm'] as num).toStringAsFixed(1)} km'
                              : '—',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _callBuyer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.phone, color: Colors.white),
                        label: const Text(
                          'Appeler l\'acheteur',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ArrivalAtBuyerScreen(delivery: delivery),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.grey),
                        ),
                        child: const Text('Je suis arrivé'),
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'En route vers l\'acheteur',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _formatDuration(_remainingTime),
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
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

// ——— ÉTAPE 5 : ARRIVÉ CHEZ L'ACHETEUR ———
class ArrivalAtBuyerScreen extends StatefulWidget {
  final Map<String, dynamic> delivery;

  const ArrivalAtBuyerScreen({super.key, required this.delivery});

  @override
  State<ArrivalAtBuyerScreen> createState() => _ArrivalAtBuyerScreenState();
}

class _ArrivalAtBuyerScreenState extends State<ArrivalAtBuyerScreen> {
  bool _surPlaceDone = false;
  double _swipeSurPlace = 0;
  double _swipeLivree = 0;
  bool _deliverDone = false;
  bool _isCollapsed = false;

  Map<String, dynamic> get delivery => widget.delivery;

  Future<void> _completeDelivery() async {
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
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => DeliveryCompletedScreen(
              delivery: delivery,
            ),
          ),
          (route) => false,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: ${res.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
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
              if (newVal >= threshold) {
                HapticFeedback.mediumImpact();
                onComplete();
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
          color: Colors.grey.shade200,
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
                        : Colors.green.shade300,
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lieuDestination = delivery['lieuDestination'] ?? {};
    final acheteur = delivery['acheteur'] ?? {};
    final addr = lieuDestination['adresse']?.toString() ?? '—';
    final name = '${acheteur['prenoms'] ?? ''} ${acheteur['nom'] ?? ''}'.trim();
    final pieces = delivery['pieces'] as List? ?? [];

    final center = latLngFromMap(lieuDestination as Map<String, dynamic>?) ??
        const LatLng(14.716677, -17.467686);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          OsmMapWidget(
            center: center,
            zoom: 14,
            markers: [
              OsmMarkerData(
                  point: center,
                  iconData: Icons.person_pin,
                  color: Colors.green),
            ],
            navigateToDestination: center,
          ),
          // ——— Google Maps (grisé) ———
          // GoogleMap( ... ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: SafeArea(
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildOverlay(addr, name, pieces.length),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlay(String addr, String name, int colisCount) {
    final height = _isCollapsed ? 100.0 : 520.0;
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
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
                                Icon(Icons.location_on,
                                    size: 14, color: Colors.orange.shade700),
                                const SizedBox(width: 4),
                                Text(
                                  '100 m',
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
                      const SizedBox(height: 8),
                      const Text(
                        'Transfert',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildDetailRow('Adresse', addr),
                      const SizedBox(height: 16),
                      _buildDetailRow('Client', name.isNotEmpty ? name : '—'),
                      const SizedBox(height: 16),
                      _buildDetailRow('Colis à livrer', '$colisCount colis'),
                      const SizedBox(height: 16),
                      _buildDetailRow('Paiement en espèces', 'À la livraison'),
                      const SizedBox(height: 16),
                      _buildDetailRow('Exigences', 'Porte à porte'),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: 0,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.orange.shade700),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('0',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                          Text('50',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Colors.grey),
                          ),
                          child: const Text('Retourner'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.message, color: Colors.white),
                          label: const Text(
                            'Discuter avec l\'assistance',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (!_surPlaceDone)
                        _buildSwipeButton(
                          text: 'Sur place',
                          icon: Icons.location_on,
                          value: _swipeSurPlace,
                          onDrag: (v) => setState(() => _swipeSurPlace = v),
                          onComplete: () {
                            setState(() => _surPlaceDone = true);
                            HapticFeedback.mediumImpact();
                          },
                          enabled: true,
                        )
                      else
                        _buildSwipeButton(
                          text: 'Colis livré',
                          icon: Icons.check_circle,
                          value: _swipeLivree,
                          onDrag: (v) => setState(() => _swipeLivree = v),
                          onComplete: _completeDelivery,
                          enabled: !_deliverDone,
                        ),
                    ],
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Arrivé chez l\'acheteur',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Icon(Icons.keyboard_arrow_up, color: Colors.grey.shade600),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
    );
  }
}

// ——— ÉTAPE 6 : LIVRAISON TERMINÉE ———
class DeliveryCompletedScreen extends StatelessWidget {
  final Map<String, dynamic> delivery;

  const DeliveryCompletedScreen({super.key, required this.delivery});

  String get _amountEarned {
    final gain = delivery['gainLivreur'] ?? delivery['fraisLivraison'];
    if (gain != null) return '${(gain as num).toStringAsFixed(0)} FCFA';
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(60),
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 60,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'Livraison terminée !',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Text(
                  'Le colis a été livré avec succès.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Montant gagné : $_amountEarned',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LivreurHomePage(),
                        ),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF8BF13),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Retour à l\'accueil',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
