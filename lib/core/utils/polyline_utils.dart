import 'dart:math' as math;

import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:latlong2/latlong.dart';

import 'distance_utils.dart';

/// Polyline helpers.
///
/// Wraps `flutter_polyline_points` to keep encoded-polyline decoding
/// out of the rest of the codebase, and provides arc-length helpers
/// used by the simulation playback.
class PolylineUtils {
  PolylineUtils._();

  /// Decode an encoded polyline string into LatLng coordinates.
  static List<LatLng> decode(String encoded) {
    if (encoded.isEmpty) return const [];
    final points = PolylinePoints.decodePolyline(encoded);
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

  /// Bearing (degrees) of the road *ahead* of fraction [t]: the chord from
  /// the point at [t] to one [aheadMeters] further along [path].
  ///
  /// A follow camera oriented by this rotates *into* a turn slightly before
  /// the vehicle reaches it, so the upcoming road keeps pointing "up" rather
  /// than swinging sideways mid-bend. Averaging over the window also makes it
  /// steadier than the local tangent ([sampleAt]); near the end of the path,
  /// where the two points converge, it falls back to that tangent.
  static double lookAheadBearing(
    List<LatLng> path,
    double t,
    double aheadMeters,
  ) {
    if (path.length < 2) return 0;
    final totalKm = DistanceUtils.pathLengthKm(path);
    if (totalKm <= 0) return 0;
    final from = interpolateByLength(path, t);
    final aheadT = (t + (aheadMeters / 1000) / totalKm).clamp(0.0, 1.0);
    final to = interpolateByLength(path, aheadT);
    if (from == null ||
        to == null ||
        DistanceUtils.haversineKm(from, to) * 1000 < 2) {
      return sampleAt(path, t)?.bearing ?? 0;
    }
    return _bearing(from, to);
  }

  /// How far apart two passes over the same place can be and still count
  /// as the same place: the width of a divided road plus a lane or two.
  static const double _stopPassToleranceKm = 0.04;

  /// True arc-length fraction of each [stops] entry along [path]. Computed
  /// once per route, then compared against live progress.
  ///
  /// Two phases, because a stop is not simply "the nearest vertex":
  ///
  ///  1. A monotonic sweep pins each stop at or after the previous one, so
  ///     the fractions can never run backwards.
  ///  2. Where the route passes the same place more than once — the
  ///     outbound carriageway before a U-turn, a loop back through a
  ///     junction — the *last* of those passes before the next stop wins.
  ///     That pass is where the leg actually ends; picking the drive-by
  ///     instead is what collapses "500 m of driving left" into "you're
  ///     already there".
  static List<double> stopFractions(List<LatLng> path, List<LatLng> stops) {
    if (stops.isEmpty) return const [];
    if (path.length < 2) return List.filled(stops.length, 0.0);

    // Cumulative arc length per vertex (km).
    final cum = List<double>.filled(path.length, 0);
    for (var i = 1; i < path.length; i++) {
      cum[i] = cum[i - 1] + DistanceUtils.haversineKm(path[i - 1], path[i]);
    }
    final total = cum.last;
    if (total <= 0) return List.filled(stops.length, 0.0);

    // Phase 1 — nearest vertex at or after the previous stop's.
    final idx = <int>[];
    final nearestKm = <double>[];
    var from = 0;
    for (final s in stops) {
      var best = double.infinity;
      var bestIdx = from;
      for (var i = from; i < path.length; i++) {
        final d = DistanceUtils.haversineKm(path[i], s);
        if (d < best) {
          best = d;
          bestIdx = i;
        }
      }
      idx.add(bestIdx);
      nearestKm.add(best);
      from = bestIdx;
    }

    // Phase 2 — slide each stop forward to its last equally-near pass,
    // never as far as the next stop (so two doors on the same street keep
    // their own fractions, and a drive-by that happens later in the trip
    // can't claim this stop).
    for (var k = 0; k < stops.length; k++) {
      final limit = k + 1 < idx.length ? idx[k + 1] - 1 : path.length - 1;
      final ceiling = nearestKm[k] + _stopPassToleranceKm;
      for (var i = limit; i > idx[k]; i--) {
        if (DistanceUtils.haversineKm(path[i], stops[k]) <= ceiling) {
          idx[k] = i;
          break;
        }
      }
    }

    return [for (final i in idx) (cum[i] / total).clamp(0.0, 1.0)];
  }

  /// Arc-length fraction of each [targets] entry along [path], where the
  /// targets are known to already be in route order (e.g. OSRM maneuvers).
  ///
  /// A single monotonic sweep: each target's search resumes from the vertex
  /// matched for the previous one, so results never go backwards even when
  /// the route revisits the same road — and the whole list costs one pass
  /// over the polyline instead of one per target.
  static List<double> orderedFractionsAlong(
    List<LatLng> path,
    List<LatLng> targets,
  ) {
    if (targets.isEmpty) return const [];
    if (path.length < 2) return List.filled(targets.length, 0.0);

    // Cumulative arc length per vertex (km).
    final cum = List<double>.filled(path.length, 0);
    for (var i = 1; i < path.length; i++) {
      cum[i] = cum[i - 1] + DistanceUtils.haversineKm(path[i - 1], path[i]);
    }
    final total = cum.last;
    if (total <= 0) return List.filled(targets.length, 0.0);

    var startIdx = 0;
    final out = <double>[];
    for (final t in targets) {
      var best = double.infinity;
      var bestIdx = startIdx;
      for (var i = startIdx; i < path.length; i++) {
        final d = DistanceUtils.haversineKm(path[i], t);
        if (d < best) {
          best = d;
          bestIdx = i;
        }
        // Found a near-exact vertex and we're now clearly walking away
        // from it — no need to scan the rest of the route.
        if (best < 0.005 && d > best + 0.05) break;
      }
      startIdx = bestIdx;
      out.add((cum[bestIdx] / total).clamp(0.0, 1.0));
    }
    return out;
  }

  static double _bearing(LatLng a, LatLng b) {
    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);

    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final brng = _rad2deg(math.atan2(y, x));
    return (brng + 360) % 360;
  }

  static double _deg2rad(double d) => d * 0.017453292519943295;
  static double _rad2deg(double r) => r * 57.29577951308232;
}
