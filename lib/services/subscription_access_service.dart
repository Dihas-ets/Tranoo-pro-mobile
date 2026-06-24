import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;
import 'package:tranoo_pro/services/user_service.dart';

class SellerAccessStatus {
  final bool freeTrialActive;
  final bool paidPlanActive;
  final DateTime? freeTrialEndsAt;
  final DateTime? paidPlanEndsAt;
  final int monthlyPriceFcfa;
  final int currentSubscriptionMonths;
  final int freeTrialDays;

  const SellerAccessStatus({
    required this.freeTrialActive,
    required this.paidPlanActive,
    required this.freeTrialEndsAt,
    required this.paidPlanEndsAt,
    required this.monthlyPriceFcfa,
    required this.currentSubscriptionMonths,
    required this.freeTrialDays,
  });

  bool get canCreateArticle => freeTrialActive || paidPlanActive;

  String get currentPlanLabel {
    if (paidPlanActive) return 'Plan Pro Mensuel';
    if (freeTrialActive) return 'Plan Decouverte (45 jours gratuits)';
    return 'Aucun plan actif';
  }

  int get freeTrialRemainingDays {
    if (!freeTrialActive || freeTrialEndsAt == null) return 0;
    final days = freeTrialEndsAt!.difference(DateTime.now()).inDays;
    return days < 0 ? 0 : days;
  }

  int get paidPlanRemainingDays {
    if (!paidPlanActive || paidPlanEndsAt == null) return 0;
    final days = paidPlanEndsAt!.difference(DateTime.now()).inDays;
    return days < 0 ? 0 : days;
  }

  bool get showExpiryWarning {
    if (paidPlanActive) return paidPlanRemainingDays <= 10;
    if (freeTrialActive) return freeTrialRemainingDays <= 10;
    return false;
  }
}

class SubscriptionAccessService {
  final UserService _userService = UserService();

  int _extractMonthlyPrice(dynamic data, {int fallback = 0}) {
    if (data is Map<String, dynamic>) {
      final directPrix = data['prixMensuel'];
      if (directPrix is num) return directPrix.toInt();
      final directPrixParsed = int.tryParse(directPrix?.toString() ?? '');
      if (directPrixParsed != null) return directPrixParsed;

      final directMonthly = data['monthlyPrice'];
      if (directMonthly is num) return directMonthly.toInt();
      final directMonthlyParsed = int.tryParse(directMonthly?.toString() ?? '');
      if (directMonthlyParsed != null) return directMonthlyParsed;

      final nestedPricing = data['pricing'];
      if (nestedPricing is Map<String, dynamic>) {
        final nestedPrix = nestedPricing['prixMensuel'];
        if (nestedPrix is num) return nestedPrix.toInt();
        final nestedPrixParsed = int.tryParse(nestedPrix?.toString() ?? '');
        if (nestedPrixParsed != null) return nestedPrixParsed;
      }
    }
    return fallback;
  }

  int _extractFreeTrialDays(dynamic data, {int fallback = 45}) {
    if (data is Map<String, dynamic>) {
      final direct = data['freeTrialDays'];
      if (direct is num) return direct.toInt();
      final directParsed = int.tryParse(direct?.toString() ?? '');
      if (directParsed != null) return directParsed;

      final nested = data['pricing'];
      if (nested is Map<String, dynamic>) {
        final nestedValue = nested['freeTrialDays'];
        if (nestedValue is num) return nestedValue.toInt();
        final nestedParsed = int.tryParse(nestedValue?.toString() ?? '');
        if (nestedParsed != null) return nestedParsed;
      }
    }
    return fallback;
  }

  Future<SellerAccessStatus> getSellerAccessStatus({
    DateTime? inscriptionDateOverride,
    bool forTransitaire = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SellerAccessStatus(
        freeTrialActive: false,
        paidPlanActive: false,
        freeTrialEndsAt: null,
        paidPlanEndsAt: null,
        monthlyPriceFcfa: 0,
        currentSubscriptionMonths: 1,
        freeTrialDays: 45,
      );
    }

    final token = await user.getIdToken();
    final dio = Dio(
      BaseOptions(
        baseUrl: _userService.dio.options.baseUrl,
        headers: {
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );

    DateTime? inscriptionDate;
    DateTime? freeTrialEndsAt;
    bool freeTrialActive = false;
    bool paidPlanActive = false;
    DateTime? paidPlanEndsAt;
    int monthlyPrice = 0;
    int freeTrialDays = 45;
    int currentMonths = 1;

    final futures = <Future<void>>[
      () async {
        try {
          developer.log(
            '[SUB_ACCESS] GET /subscription/me baseUrl=${_userService.dio.options.baseUrl}',
          );
          final subResponse = await dio.get('/subscription/me');
          developer.log('[SUB_ACCESS] /subscription/me status=${subResponse.statusCode} data=${subResponse.data}');
          final data = subResponse.data is Map<String, dynamic>
              ? subResponse.data as Map<String, dynamic>
              : <String, dynamic>{};
          paidPlanActive = data['hasSubscription'] == true;
          currentMonths = (data['months'] as num?)?.toInt() ?? 1;
          if (data['expiresAt'] != null) {
            paidPlanEndsAt = DateTime.tryParse(data['expiresAt'].toString());
          }
          monthlyPrice = _extractMonthlyPrice(data, fallback: monthlyPrice);
          developer.log(
            '[SUB_ACCESS] extracted monthlyPrice from /subscription/me => $monthlyPrice',
          );
        } catch (e) {
          developer.log('[SUB_ACCESS] /subscription/me error=$e');
        }
      }(),
      () async {
        try {
          developer.log(
            '[SUB_ACCESS] GET /protected/me baseUrl=${_userService.dio.options.baseUrl}',
          );
          final meResponse = await dio.get('/protected/me');
          developer.log('[SUB_ACCESS] /protected/me status=${meResponse.statusCode} data=${meResponse.data}');
          final payload = meResponse.data is Map<String, dynamic>
              ? meResponse.data as Map<String, dynamic>
              : <String, dynamic>{};
          final userMap = payload['user'] is Map<String, dynamic>
              ? payload['user'] as Map<String, dynamic>
              : <String, dynamic>{};
          final rawInscription = userMap['dateInscription'] ?? userMap['createdAt'];
          if (rawInscription != null) {
            inscriptionDate = DateTime.tryParse(rawInscription.toString());
          }
        } catch (e) {
          developer.log('[SUB_ACCESS] /protected/me error=$e');
        }
      }(),
      () async {
        try {
          final pricingPath = forTransitaire
              ? '/admin/transitaire-subscription-pricing'
              : '/admin/subscription-pricing';
          developer.log(
            '[SUB_ACCESS] GET $pricingPath baseUrl=${_userService.dio.options.baseUrl}',
          );
          final pricingResponse = await dio.get(pricingPath);
          developer.log('[SUB_ACCESS] $pricingPath status=${pricingResponse.statusCode} data=${pricingResponse.data}');
          final data = pricingResponse.data is Map<String, dynamic>
              ? pricingResponse.data as Map<String, dynamic>
              : <String, dynamic>{};
          monthlyPrice = _extractMonthlyPrice(data, fallback: monthlyPrice);
          if (!forTransitaire) {
            freeTrialDays = _extractFreeTrialDays(data, fallback: freeTrialDays);
          }
          developer.log(
            '[SUB_ACCESS] extracted from $pricingPath => monthlyPrice=$monthlyPrice freeTrialDays=$freeTrialDays',
          );
        } catch (e) {
          developer.log('[SUB_ACCESS] pricing fetch error=$e');
        }
      }(),
    ];

    await Future.wait(futures);
    developer.log(
      '[SUB_ACCESS] FINAL RESOLVED => baseUrl=${_userService.dio.options.baseUrl} monthlyPrice=$monthlyPrice freeTrialDays=$freeTrialDays paidPlanActive=$paidPlanActive currentMonths=$currentMonths',
    );

    final trialStartDate = inscriptionDateOverride ?? inscriptionDate;
    if (trialStartDate != null) {
      freeTrialEndsAt = trialStartDate.add(Duration(days: freeTrialDays));
      final now = DateTime.now();
      freeTrialActive = now.isBefore(
        freeTrialEndsAt.add(const Duration(days: 1)),
      );
      developer.log(
        '[SUB_ACCESS] trial start=$trialStartDate end=$freeTrialEndsAt now=$now active=$freeTrialActive',
      );
    } else {
      developer.log('[SUB_ACCESS] Aucune date inscription trouvee');
    }

    return SellerAccessStatus(
      freeTrialActive: freeTrialActive,
      paidPlanActive: paidPlanActive,
      freeTrialEndsAt: freeTrialEndsAt,
      paidPlanEndsAt: paidPlanEndsAt,
      monthlyPriceFcfa: monthlyPrice,
      currentSubscriptionMonths: currentMonths,
      freeTrialDays: freeTrialDays,
    );
  }

  Future<void> activateMonthlySubscription({required int months}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');
    final token = await user.getIdToken();
    final dio = Dio(
      BaseOptions(
        baseUrl: _userService.dio.options.baseUrl,
        headers: {
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );

    await dio.post(
      '/subscription/subscribe',
      data: {'plan': 'monthly', 'months': months},
    );
  }

  Future<List<Map<String, dynamic>>> getSubscriptionHistory({int limit = 20}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final token = await user.getIdToken();
    final dio = Dio(
      BaseOptions(
        baseUrl: _userService.dio.options.baseUrl,
        headers: {
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );

    final response = await dio.get(
      '/payments',
      queryParameters: {
        'type': 'subscription',
        'limit': limit,
      },
    );

    final data = response.data;
    if (data is Map<String, dynamic> && data['transactions'] is List) {
      final list = List<Map<String, dynamic>>.from(
        (data['transactions'] as List).whereType<Map>(),
      );
      developer.log(
        '[SUB_HISTORY] ${list.length} paiement(s) abonnement (limit=$limit)',
        name: 'SubscriptionAccessService',
      );
      return list;
    }
    developer.log(
      '[SUB_HISTORY] réponse inattendue: ${response.statusCode}',
      name: 'SubscriptionAccessService',
    );
    return [];
  }
}
