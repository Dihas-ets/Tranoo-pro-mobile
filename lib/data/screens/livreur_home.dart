import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:tranoo_pro/config/backend_config.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:tranoo_pro/providers/auth_provider.dart' as myauth;
import 'package:tranoo_pro/data/screens/wallet_screen.dart';
import 'package:tranoo_pro/data/screens/settings_page.dart';
import 'package:tranoo_pro/data/screens/notifications.dart';
import 'package:tranoo_pro/data/screens/profile.dart';
import 'package:tranoo_pro/data/screens/mes_livraisons_page.dart';
import 'package:tranoo_pro/data/screens/suivi_gps_page.dart';
import 'package:tranoo_pro/data/screens/tricycle/chauffeur_tricycle_home.dart';
import 'package:tranoo_pro/data/screens/delivery_notification_banner.dart';
import 'package:tranoo_pro/data/screens/delivery_map_screen.dart';
import 'dart:async';

class LivreurHomePage extends StatefulWidget {
  const LivreurHomePage({super.key});

  @override
  State<LivreurHomePage> createState() => _LivreurHomePageState();
}

class _LivreurHomePageState extends State<LivreurHomePage> {
  double? _balance;
  String _currency = 'XOF';
  List<Map<String, dynamic>> _pendingDeliveries = [];
  List<Map<String, dynamic>> _activeDeliveries = [];
  List<Map<String, dynamic>> _notifications = [];
  bool _isOnline = false;
  Position? _currentPosition;
  bool _loading = true;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _currentDeliveryNotification;
  Timer? _notificationPollTimer;
  StreamSubscription<Position>? _locationSubscription;
  DateTime? _lastDeliveryLocationSentAt;
  // État pour le glissement du bouton "Compléter" par livraison
  Map<String, double> _swipeCompleteValues = {};
  // État pour le glissement du bouton "Accepter" par livraison en attente
  Map<String, double> _swipeAcceptValues = {};
  final Set<String> _openingDeliveryFlowIds = <String>{};

  Future<Map<String, dynamic>?> _fetchDeliveryDetails(String deliveryId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return null;

      final baseUrl = getBackendBaseUrl();
      final res = await http.get(
        Uri.parse('$baseUrl/api/deliveries/$deliveryId'),
        headers: {'Authorization': 'Bearer $idToken'},
      );
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body);
      if (data is Map<String, dynamic>) {
        final delivery = data['delivery'];
        if (delivery is Map<String, dynamic>) return delivery;
        if (delivery is Map) return Map<String, dynamic>.from(delivery);
        return data;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openDeliveryMap(dynamic maybeIdOrDelivery) async {
    // maybeIdOrDelivery peut être un String id ou une Map delivery
    String? id;
    Map<String, dynamic>? delivery;
    if (maybeIdOrDelivery is Map<String, dynamic>) {
      delivery = maybeIdOrDelivery;
      id = maybeIdOrDelivery['_id']?.toString() ?? maybeIdOrDelivery['id']?.toString();
    } else if (maybeIdOrDelivery != null) {
      id = maybeIdOrDelivery.toString();
    }

    if (id != null && id.trim().isNotEmpty) {
      final fetched = await _fetchDeliveryDetails(id);
      if (fetched != null) delivery = fetched;
    }

    if (!mounted || delivery == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeliveryMapScreen(delivery: delivery!),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initializePage();
  }

  @override
  void dispose() {
    _notificationPollTimer?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializePage() async {
    await _loadUserData();
    await _requestLocationPermission();
    await _loadData();
    _startLocationTracking();
    _startNotificationsListener();
  }

  Future<void> _loadUserData() async {
    final authProvider =
        Provider.of<myauth.AuthProvider>(context, listen: false);
    setState(() {
      _userData = authProvider.user;
    });
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
      });
      _updateLocationOnServer(position);
    } catch (e) {
      print('Erreur géolocalisation: $e');
    }
  }

  Future<void> _updateLocationOnServer(Position position) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return;

      final baseUrl = getBackendBaseUrl();
      await http.post(
        Uri.parse('$baseUrl/api/livreurs/location'),
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

      // IMPORTANT: si le livreur a une livraison active (assigné/en_cours),
      // on pousse aussi la localisation sur la Delivery pour le tracking acheteur.
      await _updateActiveDeliveryLocation(position, idToken, baseUrl);
    } catch (e) {
      print('Erreur mise à jour localisation: $e');
    }
  }

  Future<void> _updateActiveDeliveryLocation(
    Position position,
    String idToken,
    String baseUrl,
  ) async {
    try {
      // Throttle pour éviter le spam réseau
      final now = DateTime.now();
      if (_lastDeliveryLocationSentAt != null &&
          now.difference(_lastDeliveryLocationSentAt!) <
              const Duration(seconds: 5)) {
        return;
      }

      if (_activeDeliveries.isEmpty) return;

      // On prend la première livraison active (souvent une seule)
      final delivery = _activeDeliveries.first;
      final rawId = delivery['_id']?.toString() ?? delivery['id']?.toString();
      if (rawId == null || rawId.trim().isEmpty) return;
      final deliveryId = rawId.replaceAll('"', '').replaceAll("'", '').trim();

      final url = Uri.parse('$baseUrl/api/deliveries/$deliveryId/location');
      final res = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'latitude': position.latitude,
          'longitude': position.longitude,
          // Address optionnelle (pas toujours disponible ici)
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        _lastDeliveryLocationSentAt = now;
      }
    } catch (e) {
      // Ne pas bloquer l'app si tracking échoue
      print('Erreur update delivery location: $e');
    }
  }

  void _startLocationTracking() {
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Mettre à jour tous les 10 mètres
      ),
    ).listen((position) {
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
      });
      _updateLocationOnServer(position);
    });
  }

  void _startNotificationsListener() {
    // Écouter les notifications en temps réel via WebSocket ou polling
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) _loadNotifications();
    });
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) throw Exception('Token manquant');

      final baseUrl = getBackendBaseUrl();

      // Charger le solde
      final walletRes = await http.get(
        Uri.parse('$baseUrl/api/wallet/me'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      // Charger les livraisons en attente
      final pendingRes = await http.get(
        Uri.parse('$baseUrl/api/livreurs/deliveries/pending'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      // Charger les livraisons actives
      final activeRes = await http.get(
        Uri.parse('$baseUrl/api/livreurs/deliveries/active'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      // Charger les notifications
      await _loadNotifications();

      if (walletRes.statusCode == 200) {
        final data = jsonDecode(walletRes.body);
        setState(() {
          _balance = (data['balance'] ?? 0).toDouble();
          _currency = data['currency'] ?? 'XOF';
        });
      }

      if (pendingRes.statusCode == 200) {
        final data = jsonDecode(pendingRes.body);
        final pending =
            List<Map<String, dynamic>>.from(data['deliveries'] ?? []);
        setState(() {
          _pendingDeliveries = pending;
          // Afficher le cadran de notification avec la première livraison en attente (par le bas)
          if (_isOnline &&
              pending.isNotEmpty &&
              _currentDeliveryNotification == null) {
            _currentDeliveryNotification = pending.first;
          }
        });
      }

      if (activeRes.statusCode == 200) {
        final data = jsonDecode(activeRes.body);
        setState(() {
          _activeDeliveries =
              List<Map<String, dynamic>>.from(data['deliveries'] ?? []);
        });
      }
    } catch (e) {
      print('Erreur chargement données: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return;

      final baseUrl = getBackendBaseUrl();
      final res = await http.get(
        Uri.parse('$baseUrl/api/notifications/livreur'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _notifications =
              List<Map<String, dynamic>>.from(data['notifications'] ?? []);
        });
      }
    } catch (e) {
      print('Erreur chargement notifications: $e');
    }
  }

  Future<void> _toggleOnlineStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: Utilisateur non connecté')),
        );
        return;
      }

      final baseUrl = getBackendBaseUrl();
      final newStatus = !_isOnline;

      final res = await http.post(
        Uri.parse('$baseUrl/api/livreurs/toggle-status'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'isOnline': newStatus}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _isOnline = data['isOnline'] ?? newStatus;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isOnline
                ? 'Vous êtes maintenant en ligne'
                : 'Vous êtes maintenant hors ligne'),
            backgroundColor: _isOnline ? Colors.green : Colors.grey,
          ),
        );
      } else {
        final error = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Erreur: ${error['message'] ?? 'Erreur inconnue'}')),
        );
      }
    } catch (e) {
      print('Erreur changement statut: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }

  Future<void> _acceptDelivery(
    String deliveryId, {
    bool openMapAfter = false,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return;

      final baseUrl = getBackendBaseUrl();
      final res = await http.post(
        Uri.parse('$baseUrl/api/livreurs/deliveries/$deliveryId/accept'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (res.statusCode == 200) {
        await _loadData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Livraison acceptée avec succès')),
        );

        if (openMapAfter) {
          await _openDeliveryMap(deliveryId);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }

  Future<void> _completeDelivery(
    String deliveryId,
    Map<String, dynamic> delivery,
    double screenW,
  ) async {
    // Ici "Compléter" = ouvrir la suite (GPS + overlay fournisseur/acheteur + swipe),
    // déjà implémentée dans DeliveryMapScreen + delivery_flow_screens.dart.
    if (_openingDeliveryFlowIds.contains(deliveryId)) return;
    _openingDeliveryFlowIds.add(deliveryId);

    if (mounted) {
      setState(() {
        _swipeCompleteValues[deliveryId] = screenW; // passe en vert avant redirection
      });
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeliveryMapScreen(delivery: delivery),
      ),
    );

    // Reset UI après retour
    if (mounted) {
      setState(() {
        _swipeCompleteValues[deliveryId] = 0.0;
      });
    }
    _openingDeliveryFlowIds.remove(deliveryId);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return Consumer<myauth.AuthProvider>(
      builder: (context, auth, _) {
        if (auth.user != null && _userData == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _userData = auth.user;
            });
          });
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          body: Stack(
            children: [
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          children: [
                            _buildHeader(size, isPortrait),
                            _buildQuickActions(size, isPortrait),
                            _buildStatsCards(size, isPortrait),
                            _buildServicesGrid(size, isPortrait),
                            _buildPendingDeliveries(size, isPortrait),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
              // Bannière de notification de livraison (affichée même hors ligne, mais bouton désactivé)
              if (_currentDeliveryNotification != null)
                DeliveryNotificationBanner(
                  delivery: _currentDeliveryNotification!,
                  isOnline: _isOnline,
                  currentPosition: _currentPosition,
                  onAccepted: (acceptedDelivery) {
                    final fallbackId = _currentDeliveryNotification?['_id'] ??
                        _currentDeliveryNotification?['id'];
                    setState(() {
                      _currentDeliveryNotification = null;
                    });
                    _loadData();
                    // Ouvrir directement la page GPS + overlay (toujours avec une livraison "complète")
                    _openDeliveryMap(acceptedDelivery ?? fallbackId);
                  },
                  onDismissed: () {
                    setState(() {
                      _currentDeliveryNotification = null;
                    });
                  },
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _toggleOnlineStatus,
            backgroundColor: _isOnline ? Colors.green : Colors.grey,
            tooltip: _isOnline ? 'Passer hors ligne' : 'Passer en ligne',
            child:
                Icon(_isOnline ? Icons.check_circle : Icons.power_settings_new),
          ),
        );
      },
    );
  }

  Widget _buildHeader(Size size, bool isPortrait) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 10, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A1F44), Color(0xFF1a3a6a)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _userData?['nom'] ?? 'Livreur',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const Profile()),
                  );
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: _userData?['photo'] != null &&
                              (_userData!['photo'] as String).isNotEmpty
                          ? NetworkImage(_userData!['photo'] as String)
                          : null,
                      child: _userData?['photo'] == null ||
                              (_userData!['photo'] as String).isEmpty
                          ? const Icon(
                              Icons.person_outline,
                              color: Colors.white,
                              size: 24,
                            )
                          : null,
                    ),
                    if (_userData?['photo'] == null ||
                        (_userData!['photo'] as String).isEmpty)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.error_outline,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Portefeuille',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _balance != null
                            ? NumberFormat.currency(
                                locale: 'fr_FR',
                                symbol: '$_currency ',
                              ).format(_balance)
                            : '--',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isOnline ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isOnline ? 'En ligne' : 'Hors ligne',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(Size size, bool isPortrait) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Raccourcis rapides',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WalletScreen(),
                      ),
                    );
                  },
                  child: _buildBalanceVisibilityCard(),
                ),
              ),
              const SizedBox(width: 8),
              _buildQuickActionIcon(
                Icons.local_shipping,
                'Mes Livraisons',
                Colors.blue,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MesLivraisonsPage(),
                  ),
                ),
              ),
              _buildQuickActionIcon(
                Icons.map,
                'Suivi GPS',
                Colors.green,
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SuiviGpsPage(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceVisibilityCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.purple.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            color: Colors.purple,
            size: 24,
          ),
          const SizedBox(height: 8),
          const Text(
            'Portefeuille',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _balance != null
                ? NumberFormat.currency(
                    locale: 'fr_FR',
                    symbol: '$_currency ',
                  ).format(_balance)
                : '--',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionIcon(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards(Size size, bool isPortrait) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Livraisons\nen attente',
              '${_pendingDeliveries.length}',
              Icons.pending_actions,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Livraisons\nactives',
              '${_activeDeliveries.length}',
              Icons.local_shipping,
              const Color(0xFFF8BF13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesGrid(Size size, bool isPortrait) {
    final services = [
      {
        'icon': Icons.notifications_active,
        'label': 'Notifications',
        'color': Colors.red
      },
      {
        'icon': Icons.local_shipping,
        'label': 'Livraisons',
        'color': Colors.orange
      },
      {'icon': Icons.history, 'label': 'Historique', 'color': Colors.purple},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mes Services',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];
              return _buildServiceIcon(
                service['icon'] as IconData,
                service['label'] as String,
                service['color'] as Color,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServiceIcon(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () {
        // Navigation selon le service
        if (label == 'Portefeuille') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const WalletScreen()),
          );
        } else if (label == 'Paramètres') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsPage()),
          );
        } else if (label == 'Notifications') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const Notifications()),
          );
        } else if (label == 'Tricycle') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ChauffeurTricycleHomePage(),
            ),
          );
        }
        // Ajouter d'autres navigations selon les besoins
      },
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Liste des livraisons actives retirée de la home (section visuelle supprimée).

  Widget _buildPendingDeliveries(Size size, bool isPortrait) {
    if (_pendingDeliveries.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Livraisons en attente',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ..._pendingDeliveries
              .map((delivery) => _buildDeliveryCard(delivery, false)),
        ],
      ),
    );
  }

  Widget _buildDeliveryCard(Map<String, dynamic> delivery, bool isActive) {
    final lieuDestination = delivery['lieuDestination'] ?? {};
    final distanceKm = delivery['distanceKm'] ?? 0;
    final fraisLivraison = delivery['fraisLivraison'] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFFF8BF13).withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? const Color(0xFFF8BF13) : Colors.grey,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Livraison #${delivery['_id']?.toString().substring(0, 8) ?? 'N/A'}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isActive ? 'Active' : 'En attente',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
              'Destination: ${lieuDestination['adresse'] ?? 'Non renseignée'}'),
          Text('Distance: ${distanceKm.toStringAsFixed(1)} km'),
          Text('Frais livraison: $fraisLivraison $_currency'),
          const SizedBox(height: 8),
          if (!isActive)
            _buildSwipeAcceptButton(delivery)
          else
            _buildSwipeCompleteButton(delivery),
        ],
      ),
    );
  }

  Widget _buildSwipeCompleteButton(Map<String, dynamic> delivery) {
    final deliveryId = delivery['_id']?.toString() ?? delivery['id']?.toString() ?? '';
    final swipeValue = _swipeCompleteValues[deliveryId] ?? 0.0;
    final screenW = MediaQuery.of(context).size.width - 32;
    final threshold = screenW * 0.85;
    final reached = swipeValue >= threshold;

    return GestureDetector(
      onHorizontalDragUpdate: (d) {
        final newVal = (swipeValue + d.delta.dx).clamp(0.0, screenW);
        setState(() {
          _swipeCompleteValues[deliveryId] = newVal;
        });
        if (newVal >= threshold) {
          _completeDelivery(deliveryId, delivery, screenW);
        }
      },
      onHorizontalDragEnd: (_) {
        if (swipeValue < threshold * 0.5) {
          setState(() {
            _swipeCompleteValues[deliveryId] = 0.0;
          });
        } else if (swipeValue >= threshold * 0.5 && swipeValue < threshold) {
          // Si glissé à mi-chemin, compléter quand même
          _completeDelivery(deliveryId, delivery, screenW);
        }
      },
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: Colors.grey[800], // Fond gris foncé
        ),
        child: Stack(
          children: [
            // Partie verte qui grandit quand on glisse
            if (swipeValue > 0 || reached)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: reached ? screenW : swipeValue.clamp(0.0, screenW),
                child: Container(
                  decoration: BoxDecoration(
                    color: reached
                        ? const Color(0xFF2E7D32) // Vert après complétion
                        : const Color(0xFFFFC107), // Jaune pendant le glissement
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
                      reached ? 'COMPLÉTÉ' : 'Compléter',
                      style: TextStyle(
                        color: reached
                            ? Colors.white
                            : swipeValue > 0
                                ? Colors.white
                                : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: reached ? 16 : 17,
                      ),
                    ),
                    if (!reached) const SizedBox(height: 2),
                    if (!reached)
                      Text(
                        'Glisser pour compléter',
                        style: TextStyle(
                          color: swipeValue > 0 ? Colors.white70 : Colors.grey[400],
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

  Widget _buildSwipeAcceptButton(Map<String, dynamic> delivery) {
    final deliveryId =
        delivery['_id']?.toString() ?? delivery['id']?.toString() ?? '';
    final swipeValue = _swipeAcceptValues[deliveryId] ?? 0.0;
    final screenW = MediaQuery.of(context).size.width - 32;
    final threshold = screenW * 0.85;
    final reached = swipeValue >= threshold;

    return GestureDetector(
      onHorizontalDragUpdate: (d) {
        final newVal = (swipeValue + d.delta.dx).clamp(0.0, screenW);
        setState(() {
          _swipeAcceptValues[deliveryId] = newVal;
        });
        if (newVal >= threshold) {
          _acceptDelivery(deliveryId, openMapAfter: true);
        }
      },
      onHorizontalDragEnd: (_) {
        if (swipeValue < threshold * 0.5) {
          setState(() {
            _swipeAcceptValues[deliveryId] = 0.0;
          });
        } else if (swipeValue >= threshold * 0.5 && swipeValue < threshold) {
          _acceptDelivery(deliveryId, openMapAfter: true);
        }
      },
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: Colors.grey[800],
        ),
        child: Stack(
          children: [
            if (swipeValue > 0 || reached)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: reached ? screenW : swipeValue.clamp(0.0, screenW),
                child: Container(
                  decoration: BoxDecoration(
                    color: reached
                        ? Colors.green
                        : const Color(0xFFF8BF13),
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
              ),
            Positioned.fill(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      reached ? 'ACCEPTÉE' : 'Accepter',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    if (!reached) const SizedBox(height: 2),
                    if (!reached)
                      Text(
                        'Glisser pour accepter',
                        style: TextStyle(
                          color: swipeValue > 0
                              ? Colors.white70
                              : Colors.grey[400],
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
