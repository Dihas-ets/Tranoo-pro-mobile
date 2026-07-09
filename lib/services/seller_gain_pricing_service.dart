import 'package:dio/dio.dart';
import 'package:tranoo_pro/services/user_service.dart';

enum SellerVehicleType { car, moto }

class SellerGainPricingService {
  static const int defaultGainVoiture = 100000;
  static const int defaultGainMoto = 50000;

  static Future<int> fetchGainForVehicle(SellerVehicleType type) async {
    try {
      final dio = UserService().dio;
      final response = await dio.get('/admin/seller-gain-pricing');
      final data = response.data;
      if (data is! Map) {
        return _fallback(type);
      }
      final map = Map<String, dynamic>.from(data);
      final pricing = map['pricing'] is Map
          ? Map<String, dynamic>.from(map['pricing'] as Map)
          : map;
      final raw = type == SellerVehicleType.moto
          ? (pricing['gainMoto'] ?? map['gainMoto'])
          : (pricing['gainVoiture'] ?? map['gainVoiture']);
      final parsed = int.tryParse(raw?.toString() ?? '');
      if (parsed != null && parsed >= 0) return parsed;
    } on DioException catch (_) {
      // Fallback silencieux si l'API est indisponible.
    } catch (_) {}
    return _fallback(type);
  }

  static int _fallback(SellerVehicleType type) {
    return type == SellerVehicleType.moto
        ? defaultGainMoto
        : defaultGainVoiture;
  }
}
