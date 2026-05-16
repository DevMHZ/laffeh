import 'dart:math' as math;

import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'distance_utils.dart';

/// Polyline helpers.
///
/// Wraps `flutter_polyline_points` to keep encoded-polyline decoding
/// out of the rest of the codebase, and provides arc-length helpers
/// used by the simulation playback.
class PolylineUtils {
  PolylineUtils._();

  /// Decode a Google-encoded polyline string into LatLng coordinates.
  static List<LatLng> decode(String encoded) {
    if (encoded.isEmpty) return const [];
    final points = PolylinePoints().decodePolyline(encoded);
    return points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList(growable: false);
  }

  /// Straight-line polyline (fallback when no router geometry exists).
  static List<LatLng> straightPath(List<LatLng> points) =>
      List.unmodifiable(points);

  /// Interpolate a point at fraction `t` (0..1) along [path] using
  /// arc length — the result is at `t * totalLength` from the start,
  /// regardless of how unevenly spaced the vertices are.
  static LatLng? interpolateByLength(List<LatLng> path, double t) {
    if (path.isEmpty) return null;
    if (path.length == 1) return path.first;
    final clamped = t.clamp(0.0, 1.0);
    final total = DistanceUtils.pathLengthKm(path);
    if (total <= 0) return path.first;

    final target = total * clamped;
    double traveled = 0;

    for (var i = 0; i < path.length - 1; i++) {
      final segLen = DistanceUtils.haversineKm(path[i], path[i + 1]);
      if (traveled + segLen >= target) {
        final remaining = target - traveled;
        final f = segLen == 0 ? 0.0 : (remaining / segLen);
        return LatLng(
          path[i].latitude + (path[i + 1].latitude - path[i].latitude) * f,
          path[i].longitude + (path[i + 1].longitude - path[i].longitude) * f,
        );
      }
      traveled += segLen;
    }
    return path.last;
  }

  /// Returns `(point, bearingDegrees)` at fraction `t` along [path].
  /// Bearing uses initial-bearing of the segment the point lies on,
  /// so a marker rotated by it appears to "face forward".
  static ({LatLng point, double bearing})? sampleAt(
    List<LatLng> path,
    double t,
  ) {
    if (path.isEmpty) return null;
    if (path.length == 1) return (point: path.first, bearing: 0);

    final clamped = t.clamp(0.0, 1.0);
    final total = DistanceUtils.pathLengthKm(path);
    if (total <= 0) return (point: path.first, bearing: 0);

    final target = total * clamped;
    double traveled = 0;

    for (var i = 0; i < path.length - 1; i++) {
      final segLen = DistanceUtils.haversineKm(path[i], path[i + 1]);
      if (traveled + segLen >= target) {
        final remaining = target - traveled;
        final f = segLen == 0 ? 0.0 : (remaining / segLen);
        final p = LatLng(
          path[i].latitude + (path[i + 1].latitude - path[i].latitude) * f,
          path[i].longitude + (path[i + 1].longitude - path[i].longitude) * f,
        );
        return (point: p, bearing: _bearing(path[i], path[i + 1]));
      }
      traveled += segLen;
    }
    return (
      point: path.last,
      bearing: _bearing(path[path.length - 2], path.last),
    );
  }

  static double _bearing(LatLng a, LatLng b) {
    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final brng = _rad2deg(math.atan2(y, x));
    return (brng + 360) % 360;
  }

  static double _deg2rad(double d) => d * 0.017453292519943295;
  static double _rad2deg(double r) => r * 57.29577951308232;
}
