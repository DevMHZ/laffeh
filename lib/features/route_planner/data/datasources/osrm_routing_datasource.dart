import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/utils/polyline_utils.dart';

/// Routing client backed by **OSRM** (Open Source Routing Machine).
///
/// Uses the public demo server at `router.project-osrm.org`. It
/// follows OpenStreetMap road geometry, requires no API key, and
/// returns an encoded polyline we already know how to decode.
///
/// Rate-limited and unsuitable for production traffic — for a real
/// rollout, self-host OSRM or use GraphHopper / Mapbox / Stadia.
///
/// Request shape:
///   GET /route/v1/{profile}/{lon1,lat1};{lon2,lat2};...?overview=full&geometries=polyline
///
/// Response (subset we care about):
/// ```json
/// {
///   "code": "Ok",
///   "routes": [
///     {
///       "geometry": "...encoded polyline...",
///       "distance": 1234.5,
///       "duration": 678.9
///     }
///   ]
/// }
/// ```
class OsrmRoutingDataSource {
  final Dio _dio;
  const OsrmRoutingDataSource(this._dio);

  Future<OsrmRoute> fetchRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
    String profile = 'driving',
  }) async {
    final coords = [
      origin,
      ...waypoints,
      destination,
    ].map((p) => '${p.longitude},${p.latitude}').join(';');

    final path = '/route/v1/$profile/$coords';

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: const {
          'overview': 'full',
          'geometries': 'polyline',
          'steps': 'false',
          'alternatives': 'false',
        },
      );

      final data = response.data;
      if (data == null) return OsrmRoute.empty;
      if ((data['code']?.toString() ?? '') != 'Ok') return OsrmRoute.empty;

      final routes = data['routes'];
      if (routes is! List || routes.isEmpty) return OsrmRoute.empty;

      final first = routes.first;
      if (first is! Map<String, dynamic>) return OsrmRoute.empty;

      final encoded = first['geometry']?.toString() ?? '';
      final distance = (first['distance'] is num)
          ? (first['distance'] as num).toDouble()
          : 0.0;
      final duration = (first['duration'] is num)
          ? (first['duration'] as num).toDouble()
          : 0.0;

      return OsrmRoute(
        polyline: PolylineUtils.decode(encoded),
        distanceMeters: distance,
        durationSeconds: duration,
      );
    } on DioException {
      return OsrmRoute.empty;
    }
  }

  /// Backwards-compatible alias so the repository can keep calling
  /// `fetchPolyline(...)` exactly as it did with Directions.
  Future<List<LatLng>> fetchPolyline({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
    String mode = 'driving',
  }) async {
    final profile = _mapMode(mode);
    final route = await fetchRoute(
      origin: origin,
      destination: destination,
      waypoints: waypoints,
      profile: profile,
    );
    return route.polyline;
  }

  String _mapMode(String mode) {
    switch (mode) {
      case 'cycling':
      case 'bicycling':
      case 'bike':
        return 'cycling';
      case 'walking':
      case 'foot':
        return 'foot';
      case 'driving':
      case 'car':
      default:
        return 'driving';
    }
  }
}

class OsrmRoute {
  final List<LatLng> polyline;
  final double distanceMeters;
  final double durationSeconds;

  const OsrmRoute({
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  static const OsrmRoute empty = OsrmRoute(
    polyline: [],
    distanceMeters: 0,
    durationSeconds: 0,
  );

  bool get isEmpty => polyline.isEmpty;
}
