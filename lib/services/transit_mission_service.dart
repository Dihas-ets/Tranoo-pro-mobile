import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tranoo_pro/services/user_service.dart';

class TransitMissionService {
  TransitMissionService._();
  static final TransitMissionService instance = TransitMissionService._();

  Dio get _dio => UserService().dio;

  Future<Map<String, String>> _headers() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> listMissions(String statut) async {
    try {
      final resp = await _dio.get(
        '/transit-missions/mes-missions',
        queryParameters: {'statut': statut},
        options: Options(headers: await _headers()),
      );
      final data = resp.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Map<String, dynamic>>> listAllMissions() async {
    try {
      final resp = await _dio.get(
        '/transit-missions/acceptes',
        options: Options(headers: await _headers()),
      );
      final data = resp.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>?> updateMissionDetails({
    required String missionId,
    String? paysDestination,
    String? detailsSupplementaires,
  }) async {
    try {
      final resp = await _dio.patch(
        '/transit-missions/$missionId/details',
        data: {
          if (paysDestination != null) 'paysDestination': paysDestination,
          if (detailsSupplementaires != null)
            'detailsSupplementaires': detailsSupplementaires,
        },
        options: Options(headers: await _headers()),
      );
      if (resp.statusCode == 200 && resp.data is Map) {
        return Map<String, dynamic>.from(resp.data);
      }
    } catch (_) {}
    return null;
  }

  Future<({bool ok, String? error})> rejeterAttribution(String missionId) async {
    try {
      final resp = await _dio.patch(
        '/transit-missions/$missionId/rejeter-attribution',
        options: Options(headers: await _headers()),
      );
      if (resp.statusCode == 200) {
        return (ok: true, error: null);
      }
      final data = resp.data;
      final msg = data is Map ? data['message']?.toString() : null;
      return (ok: false, error: msg ?? 'Impossible de refuser la mission');
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data is Map ? data['message']?.toString() : null;
      return (ok: false, error: msg ?? 'Impossible de refuser la mission');
    } catch (_) {
      return (ok: false, error: 'Impossible de refuser la mission');
    }
  }

  Future<bool> marquerTraite(String missionId) async {
    try {
      final resp = await _dio.patch(
        '/transit-missions/$missionId/marquer-traite',
        options: Options(headers: await _headers()),
      );
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
