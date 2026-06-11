import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:tranoo_pro/config/backend_config.dart';
import 'package:tranoo_pro/data/screens/delivery_map_screen.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';

class MesLivraisonsPage extends StatefulWidget {
  const MesLivraisonsPage({super.key});

  @override
  State<MesLivraisonsPage> createState() => _MesLivraisonsPageState();
}

class _MesLivraisonsPageState extends State<MesLivraisonsPage>
    with SingleTickerProviderStateMixin {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  late TabController _tabController;
  List<Map<String, dynamic>> _pendingDeliveries = [];
  List<Map<String, dynamic>> _activeDeliveries = [];
  List<Map<String, dynamic>> _completedDeliveries = [];
  bool _loading = true;

  List<Map<String, dynamic>> _safeMapList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * (3.141592653589793 / 180);
    final dLon = (lon2 - lon1) * (3.141592653589793 / 180);
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(lat1 * (3.141592653589793 / 180)) *
            cos(lat2 * (3.141592653589793 / 180)) *
            (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _deliveryDistanceKm(Map<String, dynamic> delivery) {
    final apiDistance = _toDouble(delivery['distanceKm']);
    if (apiDistance != null && apiDistance > 0) return apiDistance;
    final depart = _asMap(delivery['lieuDepart']);
    final dest = _asMap(delivery['lieuDestination']);
    final lat1 = _toDouble(depart['latitude']);
    final lon1 = _toDouble(depart['longitude']);
    final lat2 = _toDouble(dest['latitude']);
    final lon2 = _toDouble(dest['longitude']);
    if (lat1 != null && lon1 != null && lat2 != null && lon2 != null) {
      return _haversineKm(lat1, lon1, lat2, lon2);
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDeliveries();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDeliveries() async {
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) throw Exception('Token manquant');

      final baseUrl = getBackendBaseUrl();

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

      // Charger l'historique des livraisons (terminées / refusées / annulées)
      final completedRes = await http.get(
        Uri.parse('$baseUrl/api/livreurs/deliveries/history'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (pendingRes.statusCode == 200) {
        final data = jsonDecode(pendingRes.body);
        setState(() {
          _pendingDeliveries = _safeMapList(data['deliveries']);
        });
      }

      if (activeRes.statusCode == 200) {
        final data = jsonDecode(activeRes.body);
        setState(() {
          _activeDeliveries = _safeMapList(data['deliveries']);
        });
      }

      if (completedRes.statusCode == 200) {
        final data = jsonDecode(completedRes.body);
        setState(() {
          _completedDeliveries = _safeMapList(data['deliveries']);
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

  Future<void> _acceptDelivery(String deliveryId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return;

      final baseUrl = getBackendBaseUrl();
      final response = await http.post(
        Uri.parse('$baseUrl/api/livreurs/deliveries/$deliveryId/accept'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.deliveryAcceptedSuccess),
            backgroundColor: Colors.green,
          ),
        );
        _loadDeliveries();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'acceptation'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Mes Livraisons',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFF8BF13),
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.black,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          tabs: const [
            Tab(text: 'En attente', icon: Icon(Icons.pending)),
            Tab(text: 'En cours', icon: Icon(Icons.local_shipping)),
            Tab(text: 'Terminées', icon: Icon(Icons.check_circle)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDeliveries,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDeliveriesList(_pendingDeliveries, 'pending'),
                  _buildDeliveriesList(_activeDeliveries, 'active'),
                  _buildDeliveriesList(_completedDeliveries, 'completed'),
                ],
              ),
            ),
    );
  }

  Widget _buildDeliveriesList(
      List<Map<String, dynamic>> deliveries, String type) {
    if (deliveries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'pending'
                  ? Icons.pending_actions
                  : type == 'active'
                      ? Icons.local_shipping
                      : Icons.check_circle_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              type == 'pending'
                  ? 'Aucune livraison en attente'
                  : type == 'active'
                      ? 'Aucune livraison en cours'
                      : 'Aucune livraison terminée',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: deliveries.length,
      itemBuilder: (context, index) {
        final delivery = deliveries[index];
        return _buildDeliveryCard(delivery, type);
      },
    );
  }

  Widget _buildDeliveryCard(Map<String, dynamic> delivery, String type) {
    final statut = delivery['statut'] ?? '';
    final lieuDepart = _asMap(delivery['lieuDepart']);
    final lieuDestination = _asMap(delivery['lieuDestination']);
    final distanceKm = _deliveryDistanceKm(delivery);
    final fraisLivraison = _toDouble(delivery['fraisLivraison']) ?? 0;
    final dateCommandeRaw = delivery['dateCommande']?.toString();
    final dateCommande =
        dateCommandeRaw != null ? DateTime.tryParse(dateCommandeRaw) : null;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (statut) {
      case 'commandé':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = 'En attente';
        break;
      case 'assigné':
      case 'en_cours':
        statusColor = Colors.blue;
        statusIcon = Icons.local_shipping;
        statusText = 'En cours';
        break;
      case 'livré':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Livré';
        break;
      case 'refusé':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Refusé';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = statut;
    }

    final card = Container(
        margin: const EdgeInsets.only(bottom: 16),
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
          // Header avec statut
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(statusIcon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Livraison #${((delivery['_id'] ?? 'N/A').toString().length > 8 ? (delivery['_id'] ?? 'N/A').toString().substring(0, 8) : (delivery['_id'] ?? 'N/A').toString())}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (dateCommande != null)
                  Text(
                    DateFormat('dd/MM').format(dateCommande),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          // Contenu
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Lieu de départ
                _buildLocationRow(
                  Icons.location_on,
                  Colors.blue,
                  'Départ',
                  lieuDepart['adresse'] ?? 'Adresse non disponible',
                ),
                const SizedBox(height: 12),
                // Lieu de destination
                _buildLocationRow(
                  Icons.location_city,
                  Colors.green,
                  'Destination',
                  lieuDestination['adresse'] ?? 'Adresse non disponible',
                ),
                const Divider(height: 24),
                // Informations
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoChip(
                      Icons.straighten,
                      '${distanceKm.toStringAsFixed(1)} km',
                      Colors.purple,
                    ),
                    _buildInfoChip(
                      Icons.attach_money,
                      '${NumberFormat.currency(locale: 'fr_FR', symbol: '').format(fraisLivraison)} XOF',
                      Colors.orange,
                    ),
                  ],
                ),
                // Pièces concernées
                if (delivery['pieces'] is List &&
                    (delivery['pieces'] as List).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Pièces concernées:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (delivery['pieces'] as List)
                        .map<Widget>((piece) => Chip(
                              label: Text(
                                '${(piece is Map ? piece['titre'] : null) ?? 'Pièce'} x${(piece is Map ? piece['quantite'] : null) ?? 1}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              backgroundColor: Colors.grey[100],
                              padding: EdgeInsets.zero,
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          // Actions
          if (type == 'pending')
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final id = delivery['_id']?.toString();
                    if (id != null && id.isNotEmpty) {
                      _acceptDelivery(id);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF8BF13),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Accepter la livraison',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (type == 'active') {
      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeliveryMapScreen(delivery: delivery),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: card,
      );
    }

    return card;
  }

  Widget _buildLocationRow(
      IconData icon, Color color, String label, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
