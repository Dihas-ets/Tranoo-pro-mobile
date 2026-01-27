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
import 'package:qr_code_scanner/qr_code_scanner.dart';

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
  int _unreadNotifications = 0;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _initializePage();
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
    } catch (e) {
      print('Erreur mise à jour localisation: $e');
    }
  }

  void _startLocationTracking() {
    Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Mettre à jour tous les 10 mètres
      ),
    ).listen((position) {
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
        setState(() {
          _pendingDeliveries =
              List<Map<String, dynamic>>.from(data['deliveries'] ?? []);
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
          _unreadNotifications =
              _notifications.where((n) => n['read'] == false).length;
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

  Future<void> _acceptDelivery(String deliveryId) async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Livraison acceptée avec succès')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }

  Future<void> _completeDelivery(String deliveryId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return;

      final baseUrl = getBackendBaseUrl();
      final res = await http.post(
        Uri.parse('$baseUrl/api/livreurs/deliveries/$deliveryId/complete'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (res.statusCode == 200) {
        await _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Livraison complétée avec succès')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
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
          body: _loading
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
                        _buildActiveDeliveries(size, isPortrait),
                        _buildPendingDeliveries(size, isPortrait),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
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
                  // Naviguer vers le profil
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const Profile()),
                  );
                },
                child: CircleAvatar(
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
                        'Solde Principal',
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
              _buildQuickActionIcon(
                Icons.qr_code_scanner,
                'Scanner QR',
                const Color(0xFFF8BF13),
                () => _scanQRCode(),
              ),
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

  Future<void> _scanQRCode() async {
    // TODO: Implémenter le scanner QR
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scanner QR - Fonctionnalité à venir'),
        backgroundColor: Color(0xFFF8BF13),
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
      {'icon': Icons.check_circle, 'label': 'Valider', 'color': Colors.green},
      {'icon': Icons.map, 'label': 'Géolocalisation', 'color': Colors.blue},
      {
        'icon': Icons.track_changes,
        'label': 'Suivi',
        'color': const Color(0xFFF8BF13)
      },
      {
        'icon': Icons.local_shipping,
        'label': 'Livraisons',
        'color': Colors.orange
      },
      {'icon': Icons.history, 'label': 'Historique', 'color': Colors.purple},
      {'icon': Icons.qr_code, 'label': 'Scanner', 'color': Colors.teal},
      {
        'icon': Icons.account_balance_wallet,
        'label': 'Portefeuille',
        'color': Colors.indigo
      },
      {'icon': Icons.settings, 'label': 'Paramètres', 'color': Colors.grey},
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

  Widget _buildActiveDeliveries(Size size, bool isPortrait) {
    if (_activeDeliveries.isEmpty) return const SizedBox.shrink();

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
            'Livraisons Actives',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ..._activeDeliveries
              .map((delivery) => _buildDeliveryCard(delivery, true)),
        ],
      ),
    );
  }

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
            'Livraisons en Attente',
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
                'Livraison #${delivery['id'] ?? 'N/A'}',
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
          Text('Destination: ${delivery['destination'] ?? 'N/A'}'),
          Text('Montant: ${delivery['amount'] ?? 0} ${_currency}'),
          const SizedBox(height: 8),
          if (!isActive)
            ElevatedButton(
              onPressed: () => _acceptDelivery(delivery['id'] ?? ''),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF8BF13),
                foregroundColor: Colors.black,
              ),
              child: const Text('Accepter'),
            )
          else
            ElevatedButton(
              onPressed: () => _completeDelivery(delivery['id'] ?? ''),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Compléter'),
            ),
        ],
      ),
    );
  }
}
