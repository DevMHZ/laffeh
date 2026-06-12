import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../constants/app_constants.dart';

/// Geometry helpers used by the route planner.
///
/// Pure functions, no Flutter widget dependency, so they are
/// trivially unit-testable.
class DistanceUtils {
  DistanceUtils._();

  static const double _earthRadiusKm = 6371.0088;

  /// Haversine distance between two coordinates in **kilometers**.
  static double haversineKm(LatLng a, LatLng b) {
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);

    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);

    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return _earthRadiusKm * c;
  }

  /// Total length (km) of a path of latlngs.
  static double pathLengthKm(List<LatLng> path) {
    if (path.length < 2) return 0;
    double total = 0;
    for (var i = 0; i < path.length - 1; i++) {
      total += haversineKm(path[i], path[i + 1]);
    }
    return total;
  }

  /// Coordinate bounds that wrap a list of points, with padding
  /// applied by the map widget that consumes them.
  static CoordinateBounds boundsOf(List<LatLng> points) {
    assert(points.isNotEmpty, 'cannot compute bounds for empty list');

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    // Avoid zero-area bounds (single point) so map camera fitting
    // always has a visible rectangle to work with.
    if ((maxLat - minLat).abs() < 1e-6) {
      minLat -= 0.002;
      maxLat += 0.002;
    }
    if ((maxLng - minLng).abs() < 1e-6) {
      minLng -= 0.002;
      maxLng += 0.002;
    }

    return CoordinateBounds(
      southWest: LatLng(minLat, minLng),
      northEast: LatLng(maxLat, maxLng),
    );
  }

  static double _deg2rad(double deg) => deg * (math.pi / 180.0);
}

class CoordinateBounds {
  final LatLng southWest;
  final LatLng northEast;

  const CoordinateBounds({required this.southWest, required this.northEast});

  List<LatLng> get corners => [southWest, northEast];
}

/// Friendly formatters for metric values shown to the user.
class MetricFormat {
  MetricFormat._();

  /// Formats kilometers in the active app language.
  static String distance(double km) {
    if (km.isNaN || km.isInfinite) return '--';
    if (km < 1) {
      final meters = (km * 1000).round();
      return '$meters ${AppUnits.meter}';
    }
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} ${AppUnits.km}';
  }

  /// Formats minutes in the active app language.
  static String duration(double minutes) {
    if (minutes.isNaN || minutes.isInfinite) return '--';
    if (minutes < 60) return '${minutes.round()} ${AppUnits.min}';
    final hours = (minutes / 60).floor();
    final remaining = (minutes - hours * 60).round();
    if (remaining == 0) return '$hours ${AppUnits.hour}';
    return '$hours ${AppUnits.hour} $remaining ${AppUnits.min}';
  }

  /// Formats liters in the active app language.
  static String fuelLiters(double liters) {
    if (liters.isNaN || liters.isInfinite) return '--';
    return '${liters.toStringAsFixed(1)} ${AppUnits.liter}';
  }
}
