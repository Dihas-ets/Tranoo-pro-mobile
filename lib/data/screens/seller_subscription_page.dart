import 'package:flutter/material.dart';
import 'package:feexpay_flutter/feexpay_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:random_string/random_string.dart';
import 'package:dio/dio.dart';
import 'package:tranoo_pro/services/user_service.dart';
import 'package:tranoo_pro/services/subscription_access_service.dart';
import 'package:tranoo_pro/data/screens/avant_home.dart';
import 'package:tranoo_pro/utils/feexpay_result_utils.dart';
import 'package:tranoo_pro/utils/feexpay_callback_state.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';

class SellerSubscriptionPage extends StatefulWidget {
  final bool forTransitaire;
  final bool blockerMode;
  final VoidCallback? onSubscriptionChanged;

  const SellerSubscriptionPage({
    super.key,
    this.forTransitaire = false,
    this.blockerMode = false,
    this.onSubscriptionChanged,
  });

  @override
  State<SellerSubscriptionPage> createState() => _SellerSubscriptionPageState();
}

class _SellerSubscriptionPageState extends State<SellerSubscriptionPage> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

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
      final status = await _subscriptionService.getSellerAccessStatus(
        forTransitaire: widget.forTransitaire,
      );
      if (!mounted) return;
      setState(() {
        _status = status;
      });

      // L'historique est non bloquant: en cas d'erreur, on garde quand même
      // les infos d'abonnement (prix/mois/essai) affichées à l'écran.
      try {
        final history =
            await _subscriptionService.getSubscriptionHistory(limit: 10);
        if (!mounted) return;
        setState(() {
          _subscriptionHistory = history;
        });
      } catch (e) {
        if (!mounted) return;
        debugPrint('[SUB_PAGE] historique indisponible: $e');
      }
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

  Future<void> _subscribe() async {
    setState(() {
      _subscribing = true;
      _error = null;
    });
    try {
      if (_fpToken.isEmpty || _fpShopId.isEmpty) {
        throw Exception('Configuration FeexPay manquante');
      }

      final monthlyPrice = _status?.monthlyPriceFcfa ?? 0;
      final total = _selectedMonths * monthlyPrice;
      final remainingDays =
          _status?.paidPlanEndsAt?.difference(DateTime.now()).inDays;
      final hasDiscount = _status != null &&
          _status!.paidPlanActive &&
          _status!.currentSubscriptionMonths >= 6 &&
          remainingDays != null &&
          remainingDays >= 0 &&
          remainingDays <= 10;
      final amount = (hasDiscount ? (total * 0.9) : total).toStringAsFixed(0);
      final transKey = randomAlphaNumeric(15);

      FeexPayCallbackState.clearPendingAtNewCheckout();
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

      final user = FirebaseAuth.instance.currentUser;
      final idToken = await user?.getIdToken();
      if (idToken == null) {
        throw Exception('Utilisateur non connecté');
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

      final cb = FeexPayCallbackState.takeLatest();
      final callbackHint = result is Map && result['successHint'] == true;
      String? feexId = extractFeexPayTransactionId(result) ?? cb.transactionId;
      bool isSuccess = feexPayReturnIndicatesSuccess(result) ||
          cb.success == true ||
          callbackHint;
      if (feexId != null && feexId.isNotEmpty) {
        try {
          final st = await dio.get('/payments/feexpay/public/status/$feexId');
          if (st.statusCode == 200 && st.data is Map) {
            final s = (st.data['status'] ?? '').toString().toLowerCase();
            final verified = s.contains('success') ||
                s.contains('successful') ||
                s.contains('paid') ||
                s.contains('ok') ||
                s.contains('completed') ||
                s.contains('approved');
            isSuccess = isSuccess || verified;
          }
        } catch (_) {}
      }

      if (!isSuccess) {
        return;
      }

      await dio.post(
        '/payments/feexpay/flutter/record',
        data: {
          'transKey': transKey,
          'amount': num.parse(amount),
          'description': widget.forTransitaire
              ? 'Paiement abonnement transitaire ($_selectedMonths mois)'
              : 'Paiement abonnement vendeur ($_selectedMonths mois)',
          'type': 'subscription',
          'status': 'success',
          'duree': '$_selectedMonths mois',
          if (feexId != null && feexId.isNotEmpty) 'id_transaction': feexId,
          if (feexId != null && feexId.isNotEmpty) 'ref': feexId,
          if (feexId != null && feexId.isNotEmpty) 'reference': feexId,
        },
      );

      await _subscriptionService.activateMonthlySubscription(
        months: _selectedMonths,
      );
      await _loadStatus();
      widget.onSubscriptionChanged?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.subscriptionPaymentSuccess),
          backgroundColor: Colors.green,
        ),
      );
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      if (widget.blockerMode) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AvantHome()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erreur lors de l\'activation de l\'abonnement.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.subscriptionPaymentFailed),
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
    final months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatDateShort(dynamic raw) {
    if (raw == null) return '--';
    final dt = DateTime.tryParse(raw.toString());
    if (dt == null) return '--';
    final months = [
      'janv', 'févr', 'mars', 'avr', 'mai', 'juin',
      'juil', 'août', 'sept', 'oct', 'nov', 'déc'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final status = _status;
    final monthlyPrice = status?.monthlyPriceFcfa ?? 0;
    final totalPrice = _selectedMonths * monthlyPrice;
    final remainingDays = status?.paidPlanEndsAt?.difference(DateTime.now()).inDays;
    final hasDiscount = status != null &&
        status.paidPlanActive &&
        status.currentSubscriptionMonths >= 6 &&
        remainingDays != null &&
        remainingDays >= 0 &&
        remainingDays <= 10;
    final discountedPrice = hasDiscount ? totalPrice * 0.9 : totalPrice;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: widget.blockerMode
          ? AppBar(
              backgroundColor: const Color(0xFF1B2B4B),
              foregroundColor: Colors.white,
              automaticallyImplyLeading: false,
              centerTitle: true,
              title: Text(
                widget.forTransitaire
                    ? AppLocalizations.of(context)!
                        .transitaireSubscriptionBlockerTitle
                    : l10n.sellerSubscription,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadStatus,
              color: Colors.amber,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Carte du plan actuel
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.shade200, width: 1),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.stars,
                                color: Colors.amber.shade700,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Plan actuel',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          status?.planLabel(
                                forTransitaire: widget.forTransitaire,
                              ) ??
                              'Inconnu',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (!widget.forTransitaire &&
                            status?.freeTrialActive == true)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.local_fire_department,
                                  color: Colors.amber.shade700,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Essai gratuit : ${status?.freeTrialRemainingDays ?? 0} jours restants',
                                  style: TextStyle(
                                    color: Colors.amber.shade800,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (!widget.forTransitaire) ...[
                          const SizedBox(height: 12),
                          _buildInfoRow(
                            icon: Icons.calendar_today,
                            label: 'Fin de l\'essai gratuit',
                            value: _formatDate(status?.freeTrialEndsAt),
                          ),
                        ],
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          icon: Icons.verified,
                          label: 'Fin du plan payant',
                          value: _formatDate(status?.paidPlanEndsAt),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Carte Plan Pro
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // En-tête
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Plan Pro',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Boostez votre activité',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade500,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'POPULAIRE',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${monthlyPrice.toString()}',
                                    style: const TextStyle(
                                      fontSize: 38,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const Text(
                                    ' FCFA',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    '/ mois',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Contenu
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Sélecteur de durée
                              const Text(
                                'Durée d\'abonnement',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_month,
                                      color: Colors.amber.shade700,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        '$_selectedMonths mois',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        InkWell(
                                          onTap: () {
                                            setState(() {
                                              _selectedMonths =
                                                  (_selectedMonths + 1).clamp(1, 12);
                                            });
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.all(4),
                                            child: Icon(
                                              Icons.keyboard_arrow_up,
                                              size: 22,
                                            ),
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () {
                                            setState(() {
                                              _selectedMonths =
                                                  (_selectedMonths - 1).clamp(1, 12);
                                            });
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.all(4),
                                            child: Icon(
                                              Icons.keyboard_arrow_down,
                                              size: 22,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),

                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: hasDiscount
                                      ? const Color(0xFFE8F5E9)
                                      : const Color(0xFFE8F1FF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: hasDiscount
                                        ? const Color(0xFFB7E1C1)
                                        : const Color(0xFFB7D0FF),
                                  ),
                                ),
                                child: Text(
                                  hasDiscount
                                      ? 'Bravo! Vous êtes éligible à -10%: votre abonnement de 6 mois arrive à expiration et vous renouvelez à temps.'
                                      : 'Réduction fidélité: disponible uniquement avec un abonnement de 6 mois, proche de l\'expiration, et renouvelé avant la date de fin.',
                                  style: TextStyle(
                                    color: hasDiscount
                                        ? const Color(0xFF1B5E20)
                                        : const Color(0xFF0B3D91),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Total
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(l10n.total,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          '${totalPrice.toString()} FCFA',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: hasDiscount
                                                ? Colors.grey.shade500
                                                : Colors.black87,
                                            decoration: hasDiscount
                                                ? TextDecoration.lineThrough
                                                : TextDecoration.none,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (hasDiscount) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Économie fidélité (10%)',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.green,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            '- ${(totalPrice - discountedPrice).toStringAsFixed(0)} FCFA',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    const Divider(),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'À payer',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          '${discountedPrice.toStringAsFixed(0)} FCFA',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Avantages
                              const Text(
                                'Ce que vous obtenez',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildBenefitItem(
                                icon: Icons.auto_awesome,
                                text: 'Publications illimitées',
                              ),
                              const SizedBox(height: 10),
                              _buildBenefitItem(
                                icon: Icons.trending_up,
                                text: 'Accès prioritaire aux mises en avant',
                              ),
                              const SizedBox(height: 10),
                              _buildBenefitItem(
                                icon: Icons.autorenew,
                                text: 'Renouvellement mensuel automatique',
                              ),
                              const SizedBox(height: 10),
                              _buildBenefitItem(
                                icon: Icons.support_agent,
                                text: 'Support prioritaire 24/7',
                              ),

                              const SizedBox(height: 24),

                              // Bouton d'action
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _subscribing ? null : _subscribe,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber.shade500,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _subscribing
                                      ? const SizedBox(
                                          height: 22,
                                          width: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.rocket_launch),
                                            SizedBox(width: 8),
                                            Text(
                                              'Activer le Plan Pro',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),

                              if (_error != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.red.shade200,
                                    ),
                                  ),
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Historique
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Icon(
                                Icons.history,
                                color: Colors.amber,
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Historique des paiements',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_subscriptionHistory.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(18),
                            child: Center(
                              child: Text(
                                'Aucun paiement d\'abonnement',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _subscriptionHistory.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                            ),
                            itemBuilder: (context, index) {
                              final tx = _subscriptionHistory[index];
                              final amount = tx['amount']?.toString() ?? '--';
                              final statusTx = tx['status']?.toString() ?? '--';
                              final createdAt =
                                  _formatDateShort(tx['createdAt']);
                              final isSuccess =
                                  statusTx.toLowerCase().contains('success') ||
                                  statusTx.toLowerCase().contains('paid');

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: isSuccess
                                            ? Colors.green.shade50
                                            : Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        isSuccess
                                            ? Icons.check_circle
                                            : Icons.error_outline,
                                        size: 18,
                                        color: isSuccess
                                            ? Colors.green.shade600
                                            : Colors.red.shade600,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$amount FCFA',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            statusTx,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isSuccess
                                                  ? Colors.green.shade600
                                                  : Colors.red.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      createdAt,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitItem({
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: Colors.amber.shade700,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ),
      ],
    );
  }
}