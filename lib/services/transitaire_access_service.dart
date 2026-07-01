import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tranoo_pro/services/user_service.dart';

enum TransitaireGate {
  verificationRequired,
  verificationPending,
  verificationRejected,
  subscriptionRequired,
  subscriptionExpired,
  fullAccess,
}

class TransitaireVerificationInfo {
  final String statut;
  final String? carteRectoUrl;
  final String? carteVersoUrl;
  final String? entrepriseProvenanceNom;
  final String? entrepriseProvenanceReference;
  final String? rejectionMotif;
  final DateTime? submittedAt;

  const TransitaireVerificationInfo({
    required this.statut,
    this.carteRectoUrl,
    this.carteVersoUrl,
    this.entrepriseProvenanceNom,
    this.entrepriseProvenanceReference,
    this.rejectionMotif,
    this.submittedAt,
  });

  factory TransitaireVerificationInfo.fromJson(Map<String, dynamic> json) {
    DateTime? submitted;
    final raw = json['submittedAt'];
    if (raw != null) submitted = DateTime.tryParse(raw.toString());

    return TransitaireVerificationInfo(
      statut: (json['statut'] ?? 'none').toString(),
      carteRectoUrl: json['carteRectoUrl']?.toString(),
      carteVersoUrl: json['carteVersoUrl']?.toString(),
      entrepriseProvenanceNom: json['entrepriseProvenanceNom']?.toString(),
      entrepriseProvenanceReference:
          json['entrepriseProvenanceReference']?.toString(),
      rejectionMotif: json['rejectionMotif']?.toString(),
      submittedAt: submitted,
    );
  }
}

class TransitaireAccessState {
  final TransitaireGate gate;
  final TransitaireVerificationInfo verification;
  final bool hasActiveSubscription;

  const TransitaireAccessState({
    required this.gate,
    required this.verification,
    required this.hasActiveSubscription,
  });

  bool get needsVerificationBlock =>
      gate == TransitaireGate.verificationRequired ||
      gate == TransitaireGate.verificationPending ||
      gate == TransitaireGate.verificationRejected;

  bool get needsSubscriptionBlock =>
      gate == TransitaireGate.subscriptionRequired ||
      gate == TransitaireGate.subscriptionExpired;

  bool get subscriptionExpiredRedirect =>
      gate == TransitaireGate.subscriptionExpired;

  factory TransitaireAccessState.fromJson(Map<String, dynamic> json) {
    final gateRaw = (json['gate'] ?? 'full_access').toString();
    final gate = switch (gateRaw) {
      'verification_required' => TransitaireGate.verificationRequired,
      'verification_pending' => TransitaireGate.verificationPending,
      'verification_rejected' => TransitaireGate.verificationRejected,
      'subscription_required' => TransitaireGate.subscriptionRequired,
      'subscription_expired' => TransitaireGate.subscriptionExpired,
      _ => TransitaireGate.fullAccess,
    };
    final verificationJson = json['verification'] is Map<String, dynamic>
        ? json['verification'] as Map<String, dynamic>
        : <String, dynamic>{};
    return TransitaireAccessState(
      gate: gate,
      verification: TransitaireVerificationInfo.fromJson(verificationJson),
      hasActiveSubscription: json['hasActiveSubscription'] == true,
    );
  }
}

class TransitaireAccessService {
  final UserService _userService = UserService();

  Future<Dio> _authedDio() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = user != null ? await user.getIdToken() : null;
    return Dio(
      BaseOptions(
        baseUrl: _userService.dio.options.baseUrl,
        headers: {
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  Future<TransitaireAccessState> fetchAccessState() async {
    final dio = await _authedDio();
    final response = await dio.get('/transitaires/verification/status');
    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
    return TransitaireAccessState.fromJson(data);
  }

  Future<TransitaireAccessState> submitVerification({
    required String carteRectoUrl,
    required String carteVersoUrl,
    required String entrepriseProvenanceNom,
    required String entrepriseProvenanceReference,
  }) async {
    final dio = await _authedDio();
    final response = await dio.post(
      '/transitaires/verification/submit',
      data: {
        'carteRectoUrl': carteRectoUrl,
        'carteVersoUrl': carteVersoUrl,
        'entrepriseProvenanceNom': entrepriseProvenanceNom,
        'entrepriseProvenanceReference': entrepriseProvenanceReference,
      },
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return TransitaireAccessState.fromJson(data);
    }
    if (data is Map) {
      return TransitaireAccessState.fromJson(
        Map<String, dynamic>.from(data),
      );
    }
    return fetchAccessState();
  }

  Future<Map<String, dynamic>> fetchUserProfile() async {
    final dio = await _authedDio();
    final response = await dio.get('/protected/me');
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }
}
