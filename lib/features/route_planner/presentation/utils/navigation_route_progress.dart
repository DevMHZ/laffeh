import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../../../core/utils/distance_utils.dart';

/// Matches a GPS fix to the active part of the trip. A route can use the
/// same road several times; the nearest point on the whole trip is ambiguous.
class NavigationRouteProgress {
  NavigationRouteProgress._();

  static ({double progress, double offRouteMeters})? project(
    List<LatLng> path,
    LatLng location, {
    double from = 0,
    double to = 1,
    double? previousProgress,
    double? heading,
    double accuracyMeters = 10,
  }) {
    if (path.length < 2) return null;
    final total = DistanceUtils.pathLengthKm(path);
    if (total <= 0) return null;
    final legStart = from.clamp(0.0, 1.0);
    final legEnd = to.clamp(legStart, 1.0);
    final previous = previousProgress != null && previousProgress.isFinite
        ? previousProgress.clamp(legStart, legEnd)
        : null;
    // Retain a little already-driven road for noisy fixes. Keeping the whole
    // leg makes an out-and-back route match the outbound road forever.
    final lower = math.max(
      legStart * total,
      previous == null ? 0.0 : previous * total - 0.020,
    );
    final upper = legEnd * total;
    final direction = heading != null && heading.isFinite ? heading : null;
    final tolerance = accuracyMeters.isFinite
        ? accuracyMeters.clamp(5.0, 30.0)
        : 10.0;
    var traveled = 0.0;
    var bestDistance = double.infinity;
    var bestProgress = lower / total;
    var bestAlignment = 0.0;
    for (var i = 0; i < path.length - 1; i++) {
      final a = path[i];
      final b = path[i + 1];
      final length = DistanceUtils.haversineKm(a, b);
      final end = traveled + length;
      if (length > 0 && end >= lower && traveled <= upper) {
        final scale = math.cos((a.latitude + b.latitude) * math.pi / 360);
        final dx = (b.longitude - a.longitude) * scale;
        final dy = b.latitude - a.latitude;
        final px = (location.longitude - a.longitude) * scale;
        final py = location.latitude - a.latitude;
        final squared = dx * dx + dy * dy;
        final t = (squared == 0 ? 0.0 : (px * dx + py * dy) / squared).clamp(
          ((lower - traveled) / length).clamp(0.0, 1.0),
          ((upper - traveled) / length).clamp(0.0, 1.0),
        );
        final point = LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        );
        final distance = DistanceUtils.haversineKm(point, location) * 1000;
        final progress = (traveled + length * t) / total;
        final alignment = direction == null
            ? 0.0
            : math.cos(math.atan2(dx, dy) - direction * math.pi / 180);
        var better = distance < bestDistance - 0.01;
        if (previous != null && (distance - bestDistance).abs() <= tolerance) {
          // GPS noise can put the fix a few metres behind the lower bound.
          // Do not teleport to a much-later reverse pass just because it is
          // an exact spatial match. Moving heading distinguishes the two
          // directions; otherwise preserve the nearest route traversal.
          if (direction != null && (alignment - bestAlignment).abs() > 1) {
            better = alignment > bestAlignment;
          } else if ((progress - bestProgress).abs() * total * 1000 > 40) {
            // Adjacent vertices on the same traversal should still pick the
            // closest road point, even when fixes are less than 10 m apart.
            final gap = (progress - previous).abs();
            final bestGap = (bestProgress - previous).abs();
            if ((gap - bestGap).abs() > 1e-9) better = gap < bestGap;
          }
        }
        if (better) {
          bestDistance = distance;
          bestProgress = progress;
          bestAlignment = alignment;
        }
      }
      traveled = end;
      if (traveled > upper) break;
    }
    if (!bestDistance.isFinite) return null;
    return (progress: bestProgress, offRouteMeters: bestDistance);
  }
}
