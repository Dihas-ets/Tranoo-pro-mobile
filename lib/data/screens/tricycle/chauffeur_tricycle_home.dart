import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:tranoo_pro/config/backend_config.dart';
import 'package:tranoo_pro/data/screens/discussion.dart';
import 'package:tranoo_pro/providers/auth_provider.dart' as myauth;

class ChauffeurTricycleHomePage extends StatefulWidget {
  const ChauffeurTricycleHomePage({super.key});

  @override
  State<ChauffeurTricycleHomePage> createState() =>
      _ChauffeurTricycleHomePageState();
}

class _ChauffeurTricycleHomePageState
    extends State<ChauffeurTricycleHomePage> {
  bool _loading = true;
  bool _isAvailable = false;
  Position? _currentPosition;
  List<Map<String, dynamic>> _incomingContacts = [];

  @override
  void initState() {
    super.initState();
    _initialize();
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
        setState(() {
          _incomingContacts = List<Map<String, dynamic>>.from(
            data['contacts'] ?? [],
          );
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement contacts tricycle: $e');
    }
  }

  Future<void> _toggleAvailability() async {
    try {
      final idToken = await _getIdToken();
      if (idToken == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Utilisateur non connecté'),
            ),
          );
        }
        return;
      }

      final newStatus = _isAvailable ? 'offline' : 'available';
      final baseUrl = getBackendBaseUrl();
      final res = await http.post(
        Uri.parse('$baseUrl/api/tricycles/chauffeur/status'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': newStatus}),
      );

      if (res.statusCode == 200) {
        setState(() {
          _isAvailable = newStatus == 'available';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isAvailable
                    ? 'Vous êtes disponible pour les demandes Tricycle.'
                    : 'Vous êtes passé hors ligne pour le service Tricycle.',
              ),
            ),
          );
        }
      } else {
        final body = jsonDecode(res.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Erreur: ${body['message'] ?? 'Impossible de changer le statut'}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erreur changement statut tricycle: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

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
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openDirections(Map<String, dynamic> contact) async {
    final user = contact['user'] as Map<String, dynamic>?;
    final location = user?['location'] as Map<String, dynamic>?;
    final coords = location?['coordinates'] as List<dynamic>?;
    if (coords == null || coords.length < 2) return;

    final lng = (coords[0] as num).toDouble();
    final lat = (coords[1] as num).toDouble();
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _toggleAvailability,
            backgroundColor: _isAvailable ? Colors.green : Colors.grey,
            icon: Icon(_isAvailable ? Icons.check_circle : Icons.power_settings_new),
            label: Text(_isAvailable ? 'Disponible' : 'Hors ligne'),
          ),
          body: _loading
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
        );
      },
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _isAvailable ? Colors.green : Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _isAvailable ? 'Disponible' : 'Hors ligne',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
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
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Nouvelle',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => _acceptContact(contact),
                icon: const Icon(Icons.check_circle, color: Colors.green),
                label: const Text(
                  'Accepter',
                  style: TextStyle(color: Colors.green),
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
              IconButton(
                tooltip: 'Appeler',
                icon: const Icon(Icons.call, color: Colors.green),
                onPressed: () => _callUser(contact),
              ),
              IconButton(
                tooltip: 'Itinéraire',
                icon: const Icon(Icons.directions, color: Colors.black87),
                onPressed: () => _openDirections(contact),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

