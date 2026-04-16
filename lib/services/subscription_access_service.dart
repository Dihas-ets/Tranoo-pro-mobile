import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  Future<SellerAccessStatus> getSellerAccessStatus({
    DateTime? inscriptionDate,
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
          final subResponse = await dio.get('/subscription/me');
          final data = subResponse.data as Map<String, dynamic>;
          paidPlanActive = data['hasSubscription'] == true;
          currentMonths = (data['months'] as num?)?.toInt() ?? 1;
          if (data['expiresAt'] != null) {
            paidPlanEndsAt = DateTime.tryParse(data['expiresAt'].toString());
          }
          monthlyPrice = (data['monthlyPrice'] as num?)?.toInt() ?? monthlyPrice;
        } catch (_) {}
      }(),
      () async {
        try {
          final pricingResponse = await dio.get('/admin/subscription-pricing');
          final data = pricingResponse.data as Map<String, dynamic>;
          monthlyPrice = (data['prixMensuel'] as num?)?.toInt() ?? monthlyPrice;
        } catch (_) {}
      }(),
    ];

    await Future.wait(futures);

    final trialStartDate = inscriptionDate;
    if (trialStartDate != null) {
      freeTrialEndsAt = trialStartDate.add(const Duration(days: 90));
      freeTrialActive = DateTime.now().isBefore(freeTrialEndsAt);
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
