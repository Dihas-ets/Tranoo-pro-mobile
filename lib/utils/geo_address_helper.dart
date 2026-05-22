import 'package:dio/dio.dart';

class GeoAddressResult {
  final String address;
  final String city;

  const GeoAddressResult({required this.address, required this.city});
}

Future<GeoAddressResult> reverseGeocode(double lat, double lng) async {
  try {
    final response = await Dio().get(
      'https://nominatim.openstreetmap.org/reverse',
      queryParameters: {
        'format': 'json',
        'lat': lat,
        'lon': lng,
        'zoom': 18,
        'addressdetails': 1,
      },
      options: Options(headers: {'User-Agent': 'TranooPro/1.0'}),
    );
    if (response.statusCode == 200 && response.data is Map) {
      final data = response.data as Map<String, dynamic>;
      final address = (data['display_name'] ?? '').toString();
      final addr = data['address'];
      String city = '';
      if (addr is Map) {
        city =
            (addr['city'] ?? addr['town'] ?? addr['village'] ?? '').toString();
      }
      return GeoAddressResult(address: address, city: city);
    }
  } catch (_) {}
  return const GeoAddressResult(address: '', city: '');
}
