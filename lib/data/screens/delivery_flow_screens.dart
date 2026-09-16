import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:tranoo_pro/config/backend_config.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';

// =============================================================================
// CODE MORT — écrans flux livraison livreur interne
// -----------------------------------------------------------------------------
// Gelé avec DeliveryMapScreen / LivreurHomePage. Livraison via Livro.
// Ne pas supprimer.
// =============================================================================

List<dynamic> _piecesForPickup(Map<String, dynamic> delivery, int? pickupIndex) {
  final pickups = delivery['pickups'];
  if (pickupIndex != null && pickups is List && pickupIndex >= 0 && pickupIndex < pickups.length) {
    final p = pickups[pickupIndex];
    if (p is Map) {
      final pieces = p['pieces'];
      if (pieces is List) return pieces;
    }
  }
  final pieces = delivery['pieces'];
  return pieces is List ? pieces : const [];
}

double _sumPiecesAmount(List<dynamic> pieces) {
  double total = 0;
  for (final p in pieces) {
    if (p is Map) {
      final prix = (p['prix'] as num?)?.toDouble() ?? 0;
      final q = (p['quantite'] as num?)?.toDouble() ?? 1;
      total += prix * q;
    }
  }
  return total;
}

// ——— ÉTAPE : VALIDATION / PRISE EN CHARGE (UI refonte) ———
class PackageValidationScreen extends StatefulWidget {
  final Map<String, dynamic> delivery;
  final int? pickupIndex;

  const PackageValidationScreen({
    super.key,
    required this.delivery,
    this.pickupIndex,
  });

  @override
  State<PackageValidationScreen> createState() => _PackageValidationScreenState();
}

class _PackageValidationScreenState extends State<PackageValidationScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  bool _submitting = false;

  Map<String, dynamic> get delivery => widget.delivery;

  List<dynamic> get _pieces => _piecesForPickup(delivery, widget.pickupIndex);

  int get _colisCount => 1;

  int get _articleCount {
    if (_pieces.isEmpty) return 1;
    int n = 0;
    for (final p in _pieces) {
      n += (p is Map && p['quantite'] != null)
          ? (p['quantite'] as num).toInt()
          : 1;
    }
    return n > 0 ? n : 1;
  }

  String get _amountLabel {
    final total = _sumPiecesAmount(_pieces);
    if (total > 0) return '${total.toStringAsFixed(0)} FCFA';
    final fallback = delivery['totalCommande'] ?? delivery['fraisLivraison'];
    if (fallback is num) return '${fallback.toStringAsFixed(0)} FCFA';
    return '—';
  }

  Future<void> _confirmPickup() async {
    if (_submitting) return;
    final id = delivery['_id']?.toString();
    if (id == null) return;
    try {
      setState(() => _submitting = true);
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      if (token == null) return;
      final uri = widget.pickupIndex != null
          ? Uri.parse(
              '${getBackendBaseUrl()}/api/deliveries/$id/pickup?pickupIndex=${widget.pickupIndex}',
            )
          : Uri.parse('${getBackendBaseUrl()}/api/deliveries/$id/pickup');
      final res = await http.post(uri, headers: {'Authorization': 'Bearer $token'});
      if (!mounted) return;
      if (res.statusCode == 200) {
        final finished = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => PickupFinishedScreen(colisCount: _colisCount),
          ),
        );
        if (finished == true && mounted) {
          Navigator.pop(context); // retourne à DeliveryMapScreen
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${res.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text('Prendre en charge $_colisCount colis'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Text(
                      '1',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(l10n.packageLabel,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '$_articleCount article${_articleCount > 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  _amountLabel,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, color: Colors.grey.shade500, size: 18),
              ],
            ),
            const SizedBox(height: 20), // espace normal (au lieu du Spacer)
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _submitting ? null : _confirmPickup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF8BF13),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text('Colis pris en charge', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PickupFinishedScreen extends StatelessWidget {
  final int colisCount;

  const PickupFinishedScreen({super.key, required this.colisCount});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text('Prise en charge de $colisCount colis'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$colisCount colis',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            
            const SizedBox(height: 20), // espace normal (au lieu du Spacer)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(l10n.back, style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF8BF13),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(l10n.finishedLabel, style: TextStyle(fontWeight: FontWeight.w800)),
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


class DeliveryQrScannerScreen extends StatefulWidget {
  final String expectedOrderId;
  final String expectedDeliveryId;

  const DeliveryQrScannerScreen({
    super.key,
    required this.expectedOrderId,
    required this.expectedDeliveryId,
  });

  @override
  State<DeliveryQrScannerScreen> createState() => _DeliveryQrScannerScreenState();
}

class _DeliveryQrScannerScreenState extends State<DeliveryQrScannerScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  bool _handled = false;
  final TextEditingController _qrController = TextEditingController();

  bool _isValidPayload(String raw) {
    final orderToken = 'TRN_ORDER:${widget.expectedOrderId}';
    final deliveryToken = 'DELIVERY:${widget.expectedDeliveryId}';
    return raw.contains(orderToken) && raw.contains(deliveryToken);
  }

  void _handleValue(String raw) {
    if (_handled) return;
    if (_isValidPayload(raw)) {
      _handled = true;
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR invalide pour cette commande.')),
      );
    }
  }

  @override
  void dispose() {
    _qrController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: const Text('Valider livraison')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Saisissez le contenu du QR pour finaliser la livraison.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qrController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n.qrContent,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _handleValue(_qrController.text.trim()),
              child: Text(l10n.validate),
            ),
            const SizedBox(height: 8),
            Text(
              'Format attendu: TRN_ORDER:${widget.expectedOrderId} et DELIVERY:${widget.expectedDeliveryId}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}
