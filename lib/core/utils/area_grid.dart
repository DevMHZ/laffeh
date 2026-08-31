import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../config/offline_map_config.dart';
import 'distance_utils.dart';

/// Turns a chosen patch of map into the grid of boxes that gets downloaded.
///
/// This is the route-independent half of the offline map: it needs nothing
/// but a rectangle, so the driver has map under them whether or not a trip
/// has been planned — and whether or not the map they need is the one
/// around them. [RouteCorridor] is the other half, for when a trip exists.
///
/// Pure geometry, deliberately free of any MapLibre import, so the grid can
/// be reasoned about and tested without a platform channel.
class AreaGrid {
  AreaGrid._();

  /// Degrees of latitude per kilometre. Constant everywhere.
  static const double _degPerKmLat = 1 / 110.574;

  /// The grid of cells covering [area] — the rectangle the driver framed on
  /// the map.
  ///
  /// Cells are as close to [cellKm] square as dividing the rectangle
  /// evenly allows, and overlap by [seamPaddingKm] on every side so no
  /// sliver of map falls between two of them. A rectangle far larger than
  /// the cap allows stretches its cells rather than multiplying them past
  /// [maxCells] — the size guard in front of the download is what keeps a
  /// selection sane; this only keeps the grid finite.
  static List<CoordinateBounds> cover(
    CoordinateBounds area, {
    double cellKm = OfflineMapConfig.areaCellKm,
    double seamPaddingKm = OfflineMapConfig.areaSeamPaddingKm,
    int maxCells = OfflineMapConfig.maxAreaCells,
  }) {
    if (cellKm <= 0) return const [];

    final south = area.southWest.latitude;
    final north = area.northEast.latitude;
    final west = area.southWest.longitude;
    final east = area.northEast.longitude;
    if (north <= south || east <= west) return const [];

    // Longitude degrees shrink towards the poles, so the km-per-degree
    // conversion is taken at the middle of the rectangle. The divisor is
    // floored so an area near a pole widens a lot instead of dividing by
    // zero.
    final midLat = (south + north) / 2;
    final cosLat = math.max(math.cos(midLat * math.pi / 180).abs(), 0.01);
    final latPadding = seamPaddingKm * _degPerKmLat;
    final lonPadding = seamPaddingKm * _degPerKmLat / cosLat;

    final heightKm = (north - south) / _degPerKmLat;
    final widthKm = (east - west) / _degPerKmLat * cosLat;

    // The epsilon keeps an exact multiple (24 km across a 12 km cell) from
    // becoming three cells on a float hair over 2.0.
    var rows = math.max(1, (heightKm / cellKm - 1e-9).ceil());
    var cols = math.max(1, (widthKm / cellKm - 1e-9).ceil());
    (rows, cols) = _capCells(rows, cols, maxCells);

    final latStep = (north - south) / rows;
    final lonStep = (east - west) / cols;
    final out = <CoordinateBounds>[];

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        out.add(
          CoordinateBounds(
            southWest: LatLng(
              (south + row * latStep - latPadding).clamp(-90.0, 90.0),
              (west + col * lonStep - lonPadding).clamp(-180.0, 180.0),
            ),
            northEast: LatLng(
              (south + (row + 1) * latStep + latPadding).clamp(-90.0, 90.0),
              (west + (col + 1) * lonStep + lonPadding).clamp(-180.0, 180.0),
            ),
          ),
        );
      }
    }

    return out;
  }

  /// The square of cells covering everything within [radiusKm] of [center].
  ///
  /// [radiusKm] is a half-edge, not a circle: the pack reaches that far in
  /// every direction, so 15 km yields a 30 × 30 km map. A square is what
  /// the tile grid is made of anyway, and cutting it to a disc would drop
  /// exactly the corners a driver skirting the edge of town needs.
  ///
  /// Kept as the shorthand for "the map around here" — it is what frames
  /// the picker when it opens, and what the tests describe the grid with.
  static List<CoordinateBounds> around(
    LatLng center, {
    double radiusKm = OfflineMapConfig.defaultAreaRadiusKm,
    double cellKm = OfflineMapConfig.areaCellKm,
    double seamPaddingKm = OfflineMapConfig.areaSeamPaddingKm,
    int maxCells = OfflineMapConfig.maxAreaCells,
  }) {
    if (radiusKm <= 0) return const [];
    return cover(
      squareAround(center, radiusKm: radiusKm),
      cellKm: cellKm,
      seamPaddingKm: seamPaddingKm,
      maxCells: maxCells,
    );
  }

  /// The square reaching [radiusKm] from [center] in every direction, as a
  /// plain rectangle — what the picker frames on open.
  static CoordinateBounds squareAround(
    LatLng center, {
    double radiusKm = OfflineMapConfig.defaultAreaRadiusKm,
  }) {
    final cosLat = math.max(
      math.cos(center.latitude * math.pi / 180).abs(),
      0.01,
    );
    final dLat = radiusKm * _degPerKmLat;
    final dLon = radiusKm * _degPerKmLat / cosLat;

    return CoordinateBounds(
      southWest: LatLng(
        (center.latitude - dLat).clamp(-90.0, 90.0),
        (center.longitude - dLon).clamp(-180.0, 180.0),
      ),
      northEast: LatLng(
        (center.latitude + dLat).clamp(-90.0, 90.0),
        (center.longitude + dLon).clamp(-180.0, 180.0),
      ),
    );
  }

  /// Ground covered by [area], as the width × height a driver would read
  /// off it.
  static ({double widthKm, double heightKm}) sizeKm(CoordinateBounds area) {
    final south = area.southWest.latitude;
    final north = area.northEast.latitude;
    final midLat = (south + north) / 2;
    final cosLat = math.max(math.cos(midLat * math.pi / 180).abs(), 0.01);

    return (
      widthKm:
          (area.northEast.longitude - area.southWest.longitude) /
          _degPerKmLat *
          cosLat,
      heightKm: (north - south) / _degPerKmLat,
    );
  }

  /// Whether [point] sits *comfortably* inside [area] — not merely inside
  /// it.
  ///
  /// [marginFraction] is taken off the whole span, half from each side, so
  /// 0.2 keeps the outer tenth of the rectangle on every edge out of
  /// bounds. That margin is the difference between a cache that refreshes
  /// itself in time and one that refreshes once the driver is already off
  /// the map they were relying on.
  static bool containsWithMargin(
    CoordinateBounds area,
    LatLng point, {
    double marginFraction = 0,
  }) {
    final latSpan = area.northEast.latitude - area.southWest.latitude;
    final lonSpan = area.northEast.longitude - area.southWest.longitude;
    if (latSpan <= 0 || lonSpan <= 0) return false;

    final latMargin = latSpan * marginFraction / 2;
    final lonMargin = lonSpan * marginFraction / 2;

    return point.latitude >= area.southWest.latitude + latMargin &&
        point.latitude <= area.northEast.latitude - latMargin &&
        point.longitude >= area.southWest.longitude + lonMargin &&
        point.longitude <= area.northEast.longitude - lonMargin;
  }

  /// Whether [a] and [b] are close enough to be the same saved area.
  ///
  /// This is what decides whether the driver is offered "download" or
  /// "update", so it is deliberately forgiving. Nobody re-frames a rectangle
  /// by thumb twice, and treating a near-miss as a new area would quietly
  /// store a second copy of the same city; treating it as a refresh costs
  /// only a re-download of ground they already had.
  ///
  /// Two tests have to pass together: the centres sit within a fraction of
  /// the smaller rectangle's span, *and* neither rectangle is more than
  /// twice the other. Centres alone would call a city and the district
  /// inside it the same place.
  static bool isSameArea(
    CoordinateBounds a,
    CoordinateBounds b, {
    double centreFraction = OfflineMapConfig.areaSameCentreFraction,
  }) {
    final sizeA = sizeKm(a);
    final sizeB = sizeKm(b);
    final spanA = math.min(sizeA.widthKm, sizeA.heightKm);
    final spanB = math.min(sizeB.widthKm, sizeB.heightKm);
    if (spanA <= 0 || spanB <= 0) return false;

    final ratio = spanA / spanB;
    if (ratio > 2 || ratio < 0.5) return false;

    final centreA = LatLng(
      (a.southWest.latitude + a.northEast.latitude) / 2,
      (a.southWest.longitude + a.northEast.longitude) / 2,
    );
    final centreB = LatLng(
      (b.southWest.latitude + b.northEast.latitude) / 2,
      (b.southWest.longitude + b.northEast.longitude) / 2,
    );

    return DistanceUtils.haversineKm(centreA, centreB) <=
        math.min(spanA, spanB) * centreFraction;
  }

  /// Shrinks the grid to fit under [maxCells], keeping its shape.
  ///
  /// Scaling both sides at once rather than decrementing in a loop matters
  /// for the pathological input: a 1000 × 1000 grid would otherwise take
  /// nearly a million iterations to walk down to 10 × 10.
  static (int, int) _capCells(int rows, int cols, int maxCells) {
    if (rows * cols <= maxCells) return (rows, cols);

    final scale = math.sqrt(maxCells / (rows * cols));
    var r = math.max(1, (rows * scale).floor());
    var c = math.max(1, (cols * scale).floor());
    while (r * c > maxCells && (r > 1 || c > 1)) {
      if (r >= c) {
        r--;
      } else {
        c--;
      }
    }
    return (math.max(1, r), math.max(1, c));
  }
}
