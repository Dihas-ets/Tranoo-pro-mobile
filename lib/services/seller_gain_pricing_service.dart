import 'package:dio/dio.dart';
import 'package:tranoo_pro/services/user_service.dart';
import 'package:tranoo_pro/utils/amount_display.dart';

class SellerGainCarTier {
  final int minPrice;
  final int gain;

  const SellerGainCarTier({required this.minPrice, required this.gain});

  factory SellerGainCarTier.fromJson(Map<String, dynamic> json) {
    return SellerGainCarTier(
      minPrice: int.tryParse(json['minPrice']?.toString() ?? '') ?? 0,
      gain: int.tryParse(json['gain']?.toString() ?? '') ?? 0,
    );
  }
}

class SellerGainPricingConfig {
  final List<SellerGainCarTier> carTiers;
  final int motoNeuveGain;
  final int motoTricycleGain;
  final int motoPercentFrom;
  final double motoPercentRate;

  const SellerGainPricingConfig({
    required this.carTiers,
    required this.motoNeuveGain,
    required this.motoTricycleGain,
    required this.motoPercentFrom,
    required this.motoPercentRate,
  });

  static const defaults = SellerGainPricingConfig(
    carTiers: [
      SellerGainCarTier(minPrice: 5500000, gain: 200000),
      SellerGainCarTier(minPrice: 2500000, gain: 100000),
      SellerGainCarTier(minPrice: 1500000, gain: 50000),
    ],
    motoNeuveGain: 5000,
    motoTricycleGain: 10000,
    motoPercentFrom: 1500000,
    motoPercentRate: 10,
  );

  factory SellerGainPricingConfig.fromApi(Map<String, dynamic> data) {
    final rawTiers = data['carTiers'];
    final tiers = <SellerGainCarTier>[];
    if (rawTiers is List) {
      for (final item in rawTiers) {
        if (item is Map) {
          final tier = SellerGainCarTier.fromJson(Map<String, dynamic>.from(item));
          if (tier.minPrice > 0 && tier.gain >= 0) tiers.add(tier);
        }
      }
    }
    tiers.sort((a, b) => b.minPrice.compareTo(a.minPrice));

    return SellerGainPricingConfig(
      carTiers: tiers.isEmpty ? defaults.carTiers : tiers,
      motoNeuveGain: _int(data['motoNeuveGain'], defaults.motoNeuveGain),
      motoTricycleGain: _int(data['motoTricycleGain'], defaults.motoTricycleGain),
      motoPercentFrom: _int(data['motoPercentFrom'], defaults.motoPercentFrom),
      motoPercentRate: _double(data['motoPercentRate'], defaults.motoPercentRate),
    );
  }

  static int _int(Object? raw, int fallback) {
    final parsed = int.tryParse(raw?.toString() ?? '');
    return parsed ?? fallback;
  }

  static double _double(Object? raw, double fallback) {
    final parsed = double.tryParse(raw?.toString() ?? '');
    return parsed ?? fallback;
  }
}

/// Calcul du prélèvement Tranoo sur le prix de vente (FCFA).
class SellerGainPricingService {
  static SellerGainPricingConfig _config = SellerGainPricingConfig.defaults;

  static SellerGainPricingConfig get config => _config;

  static Future<void> refreshFromApi() async {
    try {
      final dio = UserService().dio;
      final response = await dio.get('/admin/seller-gain-pricing');
      final data = response.data;
      if (data is Map) {
        _config = SellerGainPricingConfig.fromApi(Map<String, dynamic>.from(data));
      }
    } on DioException catch (_) {
      // Fallback silencieux.
    } catch (_) {}
  }

  static int computeCarGainFcfa(double price) {
    if (price <= 0) return 0;
    for (final tier in _config.carTiers) {
      if (price >= tier.minPrice) return tier.gain;
    }
    return _config.carTiers.isNotEmpty
        ? _config.carTiers.last.gain
        : SellerGainPricingConfig.defaults.carTiers.last.gain;
  }

  static int computeMotoGainFcfa(
    double price, {
    String? typeMoto,
  }) {
    if (price <= 0) return 0;
    if (price >= _config.motoPercentFrom && _config.motoPercentRate > 0) {
      return (price * (_config.motoPercentRate / 100)).round();
    }
    final type = (typeMoto ?? '').trim().toLowerCase();
    if (type == 'tricycle') return _config.motoTricycleGain;
    return _config.motoNeuveGain;
  }

  static String describeCarGainRule(double price) {
    final gain = computeCarGainFcfa(price);
    if (price >= 5500000) {
      return 'Palier 5,5 M+ : Tranoo prélève ${formatFcfaDots(gain.toString())} FCFA.';
    }
    if (price >= 2500000) {
      return 'Palier 2,5 M – 5 M : Tranoo prélève ${formatFcfaDots(gain.toString())} FCFA.';
    }
    if (price >= 1500000) {
      return 'Palier 1,5 M – 2 M : Tranoo prélève ${formatFcfaDots(gain.toString())} FCFA.';
    }
    return 'Tranoo prélève ${formatFcfaDots(gain.toString())} FCFA (palier minimum).';
  }

  static String describeMotoGainRule(
    double price, {
    String? typeMoto,
  }) {
    final gain = computeMotoGainFcfa(price, typeMoto: typeMoto);
    if (price >= _config.motoPercentFrom && _config.motoPercentRate > 0) {
      return 'À partir de ${formatFcfaDots(_config.motoPercentFrom.toString())} FCFA : '
          '${_config.motoPercentRate.toStringAsFixed(_config.motoPercentRate == _config.motoPercentRate.roundToDouble() ? 0 : 1)} % '
          'soit ${formatFcfaDots(gain.toString())} FCFA pour Tranoo.';
    }
    final type = (typeMoto ?? '').trim().toLowerCase();
    if (type == 'tricycle') {
      return 'Tricycle neuf : Tranoo prélève ${formatFcfaDots(gain.toString())} FCFA.';
    }
    return 'Moto neuve : Tranoo prélève ${formatFcfaDots(gain.toString())} FCFA.';
  }
}
