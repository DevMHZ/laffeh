import 'dart:math' as math;

import '../config/offline_map_config.dart';
import 'distance_utils.dart';

/// Web-Mercator tile arithmetic, used to tell the user roughly how big a
/// download will be *before* they commit to it.
///
/// Counting the actual tiles a box covers beats a flat "MB per box" fudge
/// factor for one practical reason: an area cell and a route-corridor box
/// are wildly different shapes, so a per-box constant would have to be
/// wrong for at least one of them. Pure arithmetic, no MapLibre import, so
/// it is testable without a platform channel.
class TileMath {
  TileMath._();

  /// Number of tiles at [zoom] needed to cover [bounds].
  ///
  /// Counts whole tiles: a box straddling a tile edge pulls both, which is
  /// exactly what the downloader does too.
  static int tilesAt(CoordinateBounds bounds, int zoom) {
    final n = 1 << zoom;

    final xMin = _lonToTileX(bounds.southWest.longitude, n);
    final xMax = _lonToTileX(bounds.northEast.longitude, n);
    // Tile Y grows southward, so the *north* edge gives the smaller index.
    final yMin = _latToTileY(bounds.northEast.latitude, n);
    final yMax = _latToTileY(bounds.southWest.latitude, n);

    return (xMax - xMin + 1) * (yMax - yMin + 1);
  }

  /// Total tiles across the inclusive zoom span [minZoom]..[maxZoom].
  static int tilesFor(
    Iterable<CoordinateBounds> boxes, {
    required double minZoom,
    required double maxZoom,
  }) {
    var total = 0;
    for (final box in boxes) {
      for (var z = minZoom.floor(); z <= maxZoom.floor(); z++) {
        total += tilesAt(box, z);
      }
    }
    return total;
  }

  /// Rough download size in MB for [boxes] over the given zoom span.
  ///
  /// Deliberately an over-estimate where boxes overlap — every pack we
  /// build overlaps its neighbours on purpose (seams), and a figure that
  /// comes in under what actually downloads is the one that annoys people.
  static double estimatedMb(
    Iterable<CoordinateBounds> boxes, {
    required double minZoom,
    required double maxZoom,
  }) {
    final tiles = tilesFor(boxes, minZoom: minZoom, maxZoom: maxZoom);
    return tiles * OfflineMapConfig.estimatedKbPerTile / 1024;
  }

  /// Web-Mercator Y for [lat], normalised to 0 at the north edge of the
  /// world and 1 at the south.
  ///
  /// Exposed because latitude is *not* linear down the screen: a frame
  /// inset a fifth of the way down the viewport does not sit a fifth of the
  /// way down the latitude span. Anything turning screen fractions back
  /// into coordinates has to travel through Mercator, and doing it here
  /// keeps that arithmetic in the one file that already owns it.
  static double normalizedY(double lat) {
    // Clamped to the Mercator limit; beyond it the projection diverges.
    final clamped = lat.clamp(-_mercatorLimit, _mercatorLimit);
    final rad = clamped * math.pi / 180;
    return (1 - math.log(math.tan(rad) + 1 / math.cos(rad)) / math.pi) / 2;
  }

  /// Inverse of [normalizedY].
  static double latAtNormalizedY(double y) {
    final n = math.pi * (1 - 2 * y.clamp(0.0, 1.0));
    // atan(sinh(n)) — the Gudermannian, which Dart has no built-in for.
    final sinh = (math.exp(n) - math.exp(-n)) / 2;
    return math.atan(sinh) * 180 / math.pi;
  }

  /// Latitude past which the Mercator projection runs away to infinity.
  static const double _mercatorLimit = 85.05112878;

  static int _lonToTileX(double lon, int n) =>
      (((lon + 180) / 360) * n).floor().clamp(0, n - 1);

  static int _latToTileY(double lat, int n) =>
      (normalizedY(lat) * n).floor().clamp(0, n - 1);
}
