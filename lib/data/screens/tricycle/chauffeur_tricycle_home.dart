import 'dart:convert';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:tranoo_pro/config/backend_config.dart';
import 'package:tranoo_pro/data/screens/discussion.dart';
import 'package:tranoo_pro/data/screens/tricycle/call_preview_page.dart';
import 'package:tranoo_pro/providers/auth_provider.dart' as myauth;

class ChauffeurTricycleHomePage extends StatefulWidget {
  final String? initialContactId;
  const ChauffeurTricycleHomePage({super.key, this.initialContactId});

  @override
  State<ChauffeurTricycleHomePage> createState() =>
      _ChauffeurTricycleHomePageState();
}

class _ChauffeurTricycleHomePageState
    extends State<ChauffeurTricycleHomePage> {
  bool _loading = true;
  Position? _currentPosition;
  List<Map<String, dynamic>> _incomingContacts = [];
  Timer? _pollTimer;
  final Set<String> _seenContactIds = {};
  bool _initialPopupShown = false;

  List<Map<String, dynamic>> get _unreadIncomingContacts =>
      _incomingContacts
          .where((c) => c['readByChauffeurAt'] == null)
          .toList();

  @override
  void initState() {
    super.initState();
    _initialize();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) {
        _loadIncomingContacts();
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _ensureLocationPermission();
    await _refreshAll();
  }

  Future<void> _ensureLocationPermission() async {
    final status = await Permission.location.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La localisation est requise pour le service Tricycle.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _refreshAll() async {
    setState(() {
      _loading = true;
    });
    try {
      await _updateCurrentLocation();
      await _loadIncomingContacts();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<String?> _getIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    return user?.getIdToken();
  }

  Future<void> _updateCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
      });

      final idToken = await _getIdToken();
      if (idToken == null) return;

      final baseUrl = getBackendBaseUrl();
      await http.post(
        Uri.parse('$baseUrl/api/tricycles/location'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'latitude': position.latitude,
          'longitude': position.longitude,
        }),
      );
    } catch (e) {
      debugPrint('Erreur mise à jour localisation chauffeur tricycle: $e');
    }
  }

  Future<void> _loadIncomingContacts() async {
    try {
      final idToken = await _getIdToken();
      if (idToken == null) return;

      final baseUrl = getBackendBaseUrl();
      final res = await http.get(
        Uri.parse('$baseUrl/api/tricycles/contacts/incoming'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final contacts = List<Map<String, dynamic>>.from(
          data['contacts'] ?? [],
        );

        if (mounted) {
          setState(() {
            _incomingContacts = contacts;
          });
        }

        // Détecter une demande ciblée via initialContactId (tap notif)
        if (!_initialPopupShown &&
            widget.initialContactId != null &&
            contacts.isNotEmpty) {
          final targeted = contacts.firstWhere(
            (c) => c['_id']?.toString() == widget.initialContactId,
            orElse: () => {},
          );
          if (targeted.isNotEmpty) {
            _initialPopupShown = true;
            final id = targeted['_id']?.toString();
            if (id != null) _seenContactIds.add(id);
            _showIncomingContactDialog(targeted);
          }
        } else {
          // Sinon: popup auto sur nouvelle demande (polling)
          final newOnes = <Map<String, dynamic>>[];
          for (final c in contacts) {
            final id = c['_id']?.toString();
            if (id != null && !_seenContactIds.contains(id)) {
              _seenContactIds.add(id);
              newOnes.add(c);
            }
          }

          if (mounted && newOnes.isNotEmpty) {
            _showIncomingContactDialog(newOnes.last);
          }
        }
      }
    } catch (e) {
      debugPrint('Erreur chargement contacts tricycle: $e');
    }
  }

  Future<void> _showIncomingContactDialog(
    Map<String, dynamic> contact,
  ) async {
    if (!mounted) return;
    final user = contact['user'] as Map<String, dynamic>?;
    final name =
        '${user?['prenoms'] ?? ''} ${user?['nom'] ?? ''}'.trim().isEmpty
            ? 'Client'
            : '${user?['prenoms'] ?? ''} ${user?['nom'] ?? ''}'.trim();
    final phone = user?['telephone'] as String? ?? 'Téléphone non renseigné';
    final distanceKm = _distanceKmToBuyer(contact);

    final contactId = contact['_id']?.toString();
    if (contactId != null) _seenContactIds.add(contactId);

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Expanded(
                child: Text(
                  'Nouvelle demande Tricycle',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Fermer',
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                phone,
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              if (distanceKm != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Distance estimée: ${distanceKm.toStringAsFixed(2)} km',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Vous pouvez appeler le client ou accepter la demande pour voir la localisation exacte.',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _callUser(contact);
              },
              icon: const Icon(Icons.call, color: Colors.green),
              label: const Text(
                'Appeler',
                style: TextStyle(color: Colors.green),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _closeContact(contact);
              },
              icon: const Icon(Icons.close, color: Colors.red),
              label: const Text(
                'Rejeter',
                style: TextStyle(color: Colors.red),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _acceptContact(contact);
              },
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: const Text('Accepter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // _toggleAvailability supprimé: statut géré ailleurs (pas de bouton ici)

  Future<void> _acceptContact(Map<String, dynamic> contact) async {
    final id = contact['_id'] as String?;
    if (id == null) return;
    try {
      final idToken = await _getIdToken();
      if (idToken == null) return;

      final baseUrl = getBackendBaseUrl();
      final res = await http.post(
        Uri.parse('$baseUrl/api/tricycles/contacts/$id/accept'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (res.statusCode == 200) {
        await _loadIncomingContacts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Demande acceptée. Vous pouvez maintenant échanger.'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur acceptContact: $e');
    }
  }

  Future<void> _openDiscussion(Map<String, dynamic> contact) async {
    final id = contact['_id'] as String?;
    if (id == null) return;
    try {
      final idToken = await _getIdToken();
      if (idToken == null) return;

      final baseUrl = getBackendBaseUrl();
      final res = await http.get(
        Uri.parse('$baseUrl/api/tricycles/contacts/$id'),
        headers: {'Authorization': 'Bearer $idToken'},
      );
      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final room = (data['room'] ?? {}) as Map<String, dynamic>;
      final roomId = data['roomId'] as String?;
      if (roomId == null) return;

      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Discussion(
              roomId: roomId,
              roomData: room,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur openDiscussion: $e');
    }
  }

  Future<void> _callUser(Map<String, dynamic> contact) async {
    final user = contact['user'] as Map<String, dynamic>?;
    final phone = user?['telephone'] as String?;
    if (phone == null || phone.isEmpty) return;
    final name =
        '${user?['prenoms'] ?? ''} ${user?['nom'] ?? ''}'.trim().isEmpty
            ? 'Client'
            : '${user?['prenoms'] ?? ''} ${user?['nom'] ?? ''}'.trim();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallPreviewPage(name: name, phone: phone),
      ),
    );
  }

  Future<void> _openDirections(Map<String, dynamic> contact) async {
    double? lat;
    double? lng;

    final snap = contact['userLocationSnapshot'] as Map<String, dynamic>?;
    if (snap != null) {
      final la = snap['latitude'];
      final lo = snap['longitude'];
      if (la != null && lo != null) {
        lat = (la as num).toDouble();
        lng = (lo as num).toDouble();
      }
    }
    if (lat == null || lng == null) {
      final user = contact['user'] as Map<String, dynamic>?;
      final location = user?['location'] as Map<String, dynamic>?;
      final coords = location?['coordinates'] as List<dynamic>?;
      if (coords == null || coords.length < 2) return;
      lng = (coords[0] as num).toDouble();
      lat = (coords[1] as num).toDouble();
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _markContactAsRead(Map<String, dynamic> contact) async {
    final id = contact['_id'] as String?;
    if (id == null) return;
    try {
      final idToken = await _getIdToken();
      if (idToken == null) return;
      final baseUrl = getBackendBaseUrl();
      await http.post(
        Uri.parse('$baseUrl/api/tricycles/contacts/$id/read'),
        headers: {'Authorization': 'Bearer $idToken'},
      );
      await _loadIncomingContacts();
    } catch (_) {}
  }

  double? _distanceKmToBuyer(Map<String, dynamic> contact) {
    final pos = _currentPosition;
    if (pos == null) return null;

    double? lat;
    double? lng;
    final snap = contact['userLocationSnapshot'] as Map<String, dynamic>?;
    if (snap != null) {
      final la = snap['latitude'];
      final lo = snap['longitude'];
      if (la != null && lo != null) {
        lat = (la as num).toDouble();
        lng = (lo as num).toDouble();
      }
    }
    if (lat == null || lng == null) {
      final user = contact['user'] as Map<String, dynamic>?;
      final location = user?['location'] as Map<String, dynamic>?;
      final coords = location?['coordinates'] as List<dynamic>?;
      if (coords == null || coords.length < 2) return null;
      lng = (coords[0] as num).toDouble();
      lat = (coords[1] as num).toDouble();
    }
    final m = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      lat,
      lng,
    );
    return m / 1000.0;
  }

  Future<void> _closeContact(Map<String, dynamic> contact) async {
    final id = contact['_id'] as String?;
    if (id == null) return;
    try {
      final idToken = await _getIdToken();
      if (idToken == null) return;
      final baseUrl = getBackendBaseUrl();
      final res = await http.post(
        Uri.parse('$baseUrl/api/tricycles/contacts/$id/close'),
        headers: {'Authorization': 'Bearer $idToken'},
      );
      if (res.statusCode == 200) {
        await _loadIncomingContacts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Demande rejetée.'),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur closeContact: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<myauth.AuthProvider>(
      builder: (context, auth, _) {
        final user = auth.user;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Tricycle - Chauffeur'),
            backgroundColor: const Color(0xFFF8BF13),
            foregroundColor: Colors.black,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _refreshAll,
              ),
            ],
          ),
          body: Stack(
            children: [
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _refreshAll,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildHeader(user),
                          const SizedBox(height: 16),
                          _buildLocationInfo(),
                          const SizedBox(height: 16),
                          _buildIncomingContactsSection(),
                        ],
                      ),
                    ),
              if (_unreadIncomingContacts.isNotEmpty)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 90,
                  child: _buildFloatingContactBanner(
                    _unreadIncomingContacts.first,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFloatingContactBanner(Map<String, dynamic> contact) {
    final user = contact['user'] as Map<String, dynamic>?;
    final name =
        '${user?['prenoms'] ?? ''} ${user?['nom'] ?? ''}'.trim().isEmpty
            ? 'Client Tricycle'
            : '${user?['prenoms'] ?? ''} ${user?['nom'] ?? ''}'.trim();
    final phone = user?['telephone'] as String? ?? '';
    final distanceKm = _distanceKmToBuyer(contact);

    void onAction() {
      _markContactAsRead(contact);
      setState(() {});
    }

    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF8BF13), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8BF13).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.directions_car,
                    color: Color(0xFFF8BF13),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nouvelle demande Tricycle',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          phone,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                      if (distanceKm != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 16, color: Colors.green[700]),
                            const SizedBox(width: 4),
                            Text(
                              '${distanceKm.toStringAsFixed(2)} Km',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 22),
                  onPressed: () {
                    onAction();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      onAction();
                      _callUser(contact);
                    },
                    icon: const Icon(Icons.call, size: 22),
                    label: const Text('Appeler'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      onAction();
                      _openDirections(contact);
                    },
                    icon: const Icon(Icons.map, size: 20),
                    label: const Text('Carte'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue[700],
                      side: BorderSide(color: Colors.blue[700]!),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    onAction();
                    _acceptContact(contact);
                  },
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Accepter'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    onAction();
                    _openDiscussion(contact);
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Discuter'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic>? user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.grey[300],
            backgroundImage: user != null &&
                    user['photo'] != null &&
                    (user['photo'] as String).isNotEmpty
                ? NetworkImage(user['photo'] as String)
                : null,
            child: user == null ||
                    user['photo'] == null ||
                    (user['photo'] as String).isEmpty
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user != null
                      ? '${user['prenoms'] ?? ''} ${user['nom'] ?? ''}'.trim()
                      : 'Chauffeur',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInfo() {
    final hasLocation = _currentPosition != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            hasLocation ? Icons.location_on : Icons.location_off,
            color: hasLocation ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasLocation
                      ? 'Position active'
                      : 'Localisation inactive',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasLocation
                      ? 'Votre position est partagée pour recevoir des demandes proches.'
                      : 'Activez la localisation pour apparaître chez les utilisateurs.',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _updateCurrentLocation,
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingContactsSection() {
    if (_incomingContacts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aucune demande en cours',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Quand un utilisateur vous contacte, les demandes apparaîtront ici.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Demandes Tricycle',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ..._incomingContacts.map(_buildContactCard),
      ],
    );
  }

  Widget _buildContactCard(Map<String, dynamic> contact) {
    final user = contact['user'] as Map<String, dynamic>?;
    final name =
        '${user?['prenoms'] ?? ''} ${user?['nom'] ?? ''}'.trim().isEmpty
            ? 'Client'
            : '${user?['prenoms'] ?? ''} ${user?['nom'] ?? ''}'.trim();
    final phone = user?['telephone'] as String?;
    final status = contact['status']?.toString() ?? '';
    final bool isAccepted = status == 'accepted';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.grey[300],
                backgroundImage: user != null &&
                        user['photo'] != null &&
                        (user['photo'] as String).isNotEmpty
                    ? NetworkImage(user['photo'] as String)
                    : null,
                child: user == null ||
                        user['photo'] == null ||
                        (user['photo'] as String).isEmpty
                    ? const Icon(Icons.person_outline, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phone ?? 'Téléphone non renseigné',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isAccepted ? Colors.green[100] : Colors.orange[100]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isAccepted ? 'Acceptée' : 'Nouvelle',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isAccepted ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (!isAccepted) ...[
                // Avant acceptation : Appeler + Accepter + Rejeter
                IconButton(
                  tooltip: 'Appeler',
                  icon: const Icon(Icons.call, color: Colors.green),
                  onPressed: () => _callUser(contact),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => _acceptContact(contact),
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  label: const Text(
                    'Accepter',
                    style: TextStyle(color: Colors.green),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => _closeContact(contact),
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: const Text(
                    'Rejeter',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ] else ...[
                // Après acceptation : Localiser + Discuter
                TextButton.icon(
                  onPressed: () => _openDirections(contact),
                  icon: const Icon(Icons.directions, color: Colors.black87),
                  label: const Text(
                    'Localiser',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openDiscussion(contact),
                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
                  label: const Text(
                    'Discuter',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

