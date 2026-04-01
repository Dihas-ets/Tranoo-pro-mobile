import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tranoo_pro/config/backend_config.dart';

class WalletVendeurScreen extends StatefulWidget {
  const WalletVendeurScreen({super.key});

  @override
  State<WalletVendeurScreen> createState() => _WalletVendeurScreenState();
}

class _WalletVendeurScreenState extends State<WalletVendeurScreen> {
  bool _loading = true;
  bool _showBalance = false;
  double _balance = 0;
  String _currency = 'XOF';
  List<Map<String, dynamic>> _transactions = const [];

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) return;

      final baseUrl = getBackendBaseUrl();
      final res = await http.get(
        Uri.parse('$baseUrl/api/wallet/me/stats'),
        headers: {'Authorization': 'Bearer $idToken'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final txRaw = data['transactions'];
        final tx = (txRaw is List)
            ? txRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];

        if (!mounted) return;
        setState(() {
          _balance = _num(data['balance']);
          _currency = (data['currency'] ?? 'XOF').toString();
          _transactions = tx;
        });
      }
    } catch (_) {
      // on laisse l'écran fonctionner même si API échoue
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portefeuille'),
        backgroundColor: const Color(0xFFFFF7D6),
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadWallet,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7D6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF3E7A1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Solde',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _showBalance
                              ? '${_balance.toStringAsFixed(0)} $_currency'
                              : '•••••• $_currency',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _showBalance = !_showBalance),
                        icon: Icon(
                          _showBalance ? Icons.visibility_off : Icons.visibility,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_loading)
                    const LinearProgressIndicator(minHeight: 3)
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Transactions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            if (_transactions.isEmpty && !_loading)
              const Text(
                'Aucune transaction pour le moment.',
                style: TextStyle(color: Colors.black54),
              ),
            ..._transactions.map((t) {
              final label = (t['label'] ?? t['type'] ?? 'Transaction').toString();
              final amount = _num(t['amount']);
              final isCredit = (t['direction']?.toString().toLowerCase() == 'credit') || amount >= 0;
              final amountAbs = amount.abs();
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isCredit
                            ? const Color(0xFF2E7D32).withOpacity(0.10)
                            : Colors.red.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isCredit ? const Color(0xFF2E7D32) : Colors.red,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${isCredit ? '+' : '-'}${amountAbs.toStringAsFixed(0)} $_currency',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: isCredit ? const Color(0xFF2E7D32) : Colors.red,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

