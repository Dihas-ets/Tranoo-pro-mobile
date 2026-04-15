import 'package:flutter/material.dart';
import 'package:feexpay_flutter/feexpay_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:random_string/random_string.dart';
import 'package:dio/dio.dart';
import 'package:tranoo_pro/services/user_service.dart';
import 'package:tranoo_pro/services/subscription_access_service.dart';

class SellerSubscriptionPage extends StatefulWidget {
  const SellerSubscriptionPage({super.key});

  @override
  State<SellerSubscriptionPage> createState() => _SellerSubscriptionPageState();
}

class _SellerSubscriptionPageState extends State<SellerSubscriptionPage> {
  final SubscriptionAccessService _subscriptionService =
      SubscriptionAccessService();
  final UserService _userService = UserService();
  SellerAccessStatus? _status;
  bool _loading = true;
  bool _subscribing = false;
  String? _error;
  int _selectedMonths = 1;
  List<Map<String, dynamic>> _subscriptionHistory = [];

  final String _fpToken = dotenv.env['FP_TOKEN_FEEXPAY'] ?? '';
  final String _fpShopId = dotenv.env['ID_USER_FEEXPAY'] ?? '';

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await _subscriptionService.getSellerAccessStatus();
      final history = await _subscriptionService.getSubscriptionHistory(limit: 10);
      if (!mounted) return;
      setState(() {
        _status = status;
        _subscriptionHistory = history;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les informations d\'abonnement.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _openMonthPicker() async {
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        int temp = _selectedMonths;
        final controller = FixedExtentScrollController(
          initialItem: _selectedMonths - 1,
        );
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final media = MediaQuery.of(ctx);
            final maxSheetHeight = media.size.height * 0.62;
            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
              child: SizedBox(
              height: maxSheetHeight,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Choisir la duree',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    flex: 10,
                    child: ListWheelScrollView.useDelegate(
                      controller: controller,
                      itemExtent: 48,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (idx) {
                        setModal(() => temp = idx + 1);
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: 12,
                        builder: (context, index) {
                          final m = index + 1;
                          final selected = m == temp;
                          return Center(
                            child: Text(
                              '$m mois',
                              style: TextStyle(
                                fontSize: selected ? 22 : 18,
                                fontWeight:
                                    selected ? FontWeight.bold : FontWeight.w500,
                                color: selected
                                    ? const Color(0xFFB45309)
                                    : Colors.black87,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, temp),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF8BF13),
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Valider'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _selectedMonths = result;
      });
    }
  }

  Future<void> _subscribe() async {
    setState(() {
      _subscribing = true;
      _error = null;
    });
    try {
      if (_fpToken.isEmpty || _fpShopId.isEmpty) {
        throw Exception('Configuration FeexPay manquante');
      }

      final amount = (_selectedMonths * (_status?.monthlyPriceFcfa ?? 5000))
          .toString();
      final transKey = randomAlphaNumeric(15);

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChoicePage(
            token: _fpToken,
            id: _fpShopId,
            amount: amount,
            redirecturl: '/subscription-success',
            errorredirecturl: '/subscription-error',
            trans_key: transKey,
          ),
        ),
      );

      final isSuccess = _isFeexPaySuccess(result);
      if (!isSuccess) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paiement echoue ou annule.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        throw Exception('Utilisateur non connecte');
      }

      final dio = Dio(
        BaseOptions(
          baseUrl: _userService.dio.options.baseUrl,
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      await dio.post(
        '/payments/feexpay/flutter/record',
        data: {
          'transKey': transKey,
          'amount': num.parse(amount),
          'description': 'Paiement abonnement vendeur ($_selectedMonths mois)',
          'type': 'subscription',
          'status': 'success',
          'duree': '$_selectedMonths mois',
        },
      );

      await _subscriptionService.activateMonthlySubscription(
        months: _selectedMonths,
      );
      await _loadStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paiement reussi: abonnement active avec succes.'),
          backgroundColor: Color(0xFF0461B6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erreur lors de l\'activation de l\'abonnement.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Echec du paiement ou de l\'activation.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _subscribing = false;
        });
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '--';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateShort(dynamic raw) {
    if (raw == null) return '--';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return '--';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  bool _isFeexPaySuccess(dynamic result) {
    if (result == null) return false;
    if (result is bool) return result;
    final payload = result.toString().toLowerCase();
    if (payload.contains('success') ||
        payload.contains('successful') ||
        payload.contains('paid') ||
        payload.contains('ok')) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Abonnement vendeur'),
        backgroundColor: const Color(0xFFF8BF13),
        foregroundColor: Colors.black,
      ),
      backgroundColor: const Color(0xFFF9FAFB),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatus,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF8BF13)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Votre plan actuel',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          status?.currentPlanLabel ?? 'Inconnu',
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF0461B6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (status?.freeTrialActive == true)
                          Text(
                            'Jours restants (Decouverte): ${status?.freeTrialRemainingDays ?? 0}',
                          ),
                        Text(
                          'Essai gratuit jusqu\'au: ${_formatDate(status?.freeTrialEndsAt)}',
                        ),
                        Text(
                          'Plan payant jusqu\'au: ${_formatDate(status?.paidPlanEndsAt)}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Plan Decouverte',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '3 mois gratuits apres inscription. Publiez vos articles sans paiement.',
                        ),
                        const SizedBox(height: 14),
                        const Divider(),
                        const SizedBox(height: 14),
                        const Text(
                          'Plan Pro Mensuel',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${status?.monthlyPriceFcfa ?? 5000} FCFA / mois',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB45309),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _openMonthPicker,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFF8BF13),
                                  ),
                                ),
                                child: Text(
                                  'Duree: $_selectedMonths mois',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total: ${(_selectedMonths * (status?.monthlyPriceFcfa ?? 5000))} FCFA',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0461B6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('Options incluses:'),
                        const SizedBox(height: 4),
                        const Text('- Publication illimitee des articles'),
                        const Text('- Acces prioritaire aux mises en avant'),
                        const Text('- Renouvellement mensuel'),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _subscribing ? null : _subscribe,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF8BF13),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _subscribing
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Text(
                                    'Passer au Plan Pro',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Historique abonnement (10 derniers)',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_subscriptionHistory.isEmpty)
                          const Text(
                            'Aucun paiement d\'abonnement pour le moment.',
                            style: TextStyle(color: Colors.grey),
                          )
                        else
                          ..._subscriptionHistory.map((tx) {
                            final amount = tx['amount']?.toString() ?? '--';
                            final status = tx['status']?.toString() ?? '--';
                            final createdAt = _formatDateShort(tx['createdAt']);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFEDEDED),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.receipt_long,
                                    color: Color(0xFFF8BF13),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '$amount FCFA - $status',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    createdAt,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
