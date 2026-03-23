import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

/// Carte gratuite OpenStreetMap (Flutter Map) pour affichage + bouton "Naviguer"
/// vers Google Maps / Waze pour la navigation voix.
class OsmMapWidget extends StatelessWidget {
  final LatLng center;
  final double zoom;
  final List<OsmMarkerData> markers;
  final List<LatLng>? polylinePoints;
  final VoidCallback? onTapMyLocation;
  final LatLng? navigateToDestination;

  const OsmMapWidget({
    super.key,
    required this.center,
    this.zoom = 14,
    this.markers = const [],
    this.polylinePoints,
    this.onTapMyLocation,
    this.navigateToDestination,
  });

  /// Ouvre Google Maps ou Waze pour la navigation vers [destination].
  /// [destination] ex: LatLng(14.716677, -17.467686)
  static Future<void> openNavigation(LatLng destination,
      {bool useWaze = false}) async {
    final lat = destination.latitude;
    final lng = destination.longitude;
    if (useWaze) {
      final waze = Uri.parse('https://waze.com/ul?ll=$lat,$lng&navigate=yes');
      try {
        await launchUrl(waze, mode: LaunchMode.externalApplication);
      } catch (_) {}
      return;
    }

    // Essayer d'abord le schéma "navigation" (ouvre directement Google Maps en mode guidage sur Android),
    // puis fallback web si indisponible.
    final googleNav = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    try {
      final ok = await launchUrl(googleNav, mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (_) {}

    final web = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    try {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: zoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.tranoo.tranoo_pro',
            ),
            if (polylinePoints != null && polylinePoints!.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: polylinePoints!,
                    // Cohérent avec la légende "Itinéraire" (jaune)
                    color: const Color(0xFFF8BF13),
                    strokeWidth: 4.5,
                  ),
                ],
              ),
            MarkerLayer(
              markers: markers
                  .map(
                    (m) => Marker(
                      point: m.point,
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: m.onTap,
                        child: Icon(
                          m.iconData ?? Icons.place,
                          color: m.color ?? Colors.blue,
                          size: 40,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        if (onTapMyLocation != null)
          Positioned(
            right: 16,
            bottom: 100,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(8),
              child: IconButton(
                icon: const Icon(Icons.my_location),
                onPressed: onTapMyLocation,
              ),
            ),
          ),
        if (navigateToDestination != null)
          Positioned(
            right: 16,
            bottom: 40,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              child: InkWell(
                onTap: () => openNavigation(navigateToDestination!),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Naviguer',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class OsmMarkerData {
  final LatLng point;
  final IconData? iconData;
  final Color? color;
  final VoidCallback? onTap;

  OsmMarkerData({required this.point, this.iconData, this.color, this.onTap});
}

/// Convertit les coordonnées [Position] (geolocator) en [LatLng] (latlong2).
LatLng positionToLatLng(Position p) => LatLng(p.latitude, p.longitude);

/// Crée un [LatLng] depuis un map (ex: lieuDepart / lieuDestination).
LatLng? latLngFromMap(Map<String, dynamic>? place) {
  if (place == null) return null;
  final rawLat = place['latitude'] ?? place['lat'];
  final rawLng = place['longitude'] ?? place['lng'] ?? place['lon'];
  if (rawLat == null || rawLng == null) return null;

  final lat = (rawLat is num) ? rawLat.toDouble() : double.tryParse(rawLat.toString());
  final lng = (rawLng is num) ? rawLng.toDouble() : double.tryParse(rawLng.toString());
  if (lat == null || lng == null) return null;
  return LatLng(lat, lng);
}
