import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/map_config.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../../../core/utils/polyline_utils.dart';
import '../../domain/entities/optimized_route.dart';

/// Pure geometry / formatting helpers for the route map — arc-length
/// sub-paths, GeoJSON line features, colour string encoding, and the
/// look-ahead destination math. Stateless so they live outside the widget.
class MapGeometry {
  MapGeometry._();

  static const Map<String, dynamic> emptyGeoJson = {
    'type': 'FeatureCollection',
    'features': <dynamic>[],
  };

  /// Point [meters] from [origin] along [bearingDegrees] (great-circle).
  static LatLng destinationPoint(
    LatLng origin,
    double bearingDegrees,
    double meters,
  ) {
    if (meters <= 0) return origin;

    final angularDistance = meters / MapConfig.earthRadiusMeters;
    final bearing = bearingDegrees * math.pi / 180.0;
    final lat1 = origin.latitude * math.pi / 180.0;
    final lon1 = origin.longitude * math.pi / 180.0;

    final sinLat1 = math.sin(lat1);
    final cosLat1 = math.cos(lat1);
    final sinDistance = math.sin(angularDistance);
    final cosDistance = math.cos(angularDistance);

    final lat2 = math.asin(
      sinLat1 * cosDistance + cosLat1 * sinDistance * math.cos(bearing),
    );
    final lon2 =
        lon1 +
        math.atan2(
          math.sin(bearing) * sinDistance * cosLat1,
          cosDistance - sinLat1 * math.sin(lat2),
        );

    final normalizedLon = ((lon2 * 180.0 / math.pi + 540.0) % 360.0) - 180.0;
    return LatLng(lat2 * 180.0 / math.pi, normalizedLon);
  }

  /// `#rrggbb` for an opaque colour.
  static String hex(Color c) {
    final r = (c.r * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  /// `rgba(r,g,b,a)` for a translucent colour.
  static String rgba(Color c) {
    final r = (c.r * 255).round().clamp(0, 255);
    final g = (c.g * 255).round().clamp(0, 255);
    final b = (c.b * 255).round().clamp(0, 255);
    return 'rgba($r,$g,$b,${c.a.toStringAsFixed(3)})';
  }

  /// A single-LineString GeoJSON FeatureCollection for [pts].
  static Map<String, dynamic> lineGeoJson(List<LatLng> pts) {
    if (pts.isEmpty) return emptyGeoJson;
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': pts.map((p) => [p.longitude, p.latitude]).toList(),
          },
          'properties': <String, dynamic>{},
        },
      ],
    };
  }

  /// The leading portion of [path] up to arc-length fraction [t] (0..1).
  static List<LatLng> trailUpTo(List<LatLng> path, double t) {
    if (path.length < 2 || t <= 0) return const [];
    final total = DistanceUtils.pathLengthKm(path);
    if (total <= 0) return const [];
    final target = total * t.clamp(0.0, 1.0);

    final out = <LatLng>[path.first];
    double traveled = 0;
    for (var i = 0; i < path.length - 1; i++) {
      final segLen = DistanceUtils.haversineKm(path[i], path[i + 1]);
      if (traveled + segLen >= target) {
        final remaining = target - traveled;
        final f = segLen == 0 ? 0.0 : (remaining / segLen);
        out.add(
          LatLng(
            path[i].latitude + (path[i + 1].latitude - path[i].latitude) * f,
            path[i].longitude + (path[i + 1].longitude - path[i].longitude) * f,
          ),
        );
        return out;
      }
      traveled += segLen;
      out.add(path[i + 1]);
    }
    return out;
  }

  /// Arc-length sub-path of [path] between fractions [t0] and [t1] (0..1),
  /// endpoints interpolated. Carves the drive route into done/current/ahead.
  static List<LatLng> subPath(List<LatLng> path, double t0, double t1) {
    if (path.length < 2) return const [];
    final a = t0.clamp(0.0, 1.0);
    final b = t1.clamp(0.0, 1.0);
    if (b <= a) return const [];

    final total = DistanceUtils.pathLengthKm(path);
    if (total <= 0) return const [];
    final startD = total * a;
    final endD = total * b;

    final start = PolylineUtils.interpolateByLength(path, a);
    final out = <LatLng>[if (start != null) start];
    double traveled = 0;
    for (var i = 0; i < path.length - 1; i++) {
      final segLen = DistanceUtils.haversineKm(path[i], path[i + 1]);
      final segEnd = traveled + segLen;
      if (segEnd > startD && segEnd < endD) {
        out.add(path[i + 1]);
      }
      if (segEnd >= endD) {
        final end = PolylineUtils.interpolateByLength(path, b);
        if (end != null) out.add(end);
        break;
      }
      traveled = segEnd;
    }
    return out.length < 2 ? const [] : out;
  }

  /// Fraction (0..1) along [route.fullPolyline] of the stop the driver is
  /// heading to, clamped at or ahead of [progress]. Return depot → end.
  static double nextStopFraction(
    OptimizedRoute route,
    int stopIndex,
    double progress,
  ) {
    final pts = route.orderedPoints;
    if (pts.length < 2 || route.fullPolyline.length < 2) return 1.0;
    final i = stopIndex.clamp(0, pts.length - 1);
    if (i >= pts.length - 1) return 1.0; // heading back to depot
    final frac = fractionOfNearest(route.fullPolyline, pts[i].latLng);
    return frac.clamp(progress, 1.0);
  }

  /// Arc-length fraction (0..1) along [path] of the point nearest to
  /// [target], using proper segment projection (not just vertex distances)
  /// so drive-mode leg boundaries align with the true stop position.
  static double fractionOfNearest(List<LatLng> path, LatLng target) {
    if (path.length < 2) return 0.0;
    final totalKm = DistanceUtils.pathLengthKm(path);
    if (totalKm <= 0) return 0.0;

    double traveledKm = 0;
    double bestMeters = double.infinity;
    double bestFrac = 0;

    for (var i = 0; i < path.length - 1; i++) {
      final start = path[i];
      final end = path[i + 1];
      final segKm = DistanceUtils.haversineKm(start, end);
      final t = _projectionFraction(start, end, target);
      final projected = LatLng(
        start.latitude + (end.latitude - start.latitude) * t,
        start.longitude + (end.longitude - start.longitude) * t,
      );
      final distMeters = DistanceUtils.haversineKm(projected, target) * 1000;
      if (distMeters < bestMeters) {
        bestMeters = distMeters;
        bestFrac = ((traveledKm + segKm * t) / totalKm).clamp(0.0, 1.0);
      }
      traveledKm += segKm;
    }

    return bestFrac;
  }

  /// Projects [point] onto segment ([start]→[end]) and returns the
  /// interpolation parameter t (0..1). Equirectangular approximation so the
  /// math is cheap (called on every GPS tick).
  static double _projectionFraction(LatLng start, LatLng end, LatLng point) {
    final meanLat = _degToRad((start.latitude + end.latitude) / 2);
    final sx = start.longitude * math.cos(meanLat);
    final sy = start.latitude;
    final ex = end.longitude * math.cos(meanLat);
    final ey = end.latitude;
    final px = point.longitude * math.cos(meanLat);
    final py = point.latitude;

    final dx = ex - sx;
    final dy = ey - sy;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) return 0;

    return (((px - sx) * dx + (py - sy) * dy) / lengthSquared).clamp(0.0, 1.0);
  }

  static double _degToRad(double deg) => deg * math.pi / 180.0;
}
