import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../config/offline_map_config.dart';
import 'distance_utils.dart';

/// Turns a route polyline into the chain of small padded boxes that get
/// downloaded for offline use — the route's "corridor".
///
/// This is the trip-specific half of the offline map; [AreaGrid] is the
/// half that needs no route at all.
///
/// Pure geometry, deliberately free of any MapLibre import, so the chunking
/// can be reasoned about and tested without a platform channel.
class RouteCorridor {
  RouteCorridor._();

  /// Degrees of latitude per kilometre. Constant everywhere.
  static const double _degPerKmLat = 1 / 110.574;

  /// Splits [polyline] into consecutive boxes, each covering roughly
  /// [chunkKm] of road and padded by [paddingKm] on every side.
  ///
  /// Consecutive boxes overlap by twice the padding, which is what keeps the
  /// map seamless at the seams between them.
  ///
  /// Returns an empty list for an empty polyline. A single-point polyline
  /// yields one box centred on it, so "download the map around this stop"
  /// degrades sensibly rather than throwing.
  static List<CoordinateBounds> chunk(
    List<LatLng> polyline, {
    double chunkKm = OfflineMapConfig.corridorChunkKm,
    double paddingKm = OfflineMapConfig.corridorPaddingKm,
    int maxChunks = OfflineMapConfig.maxCorridorChunks,
  }) {
    if (polyline.isEmpty) return const [];
    if (polyline.length == 1) {
      return [_pad(DistanceUtils.boundsOf(polyline), paddingKm)];
    }

    // A long trip stretches its chunks rather than producing hundreds of
    // regions: the effective chunk length is whatever keeps the count under
    // the cap.
    final totalKm = DistanceUtils.pathLengthKm(polyline);
    final effectiveChunkKm = math.max(chunkKm, totalKm / maxChunks);

    final out = <CoordinateBounds>[];
    var current = <LatLng>[polyline.first];
    double runKm = 0;

    for (var i = 1; i < polyline.length; i++) {
      runKm += DistanceUtils.haversineKm(polyline[i - 1], polyline[i]);
      current.add(polyline[i]);

      if (runKm >= effectiveChunkKm && i < polyline.length - 1) {
        out.add(_pad(DistanceUtils.boundsOf(current), paddingKm));
        // The next box restarts *at* the shared vertex, so the corridor has
        // no gap between consecutive boxes even before padding.
        current = <LatLng>[polyline[i]];
        runKm = 0;
      }
    }

    if (current.length > 1) {
      out.add(_pad(DistanceUtils.boundsOf(current), paddingKm));
    } else if (out.isEmpty) {
      out.add(_pad(DistanceUtils.boundsOf(polyline), paddingKm));
    }

    return out;
  }

  /// Expands [bounds] by [paddingKm] on all four sides.
  ///
  /// Longitude degrees shrink towards the poles, so the horizontal padding
  /// is scaled by cos(latitude); the divisor is floored so a route near a
  /// pole widens a lot instead of dividing by zero.
  static CoordinateBounds _pad(CoordinateBounds bounds, double paddingKm) {
    final latPad = paddingKm * _degPerKmLat;

    final midLat = (bounds.southWest.latitude + bounds.northEast.latitude) / 2;
    final cosLat = math.max(math.cos(midLat * math.pi / 180).abs(), 0.01);
    final lonPad = latPad / cosLat;

    return CoordinateBounds(
      southWest: LatLng(
        (bounds.southWest.latitude - latPad).clamp(-90.0, 90.0),
        (bounds.southWest.longitude - lonPad).clamp(-180.0, 180.0),
      ),
      northEast: LatLng(
        (bounds.northEast.latitude + latPad).clamp(-90.0, 90.0),
        (bounds.northEast.longitude + lonPad).clamp(-180.0, 180.0),
      ),
    );
  }
}
