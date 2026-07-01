import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/utils/polyline_utils.dart';
import '../../domain/entities/route_maneuver.dart';

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
    bool includeSteps = false,
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
        queryParameters: {
          'overview': 'full',
          'geometries': 'polyline',
          // Steps carry the turn-by-turn maneuvers used by drive mode.
          // Only the full-trip fetch asks for them; the go/return leg
          // fetches keep the payload light.
          'steps': includeSteps ? 'true' : 'false',
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
        maneuvers: includeSteps ? _parseManeuvers(first) : const [],
      );
    } on DioException {
      return OsrmRoute.empty;
    }
  }

  // ── Step / maneuver parsing ────────────────────────────────────────────

  /// Flattens every leg's steps into route-ordered [RouteManeuver]s.
  ///
  /// Depart steps are dropped (one fires at the start of every leg — pure
  /// noise mid-trip). Roundabout exit events are dropped too: the entry
  /// maneuver already carries the exit number. Anything unrecognized is
  /// skipped rather than guessed at.
  static List<RouteManeuver> _parseManeuvers(Map<String, dynamic> route) {
    final out = <RouteManeuver>[];
    final legs = route['legs'];
    if (legs is! List) return out;

    for (final leg in legs) {
      if (leg is! Map<String, dynamic>) continue;
      final steps = leg['steps'];
      if (steps is! List) continue;

      for (final step in steps) {
        if (step is! Map<String, dynamic>) continue;
        final man = step['maneuver'];
        if (man is! Map<String, dynamic>) continue;

        final loc = man['location'];
        if (loc is! List || loc.length < 2) continue;
        final lon = (loc[0] is num) ? (loc[0] as num).toDouble() : null;
        final lat = (loc[1] is num) ? (loc[1] as num).toDouble() : null;
        if (lat == null || lon == null) continue;

        final type = man['type']?.toString() ?? '';
        final modifier = man['modifier']?.toString() ?? '';
        final exit = (man['exit'] is num) ? (man['exit'] as num).toInt() : null;
        final kind = _mapKind(type, modifier);
        if (kind == null) continue;

        final name = step['name']?.toString().trim() ?? '';
        out.add(
          RouteManeuver(
            kind: kind,
            latitude: lat,
            longitude: lon,
            roadName: name.isEmpty ? null : name,
            roundaboutExit: kind == ManeuverKind.roundabout ? exit : null,
          ),
        );
      }
    }
    return out;
  }

  /// OSRM `type` + `modifier` → [ManeuverKind]; null = skip the step.
  static ManeuverKind? _mapKind(String type, String modifier) {
    switch (type) {
      case 'depart':
        return null; // fires at every leg start — noise
      case 'arrive':
        return ManeuverKind.arrive;
      case 'merge':
        return ManeuverKind.merge;
      case 'on ramp':
        return ManeuverKind.onRamp;
      case 'off ramp':
        return ManeuverKind.offRamp;
      case 'roundabout':
      case 'rotary':
      case 'roundabout turn':
        return ManeuverKind.roundabout;
      case 'exit roundabout':
      case 'exit rotary':
        return null; // entry maneuver already announced the exit
      case 'fork':
        return switch (modifier) {
          'left' || 'slight left' || 'sharp left' => ManeuverKind.keepLeft,
          'right' || 'slight right' || 'sharp right' => ManeuverKind.keepRight,
          _ => ManeuverKind.straight,
        };
      case 'turn':
      case 'end of road':
      case 'continue':
      case 'new name':
      case 'notification':
        final kind = switch (modifier) {
          'left' => ManeuverKind.turnLeft,
          'right' => ManeuverKind.turnRight,
          'slight left' => ManeuverKind.slightLeft,
          'slight right' => ManeuverKind.slightRight,
          'sharp left' => ManeuverKind.sharpLeft,
          'sharp right' => ManeuverKind.sharpRight,
          'uturn' => ManeuverKind.uTurn,
          'straight' => ManeuverKind.straight,
          _ => null,
        };
        // "Continue straight" / road renames aren't real maneuvers — the
        // driver does nothing. Keep straight only for `end of road`-style
        // forced continues (type 'turn').
        if (kind == ManeuverKind.straight && type != 'turn') return null;
        return kind;
      default:
        return null;
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

  /// Route-ordered turn instructions; empty unless steps were requested.
  final List<RouteManeuver> maneuvers;

  const OsrmRoute({
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
    this.maneuvers = const [],
  });

  static const OsrmRoute empty = OsrmRoute(
    polyline: [],
    distanceMeters: 0,
    durationSeconds: 0,
  );

  bool get isEmpty => polyline.isEmpty;
}
