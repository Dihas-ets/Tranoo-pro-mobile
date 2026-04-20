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
import 'package:tranoo_pro/data/screens/profile.dart';
import 'package:tranoo_pro/data/screens/chauffeur_ride_notification.dart';
import 'package:tranoo_pro/data/screens/tricycle/chauffeur_tricycle_home.dart';
import 'dart:async';

class ChauffeurHomePage extends StatefulWidget {
  const ChauffeurHomePage({super.key});

  @override
  State<ChauffeurHomePage> createState() => _ChauffeurHomePageState();
}

class _ChauffeurHomePageState extends State<ChauffeurHomePage> {
  String _currency = 'XOF';
  double? _balance;
  bool _showBalance = false;
  // ignore: unused_field - utilisé pour le polling des nouvelles courses
  List<Map<String, dynamic>> _pendingRides = [];
  List<Map<String, dynamic>> _activeRides = [];
  List<Map<String, dynamic>> _notifications = [];
  bool _isOnline = false;
  // ignore: unused_field - utilisé pour le tracking GPS
  Position? _currentPosition;
  bool _loading = true;
  int _unreadNotifications = 0;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _currentRideNotification;
  Timer? _notificationPollTimer;
  StreamSubscription<Position>? _locationSubscription;

  // Statistiques pour l'affichage
  int _todayRides = 0;
  int _weekRides = 0;
  int _acceptedRidesTotal = 0;
  double _loanPaid = 0;
  double _loanRemaining = 0;
  DateTime? _loanDueDate;

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
    await _syncOnlineStatus();
    await _loadData();
    _startLocationTracking();
    _startNotificationsListener();
  }

  Future<void> _syncOnlineStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return;
      final baseUrl = getBackendBaseUrl();
      final res = await http.get(
        Uri.parse('$baseUrl/api/tricycles/chauffeur/status'),
        headers: {'Authorization': 'Bearer $idToken'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final s = (data['availabilityStatus'] ?? '').toString().toLowerCase();
        if (!mounted) return;
        setState(() {
          _isOnline = s == 'available';
        });
      }
    } catch (_) {}
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
    } catch (e) {
      print('Erreur mise à jour localisation: $e');
    }
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
      });
      _updateLocationOnServer(position);
    });
  }

  void _startNotificationsListener() {
    _notificationPollTimer =
        Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted) return;
      await _loadNotifications();
      if (_isOnline) {
        await _checkForNewRides();
      }
    });
  }

  Future<void> _checkForNewRides() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return;

      final baseUrl = getBackendBaseUrl();
      final res = await http.get(
        Uri.parse('$baseUrl/api/chauffeurs/rides/pending'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final pending = List<Map<String, dynamic>>.from(data['rides'] ?? []);
        if (pending.isNotEmpty &&
            _currentRideNotification == null &&
            _isOnline) {
          setState(() {
            _currentRideNotification = pending.first;
          });
        }
      }
    } catch (e) {
      print('Erreur vérification nouvelles courses: $e');
    }
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

      // Charger les courses en attente
      final pendingRes = await http.get(
        Uri.parse('$baseUrl/api/chauffeurs/rides/pending'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      // Charger les courses actives
      final activeRes = await http.get(
        Uri.parse('$baseUrl/api/chauffeurs/rides/active'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      // Charger les contacts tricycle pour stats dynamiques "courses acceptées"
      final incomingContactsRes = await http.get(
        Uri.parse('$baseUrl/api/tricycles/contacts/incoming'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      // Charger les notifications
      await _loadNotifications();

      if (walletRes.statusCode == 200) {
        final data = jsonDecode(walletRes.body);
        final loan = (data['loan'] is Map<String, dynamic>)
            ? data['loan'] as Map<String, dynamic>
            : <String, dynamic>{};
        final paid = (loan['paidAmount'] as num?)?.toDouble() ??
            (data['loanPaidAmount'] as num?)?.toDouble() ??
            0;
        final total = (loan['totalAmount'] as num?)?.toDouble() ??
            (data['loanTotalAmount'] as num?)?.toDouble() ??
            0;
        final remaining = (loan['remainingAmount'] as num?)?.toDouble() ??
            (total - paid).clamp(0, double.infinity);
        final dueDateRaw = loan['dueDate'] ?? data['loanDueDate'];
        setState(() {
          _currency = data['currency'] ?? 'XOF';
          _balance = (data['balance'] as num?)?.toDouble() ??
              (data['balance'] is String
                  ? double.tryParse(data['balance'])
                  : null) ??
              _balance ??
              0;
          _loanPaid = paid;
          _loanRemaining = remaining;
          _loanDueDate = dueDateRaw != null
              ? DateTime.tryParse(dueDateRaw.toString())
              : _loanDueDate;
        });
      }

      if (pendingRes.statusCode == 200) {
        final data = jsonDecode(pendingRes.body);
        final pending =
            List<Map<String, dynamic>>.from(data['rides'] ?? []);
        setState(() {
          _pendingRides = pending;
          if (_isOnline &&
              pending.isNotEmpty &&
              _currentRideNotification == null) {
            _currentRideNotification = pending.first;
          }
        });
      }

      if (activeRes.statusCode == 200) {
        final data = jsonDecode(activeRes.body);
        setState(() {
          _activeRides =
              List<Map<String, dynamic>>.from(data['rides'] ?? []);
        });
      }

      if (incomingContactsRes.statusCode == 200) {
        final data = jsonDecode(incomingContactsRes.body);
        final contacts =
            List<Map<String, dynamic>>.from(data['contacts'] ?? []);
        final accepted = contacts.where((c) {
          final status = (c['status'] ?? '').toString().toLowerCase();
          return status == 'accepted' || c['acceptedAt'] != null;
        }).toList();
        final now = DateTime.now();
        final startToday = DateTime(now.year, now.month, now.day);
        final startWeek = startToday.subtract(Duration(days: now.weekday - 1));
        int today = 0;
        int week = 0;
        for (final c in accepted) {
          final acceptedAtRaw = c['acceptedAt'];
          final acceptedAt = acceptedAtRaw != null
              ? DateTime.tryParse(acceptedAtRaw.toString())
              : null;
          if (acceptedAt == null) continue;
          if (!acceptedAt.isBefore(startToday)) today += 1;
          if (!acceptedAt.isBefore(startWeek)) week += 1;
        }
        setState(() {
          _todayRides = today;
          _weekRides = week;
          _acceptedRidesTotal = accepted.length;
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
        Uri.parse('$baseUrl/api/notifications/chauffeur'),
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

  /// Synchronise le statut + la position avec le service Tricycle
  Future<void> _updateTricycleStatusAndLocation(bool isOnline) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return;

      final baseUrl = getBackendBaseUrl();

      // 1) Mettre à jour la localisation pour le service Tricycle
      Position? pos = _currentPosition;
      if (pos == null) {
        try {
          pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
        } catch (_) {}
      }

      if (pos != null) {
        await http.post(
          Uri.parse('$baseUrl/api/tricycles/location'),
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'latitude': pos.latitude,
            'longitude': pos.longitude,
          }),
        );
      }

      // 2) Mettre à jour le statut de disponibilité Tricycle
      final tricycleStatus = isOnline ? 'available' : 'offline';
      await http.post(
        Uri.parse('$baseUrl/api/tricycles/chauffeur/status'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': tricycleStatus}),
      );
    } catch (e) {
      print('Erreur sync statut/location Tricycle: $e');
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

      final newStatus = !_isOnline;

      // Pour l'instant, le statut en ligne des chauffeurs est directement
      // géré via le service Tricycle (pas de route /api/chauffeurs/toggle-status).
      // On met donc à jour l'état local + le backend Tricycle uniquement.
      await _updateTricycleStatusAndLocation(newStatus);
      setState(() {
        _isOnline = newStatus;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isOnline
              ? 'Vous êtes maintenant disponible'
              : 'Vous êtes maintenant indisponible'),
          backgroundColor: _isOnline ? Colors.green : Colors.grey,
          duration: const Duration(seconds: 2),
        ),
      );
      if (_isOnline) {
        _checkForNewRides();
      }
    } catch (e) {
      print('Erreur changement statut: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                            _buildHeader(),
                            _buildStatsCards(),
                            _buildQuickActions(),
                            _buildActiveRides(),
                            _buildEarningsChart(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
              // Notification de course
              if (_isOnline && _currentRideNotification != null)
                ChauffeurRideNotificationBanner(
                  ride: _currentRideNotification!,
                  onAccepted: (acceptedRide) {
                    setState(() {
                      _currentRideNotification = null;
                    });
                    _loadData();
                  },
                  onDismissed: () {
                    setState(() {
                      _currentRideNotification = null;
                    });
                  },
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.small(
            onPressed: _toggleOnlineStatus,
            backgroundColor: _isOnline ? Colors.green : Colors.grey,
            tooltip: _isOnline ? 'Passer hors ligne' : 'Passer en ligne',
            child: Icon(
              _isOnline ? Icons.toggle_on : Icons.toggle_off,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 16, 20, 24),
      decoration: const BoxDecoration(color: Color(0xFFFFF7D6)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bonjour ${_userData?['prenoms'] ?? 'Chauffeur'} 👋',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isOnline ? 'Vous êtes en ligne' : 'Vous êtes hors ligne',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const Profile()),
                  );
                },
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  backgroundImage: _userData?['photo'] != null &&
                          (_userData!['photo'] as String).isNotEmpty
                      ? NetworkImage(_userData!['photo'] as String)
                      : null,
                  child: _userData?['photo'] == null ||
                          (_userData!['photo'] as String).isEmpty
                      ? const Icon(
                          Icons.person,
                          color: Color(0xFFF8BF13),
                          size: 28,
                        )
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Portefeuille masqué (sans icône oeil)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF3E7A1)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Color(0xFFB8860B),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Portefeuille',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const Spacer(),
                Text(
                  _showBalance
                      ? NumberFormat.currency(
                          locale: 'fr_FR',
                          symbol: '$_currency ',
                          decimalDigits: 0,
                        ).format(_balance ?? 0)
                      : '••••••',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB8860B),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _showBalance = !_showBalance),
                  child: Icon(
                    _showBalance ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vos statistiques',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Aujourd\'hui',
                  '$_todayRides',
                  'Courses',
                  Icons.local_taxi,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Cette semaine',
                  '$_weekRides',
                  'Courses',
                  Icons.calendar_today,
                  Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Acceptées total',
                  '$_acceptedRidesTotal',
                  'Courses',
                  Icons.verified,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Non lues',
                  '$_unreadNotifications',
                  'Alertes',
                  Icons.notifications_active,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
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
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Actions rapides',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Historique',
                  Icons.history,
                  Colors.purple,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChauffeurTricycleHomePage(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Portefeuille',
                  Icons.account_balance_wallet,
                  Colors.green,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WalletScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionButton(
                  'Paramètres',
                  Icons.settings,
                  Colors.grey,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsPage(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveRides() {
    if (_activeRides.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.local_taxi,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Courses en cours',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._activeRides.map((ride) => _buildRideCard(ride, true)),
        ],
      ),
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride, bool isActive) {
    final acheteur = ride['acheteur'] ?? {};
    final name = '${acheteur['prenoms'] ?? ''} ${acheteur['nom'] ?? ''}'.trim();
    final destination = ride['destination'] ?? 'Destination non précisée';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFFFFF8E1)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? const Color(0xFFF8BF13) : Colors.grey.shade300,
          width: 1.5,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isNotEmpty ? name : 'Client',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        destination,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            color: Colors.grey.shade400,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsChart() {
    final paid = _loanPaid;
    final remaining = _loanRemaining;
    final total = (paid + remaining) <= 0 ? 1 : (paid + remaining);
    final progress = (paid / total).clamp(0.0, 1.0);
    final due = _loanDueDate;
    final dueLabel = due != null ? DateFormat('dd/MM/yyyy').format(due) : 'Choisir';

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFF9E8),
            const Color(0xFFFFF3CB),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF8BF13).withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Remboursement prêt',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _pickLoanDueDate,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_month,
                        size: 14,
                        color: Color(0xFFB8860B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dueLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFB8860B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildLoanInfoBox(
                  'Déjà payé',
                  NumberFormat.currency(
                    locale: 'fr_FR',
                    symbol: '$_currency ',
                    decimalDigits: 0,
                  ).format(paid),
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLoanInfoBox(
                  'Reste à payer',
                  NumberFormat.currency(
                    locale: 'fr_FR',
                    symbol: '$_currency ',
                    decimalDigits: 0,
                  ).format(remaining),
                  Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: progress,
              backgroundColor: Colors.white,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF8BF13)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              final step = (i + 1) / 6;
              final done = progress >= step;
              final isDue = i == 5;
              return Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: isDue
                      ? const Color(0xFFD32F2F)
                      : (done ? const Color(0xFFF8BF13) : Colors.white),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDue
                        ? const Color(0xFFD32F2F)
                        : const Color(0xFFF8BF13),
                    width: 1.5,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            'Calendrier de remboursement (point rouge = date limite)',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanInfoBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickLoanDueDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _loanDueDate ?? now,
      firstDate: now.subtract(const Duration(days: 3650)),
      lastDate: now.add(const Duration(days: 3650)),
      helpText: 'Choisir la date d\'échéance',
    );
    if (selected != null && mounted) {
      setState(() => _loanDueDate = selected);
    }
  }
}
