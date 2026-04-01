import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:tranoo_pro/config/backend_config.dart';
import 'RetraitScreen.dart';
import 'settings_page.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  WalletScreenState createState() => WalletScreenState();
}

class WalletScreenState extends State<WalletScreen> {
  double? _balance;
  String _currency = 'XOF';
  List<Map<String, dynamic>> _transactions = [];
  bool _loading = true;
  DateTime _selectedMonth = DateTime.now();
  List<double> _weeklyData = [0, 0, 0, 0, 0, 0, 0];
  double _totalOrders = 0;
  double _totalKm = 0;
  // Profil utilisateur (dynamique)
  String? _userPhoto;
  String _userName = '';
  String _userRole = '';
  String _userVehicle = '';
  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final fullName = _userName.isNotEmpty ? _userName : '—';
    final role = _userRole.isNotEmpty ? _userRole : '—';
    final vehicleLine = _userVehicle.isNotEmpty ? _userVehicle : '—';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header avec photo de profil
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.grey[200],
                      backgroundImage:
                          _userPhoto != null && _userPhoto!.isNotEmpty
                              ? NetworkImage(_userPhoto!)
                              : null,
                      child: _userPhoto == null || _userPhoto!.isEmpty
                          ? const Icon(Icons.person, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            role,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            vehicleLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined,
                          color: Colors.grey),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SettingsPage()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Section Solde Actuel
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Solde actuel',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _loading
                                ? const SizedBox(
                                    height: 40,
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF4CAF50),
                                      ),
                                    ),
                                  )
                                : Text(
                                    _balance == null
                                        ? '--'
                                        : NumberFormat.currency(
                                            locale: 'fr_FR',
                                            symbol: '$_currency ',
                                            decimalDigits: 0,
                                          ).format(_balance),
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const RetraitScreen()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                              ),
                              child: const Text(
                                'Retirer',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Section Statistiques
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Statistiques',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // En-tête du graphique avec sélection du mois
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('MMMM yyyy', 'fr_FR')
                                .format(_selectedMonth),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left,
                                    color: Colors.grey),
                                onPressed: () {
                                  setState(() {
                                    _selectedMonth = DateTime(
                                      _selectedMonth.year,
                                      _selectedMonth.month - 1,
                                      1,
                                    );
                                  });
                                  _loadWallet();
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right,
                                    color: Colors.grey),
                                onPressed: () {
                                  setState(() {
                                    _selectedMonth = DateTime(
                                      _selectedMonth.year,
                                      _selectedMonth.month + 1,
                                      1,
                                    );
                                  });
                                  _loadWallet();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Graphique
                    Container(
                      height: 200,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          // Légendes
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildLegend(
                                  'Cette semaine', const Color(0xFF4CAF50)),
                              const SizedBox(width: 20),
                              _buildLegend('Semaine précédente',
                                  const Color(0xFF2196F3)),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Graphique
                          Expanded(
                            child: _buildChart(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Métriques en bas
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Commandes honorées',
                            value: '${_totalOrders.toInt()}',
                            unit: _currency,
                            color: const Color(0xFF4CAF50),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Kilométrage',
                            value: '${_totalKm.toInt()}',
                            unit: 'km',
                            color: const Color(0xFF2196F3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Transactions récentes
                    const Text(
                      'Transactions récentes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildTransactionList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildChart() {
    // Si aucune donnée, éviter les divisions par 0 et les hauteurs NaN
    if (_weeklyData.isEmpty || _weeklyData.every((v) => v == 0)) {
      return const Center(
        child: Text(
          'Pas encore de données',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    final maxValue = _weeklyData.reduce((a, b) => a > b ? a : b);
    final safeMax = maxValue > 0 ? maxValue : 1;
    final days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableH = constraints.maxHeight;
        final barsZoneH = (availableH - 26).clamp(40.0, 90.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(days.length, (index) {
            final value = _weeklyData[index];
            final height = (value / safeMax) * barsZoneH;
            final previousHeight =
                index > 0 ? (_weeklyData[index - 1] / safeMax) * barsZoneH : 0.0;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: barsZoneH,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Container(
                            width: 6,
                            height: previousHeight,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          Container(
                            width: 12,
                            height: height,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      days[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    if (_transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: const Column(
          children: [
            Icon(Icons.receipt_long, color: Colors.grey, size: 48),
            SizedBox(height: 16),
            Text(
              'Aucune transaction récente',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _transactions.take(5).map((tx) {
        final dateStr = tx['date'] != null
            ? DateFormat('dd MMMM yyyy', 'fr_FR')
                .format(DateTime.parse(tx['date']))
            : '';
        final isCredit = tx['type'] == 'in';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      isCredit ? Colors.green.shade100 : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(
                  isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isCredit ? Colors.green : Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx['label'] ?? (isCredit ? 'Revenu' : 'Retrait'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (dateStr.isNotEmpty)
                      Text(
                        dateStr,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                NumberFormat.currency(
                  locale: 'fr_FR',
                  symbol: '${tx['currency'] ?? _currency} ',
                  decimalDigits: 0,
                ).format(tx['amount'] ?? 0),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isCredit ? Colors.green : Colors.black,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    setState(() {
      _loading = true;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) throw Exception('Token manquant');
      final baseUrl = getBackendBaseUrl();
      final headers = {'Authorization': 'Bearer $idToken'};

      final walletRes = await http.get(
        Uri.parse('$baseUrl/api/wallet/me'),
        headers: headers,
      );
      final txRes = await http.get(
        Uri.parse('$baseUrl/api/wallet/me/transactions'),
        headers: headers,
      );
      final profileRes = await http.get(
        Uri.parse('$baseUrl/api/protected/me'),
        headers: headers,
      );
      final statsRes = await http.get(
        Uri.parse('$baseUrl/api/wallet/me/stats'),
        headers: headers,
      );

      if (walletRes.statusCode == 200) {
        final data = jsonDecode(walletRes.body);
        _balance = _num(data['balance']);
        _currency = data['currency'] ?? 'XOF';
      }
      if (txRes.statusCode == 200) {
        final data = jsonDecode(txRes.body);
        final List list = data['transactions'] ?? [];
        _transactions = list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (profileRes.statusCode == 200) {
        final data = jsonDecode(profileRes.body);
        final u = data['user'];
        if (u is Map<String, dynamic>) {
          _userName = '${u['prenoms'] ?? ''} ${u['nom'] ?? ''}'.trim();
          if (_userName.isEmpty)
            _userName = (u['nom'] ?? u['email'] ?? '')?.toString() ?? '';
          _userRole = _formatRole(u['role']?.toString() ?? '');
          final v = u['vehicule'];
          if (v is Map<String, dynamic>) {
            final type = v['type']?.toString() ?? 'Véhicule';
            final plate = v['immatriculation']?.toString() ?? '';
            _userVehicle = plate.isNotEmpty ? '$type • $plate' : type;
          } else {
            _userVehicle = 'Véhicule';
          }
          _userPhoto = u['photo']?.toString();
        }
      }
      if (statsRes.statusCode == 200) {
        final data = jsonDecode(statsRes.body);
        _totalOrders = _num(data['totalOrders']);
        _totalKm = _num(data['totalKm']);
        final list = data['weeklyData'];
        if (list is List && list.length >= 7) {
          _weeklyData =
              list.map((e) => (e is num ? e.toDouble() : 0.0)).toList();
        }
      }
    } catch (e) {
      print('Erreur chargement portefeuille: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _formatRole(String role) {
    switch (role.toLowerCase()) {
      case 'livreur':
        return 'Livreur';
      case 'chauffeur':
        return 'Chauffeur';
      case 'vendeur':
        return 'Vendeur';
      case 'acheteur':
        return 'Acheteur';
      case 'transitaire':
        return 'Transitaire';
      case 'agentcommercial':
        return 'Agent commercial';
      case 'admin':
        return 'Admin';
      default:
        return role.isNotEmpty ? role : '—';
    }
  }
}
