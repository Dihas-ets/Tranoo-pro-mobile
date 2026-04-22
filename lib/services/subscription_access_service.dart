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

  const SellerAccessStatus({
    required this.freeTrialActive,
    required this.paidPlanActive,
    required this.freeTrialEndsAt,
    required this.paidPlanEndsAt,
    required this.monthlyPriceFcfa,
    required this.currentSubscriptionMonths,
  });

  bool get canCreateArticle => freeTrialActive || paidPlanActive;

  String get currentPlanLabel {
    if (paidPlanActive) return 'Plan Pro Mensuel';
    if (freeTrialActive) return 'Plan Decouverte (3 mois gratuits)';
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

  int _extractMonthlyPrice(dynamic data, {int fallback = 5000}) {
    if (data is Map<String, dynamic>) {
      final directPrix = data['prixMensuel'];
      if (directPrix is num) return directPrix.toInt();

      final directMonthly = data['monthlyPrice'];
      if (directMonthly is num) return directMonthly.toInt();

      final nestedPricing = data['pricing'];
      if (nestedPricing is Map<String, dynamic>) {
        final nestedPrix = nestedPricing['prixMensuel'];
        if (nestedPrix is num) return nestedPrix.toInt();
      }
    }
    return fallback;
  }

  Future<SellerAccessStatus> getSellerAccessStatus({
    DateTime? inscriptionDateOverride,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SellerAccessStatus(
        freeTrialActive: false,
        paidPlanActive: false,
        freeTrialEndsAt: null,
        paidPlanEndsAt: null,
        monthlyPriceFcfa: 5000,
        currentSubscriptionMonths: 1,
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
    int monthlyPrice = 5000;
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
          developer.log(
            '[SUB_ACCESS] GET /admin/subscription-pricing baseUrl=${_userService.dio.options.baseUrl}',
          );
          final pricingResponse = await dio.get('/admin/subscription-pricing');
          developer.log('[SUB_ACCESS] /admin/subscription-pricing status=${pricingResponse.statusCode} data=${pricingResponse.data}');
          final data = pricingResponse.data is Map<String, dynamic>
              ? pricingResponse.data as Map<String, dynamic>
              : <String, dynamic>{};
          monthlyPrice = _extractMonthlyPrice(data, fallback: monthlyPrice);
        } catch (e) {
          developer.log('[SUB_ACCESS] /admin/subscription-pricing error=$e');
        }
      }(),
    ];

    await Future.wait(futures);

    final trialStartDate = inscriptionDateOverride ?? inscriptionDate;
    if (trialStartDate != null) {
      freeTrialEndsAt = trialStartDate.add(const Duration(days: 90));
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
      queryParameters: {'type': 'Abonnement', 'limit': limit},
    );

    final data = response.data;
    if (data is Map<String, dynamic> && data['transactions'] is List) {
      return List<Map<String, dynamic>>.from(
        (data['transactions'] as List).whereType<Map>(),
      );
    }
    return [];
  }
}
