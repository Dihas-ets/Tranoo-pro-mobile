import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:tranoo_pro/config/backend_config.dart';

class ChauffeurRidesHistoryPage extends StatefulWidget {
  const ChauffeurRidesHistoryPage({super.key});

  @override
  State<ChauffeurRidesHistoryPage> createState() =>
      _ChauffeurRidesHistoryPageState();
}

class _ChauffeurRidesHistoryPageState extends State<ChauffeurRidesHistoryPage> {
  List<Map<String, dynamic>> _completedRides = [];
  bool _loading = true;
  String _selectedFilter = 'all'; // all, today, week, month

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) throw Exception('Token manquant');

      final baseUrl = getBackendBaseUrl();
      final res = await http.get(
        Uri.parse('$baseUrl/api/chauffeurs/rides/history?filter=$_selectedFilter'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _completedRides =
              List<Map<String, dynamic>>.from(data['rides'] ?? []);
        });
      }
    } catch (e) {
      print('Erreur chargement historique: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Historique des courses'),
        backgroundColor: const Color(0xFFF8BF13),
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filtres
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Tous', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Aujourd\'hui', 'today'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Cette semaine', 'week'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Ce mois', 'month'),
                ],
              ),
            ),
          ),

          // Liste
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _completedRides.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadHistory,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _completedRides.length,
                          itemBuilder: (context, index) {
                            return _buildRideCard(_completedRides[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilter = value);
        _loadHistory();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF8BF13) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildRideCard(Map<String, dynamic> ride) {
    final acheteur = ride['acheteur'] ?? {};
    final name = '${acheteur['prenoms'] ?? ''} ${acheteur['nom'] ?? ''}'.trim();
    final destination = ride['destination'] ?? 'Destination non précisée';
    final amount = ride['amount'] ?? 0;
    final date = ride['completedAt'] != null
        ? DateTime.parse(ride['completedAt'] as String)
        : DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
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
                            size: 24,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    name.isNotEmpty ? name : 'Client',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '${amount.toStringAsFixed(0)} FCFA',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  destination,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                DateFormat('dd/MM/yyyy à HH:mm').format(date),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune course terminée',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vos courses complétées apparaîtront ici',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
