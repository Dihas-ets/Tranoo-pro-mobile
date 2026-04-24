import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:feexpay_flutter/feexpay_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:random_string/random_string.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dio/dio.dart';
import 'dart:math';
import 'dart:developer' as developer;
import '../../services/cart_service.dart';
import '../../services/user_service.dart';
import 'map_picker_screen.dart';

enum PaymentMethod { cash, online }

class OrderSummaryPage extends StatefulWidget {
  const OrderSummaryPage({super.key});

  @override
  State<OrderSummaryPage> createState() => _OrderSummaryPageState();
}

class _OrderSummaryPageState extends State<OrderSummaryPage> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  double _deliveryFee = 0; // Calculé automatiquement
  double _discount = 0;
  double _pricePerKm = 0;
  double? _deliveryLatitude;
  double? _deliveryLongitude;
  double? _supplierLatitude;
  double? _supplierLongitude;
  double? _deliveryDistanceKm;
  bool _isProcessing = false;
  final String _transKey = randomAlphaNumeric(15);

  @override
  void dispose() {
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * (pi / 180.0);
    final dLon = (lon2 - lon1) * (pi / 180.0);
    final la1 = lat1 * (pi / 180.0);
    final la2 = lat2 * (pi / 180.0);
    final h = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(la1) * cos(la2) * (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(h), sqrt(1 - h));
    return r * c;
  }

  Future<void> _loadDeliveryPricePerKm() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      final dio = Dio(
        BaseOptions(
          baseUrl: UserService().dio.options.baseUrl,
          headers: {
            if (token != null) 'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        ),
      );
      final response = await dio.get('/deliveries/settings');
      if (response.statusCode == 200) {
        final root = response.data is Map<String, dynamic>
            ? response.data as Map<String, dynamic>
            : <String, dynamic>{};
        final data = root['settings'] is Map<String, dynamic>
            ? root['settings'] as Map<String, dynamic>
            : root;
        final value = data['pricePerKm'];
        final parsed = value is num ? value.toDouble() : double.tryParse('$value');
        if (parsed != null && parsed >= 0) {
          _pricePerKm = parsed;
        }
        developer.log('[ORDER_SUMMARY_PRO] settings pricePerKm=$_pricePerKm');
      }
    } catch (e) {
      developer.log('[ORDER_SUMMARY_PRO] load pricePerKm error=$e');
    }
  }

  Future<void> _loadSupplierCoordsIfNeeded(CartService cart) async {
    if (_supplierLatitude != null && _supplierLongitude != null) return;
    if (cart.items.isEmpty) return;
    final articleId = cart.items.first.articleId;
    if (articleId.isEmpty) return;
    try {
      final dio = Dio(BaseOptions(baseUrl: UserService().dio.options.baseUrl));
      final response = await dio.get('/articles/$articleId');
      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : <String, dynamic>{};
      final article = data['article'] is Map<String, dynamic>
          ? data['article'] as Map<String, dynamic>
          : data;
      final fournisseur = article['fournisseur'] is Map<String, dynamic>
          ? article['fournisseur'] as Map<String, dynamic>
          : <String, dynamic>{};
      final lat = fournisseur['latitude'];
      final lng = fournisseur['longitude'];
      final parsedLat = lat is num ? lat.toDouble() : double.tryParse('$lat');
      final parsedLng = lng is num ? lng.toDouble() : double.tryParse('$lng');
      if (parsedLat != null && parsedLng != null && mounted) {
        setState(() {
          _supplierLatitude = parsedLat;
          _supplierLongitude = parsedLng;
        });
      }
    } catch (_) {}
  }

  Future<void> _recalculateDeliveryFee(CartService cart) async {
    if (_deliveryLatitude == null || _deliveryLongitude == null) return;
    await _loadDeliveryPricePerKm();
    await _loadSupplierCoordsIfNeeded(cart);
    if (_supplierLatitude == null || _supplierLongitude == null || !mounted) return;

    final km = _haversineKm(
      _supplierLatitude!,
      _supplierLongitude!,
      _deliveryLatitude!,
      _deliveryLongitude!,
    );
    final fee = (km * _pricePerKm).roundToDouble();
    setState(() {
      _deliveryDistanceKm = km;
      _deliveryFee = fee < 0 ? 0 : fee;
      _discount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Résumé'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
      ),
      body: Consumer<CartService>(
        builder: (context, cart, child) {
          final double subtotal = cart.subtotal;
          final double total = (subtotal + _deliveryFee - _discount).clamp(
            0,
            double.infinity,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mon panier (liste courte)
                const Text(
                  'Mon panier',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...cart.items.map(
                  (i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${i.quantity} x ${i.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text('${i.totalPrice.toStringAsFixed(0)} F'),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 24),

                // Livraison à
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Livraison à',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _selectLocationFromMap(cart),
                      icon: const Icon(Icons.map, size: 16),
                      label: const Text('Choisir sur la carte'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    hintText: 'Adresse de livraison',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  maxLength: 500,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Ajouter une note de livraison',
                    border: OutlineInputBorder(),
                    counterText: '0/500',
                  ),
                ),

                const SizedBox(height: 8),
                // Total de la commande
                const Text(
                  'Total de la commande',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                _rowKV('Sous-total', '${subtotal.toStringAsFixed(0)} F'),
                const SizedBox(height: 6),
                _rowKV(
                  'Frais de livraison',
                  '${_deliveryFee.toStringAsFixed(0)} F',
                ),
                if (_deliveryDistanceKm != null) ...[
                  const SizedBox(height: 6),
                  _rowKV(
                    'Distance',
                    '${_deliveryDistanceKm!.toStringAsFixed(2)} km',
                  ),
                  const SizedBox(height: 6),
                  _rowKV(
                    'Tarif/km',
                    '${_pricePerKm.toStringAsFixed(0)} F',
                  ),
                ],
                const SizedBox(height: 6),
                _rowKV(
                  'Remise sur la livraison',
                  '-${_discount.toStringAsFixed(0)} F',
                ),
                const Divider(height: 24),
                _rowKV('Total', '${total.toStringAsFixed(0)} F', isBold: true),

                const SizedBox(height: 16),
                // Mode de paiement
                const Text(
                  'Mode de paiement',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            () => setState(() => _method = PaymentMethod.cash),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color:
                                _method == PaymentMethod.cash
                                    ? Colors.amber
                                    : Colors.grey.shade300,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.money, size: 18),
                        label: const Text('Espèces'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            () =>
                                setState(() => _method = PaymentMethod.online),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color:
                                _method == PaymentMethod.online
                                    ? Colors.amber
                                    : Colors.grey.shade300,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.credit_card, size: 18),
                        label: const Text('En ligne'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        cart.items.isEmpty || _isProcessing
                            ? null
                            : () async {
                              if (_method == PaymentMethod.cash) {
                                // Confirmer commande espèces
                                final confirmed = await _confirmCashOrder();
                                if (confirmed && mounted) {
                                  await _processCashOrder(total, cart);
                                }
                                return;
                              }
                              // Auto-redirection directe vers FeexPay
                              await _processOnlinePayment(total);
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child:
                        _isProcessing
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : Text('Commander • ${total.toStringAsFixed(0)} F'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _rowKV(String k, String v, {bool isBold = false, Widget? trailing}) {
    final textStyle = TextStyle(
      fontSize: 16,
      fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
    );
    return Row(
      children: [
        Expanded(child: Text(k, style: const TextStyle(color: Colors.black54))),
        if (trailing != null) ...[trailing, const SizedBox(width: 8)],
        Text(v, style: textStyle),
      ],
    );
  }

  Future<void> _selectLocationFromMap(CartService cart) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(
          initialLatitude: _deliveryLatitude,
          initialLongitude: _deliveryLongitude,
        ),
      ),
    );
    if (result != null && result is Map<String, dynamic> && mounted) {
      final lat = (result['latitude'] as num?)?.toDouble();
      final lng = (result['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return;
      setState(() {
        _deliveryLatitude = lat;
        _deliveryLongitude = lng;
        _addressController.text =
            'Position: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
      });
      await _recalculateDeliveryFee(cart);
    }
  }

  Future<bool> _confirmCashOrder() async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.money,
                        color: Colors.amber,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Paiement à la livraison',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vous avez choisi le paiement à la livraison.',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Vous serez facturé lors de la réception de votre commande.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Confirmer la commande',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
        ) ??
        false;
  }

  Future<void> _processCashOrder(double total, CartService cart) async {
    setState(() => _isProcessing = true);

    try {
      // Enregistrer la commande en BDD
      await _saveOrderToDatabase(total, cart, 'cash');

      if (mounted) {
        // Vider le panier
        await cart.clear();

        // Afficher le modal de succès
        await _showSuccessModal();

        // Retourner à l'accueil
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'enregistrement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _processOnlinePayment(double total) async {
    setState(() => _isProcessing = true);

    try {
      final token = dotenv.env['FP_TOKEN_FEEXPAY'] ?? '';
      final idUser = dotenv.env['ID_USER_FEEXPAY'] ?? '';

      if (token.isEmpty || idUser.isEmpty) {
        throw Exception('Configuration FeexPay manquante');
      }

      // Redirection directe vers FeexPay
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => ChoicePage(
                token: token,
                id: idUser,
                amount: total.toStringAsFixed(0),
                redirecturl: '/cart-payment-success',
                errorredirecturl: '/cart-payment-error',
                trans_key: _transKey,
              ),
        ),
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de paiement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveOrderToDatabase(
    double total,
    CartService cart,
    String paymentMethod,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    final token = await user.getIdToken();
    final dio = Dio(
      BaseOptions(
        baseUrl: UserService().dio.options.baseUrl,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );

    final orderData = {
      'items':
          cart.items
              .map(
                (item) => {
                  'articleId': item.articleId,
                  'title': item.title,
                  'quantity': item.quantity,
                  'unitPrice': item.unitPrice,
                  'totalPrice': item.totalPrice,
                },
              )
              .toList(),
      'subtotal': cart.subtotal,
      'deliveryFee': _deliveryFee,
      'discount': _discount,
      'total': total,
      'paymentMethod': paymentMethod,
      'deliveryAddress': _addressController.text.trim(),
      'deliveryNote': _noteController.text.trim(),
      'status': paymentMethod == 'cash' ? 'pending' : 'paid',
      'deliveryInfo': {
        'distanceKm': _deliveryDistanceKm,
        'lieuDestination': {
          'adresse': _addressController.text.trim(),
          'latitude': _deliveryLatitude,
          'longitude': _deliveryLongitude,
        },
        'fournisseur': {
          'latitude': _supplierLatitude,
          'longitude': _supplierLongitude,
        },
      },
    };

    await dio.post('/orders', data: orderData);
  }

  Future<void> _showSuccessModal() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            contentPadding: const EdgeInsets.all(24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Commande confirmée !',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Votre commande a été enregistrée avec succès.',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.local_shipping,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Livraison prévue',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Entre 3 et 7 jours ouvrables',
                        style: TextStyle(fontSize: 14, color: Colors.blue),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.notifications,
                            color: Colors.amber,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Vous recevrez une notification',
                            style: TextStyle(fontSize: 12, color: Colors.amber),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Parfait !',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
