import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/config/offline_map_config.dart';
import 'package:laffeh/core/utils/area_grid.dart';
import 'package:laffeh/core/utils/distance_utils.dart';
import 'package:laffeh/core/utils/tile_math.dart';
import 'package:latlong2/latlong.dart';

const _riyadh = LatLng(24.7136, 46.6753);
const _degPerKmLat = 1 / 110.574;

bool _covered(List<CoordinateBounds> boxes, LatLng p) => boxes.any(
  (b) =>
      p.latitude >= b.southWest.latitude &&
      p.latitude <= b.northEast.latitude &&
      p.longitude >= b.southWest.longitude &&
      p.longitude <= b.northEast.longitude,
);

void main() {
  group('AreaGrid.around', () {
    test('a degenerate radius yields no cells rather than a broken box', () {
      expect(AreaGrid.around(_riyadh, radiusKm: 0), isEmpty);
      expect(AreaGrid.around(_riyadh, radiusKm: -5), isEmpty);
    });

    test('a radius under one cell still yields a single usable box', () {
      final boxes = AreaGrid.around(_riyadh, radiusKm: 2, cellKm: 12);

      expect(boxes, hasLength(1));
      expect(boxes.first.southWest.latitude, lessThan(_riyadh.latitude));
      expect(boxes.first.northEast.latitude, greaterThan(_riyadh.latitude));
    });

    test('the grid is square — one cell per cellKm on each side', () {
      // 30 km across at a 12 km cell needs 3 per side → 9 cells.
      final boxes = AreaGrid.around(_riyadh, radiusKm: 15, cellKm: 12);

      expect(boxes, hasLength(9));
    });

    test('every point within the radius falls inside some cell', () {
      const radiusKm = 15.0;
      final boxes = AreaGrid.around(_riyadh, radiusKm: radiusKm);

      // A lattice across the whole square, including the corners, which are
      // exactly what a driver skirting the edge of town needs.
      for (var northKm = -radiusKm; northKm <= radiusKm; northKm += 2.5) {
        for (var eastKm = -radiusKm; eastKm <= radiusKm; eastKm += 2.5) {
          final p = LatLng(
            _riyadh.latitude + northKm * _degPerKmLat,
            _riyadh.longitude + eastKm * _degPerKmLat / 0.9085, // cos(24.7°)
          );
          expect(
            _covered(boxes, p),
            isTrue,
            reason: '($northKm km N, $eastKm km E) is not covered by any cell',
          );
        }
      }
    });

    test('neighbouring cells overlap, so the area has no seams', () {
      final boxes = AreaGrid.around(_riyadh, radiusKm: 15, cellKm: 12);

      // Row-major order: cell 1 sits directly east of cell 0.
      expect(
        boxes[1].southWest.longitude,
        lessThan(boxes[0].northEast.longitude),
        reason: 'the cell to the east must start before its neighbour ends',
      );
      // Cell 3 opens the next row up, directly north of cell 0.
      expect(
        boxes[3].southWest.latitude,
        lessThan(boxes[0].northEast.latitude),
        reason: 'the cell to the north must start below its neighbour’s top',
      );
    });

    test('a huge radius stretches its cells instead of multiplying them', () {
      final boxes = AreaGrid.around(_riyadh, radiusKm: 500, cellKm: 1);

      expect(boxes.length, lessThanOrEqualTo(OfflineMapConfig.maxAreaCells));
      // Still covers the requested area, just in coarser slices.
      expect(
        _covered(
          boxes,
          LatLng(_riyadh.latitude + 400 * _degPerKmLat, _riyadh.longitude),
        ),
        isTrue,
      );
    });

    test('longitude padding widens towards the poles', () {
      double width(List<CoordinateBounds> boxes) =>
          boxes.first.northEast.longitude - boxes.first.southWest.longitude;

      final equator = AreaGrid.around(const LatLng(0, 0), radiusKm: 15);
      final north = AreaGrid.around(const LatLng(60, 0), radiusKm: 15);

      expect(
        width(north),
        greaterThan(width(equator) * 1.5),
        reason: '15 km of longitude spans far more degrees at 60°N',
      );
    });
  });

  group('TileMath', () {
    final boxes = AreaGrid.around(_riyadh, radiusKm: 15);

    test('a zoom level costs about four times the one below it', () {
      final z12 = TileMath.tilesFor(boxes, minZoom: 12, maxZoom: 12);
      final z13 = TileMath.tilesFor(boxes, minZoom: 13, maxZoom: 13);

      // Not exactly 4× — whole tiles are counted, so boundary tiles skew
      // small spans — but the growth must be unmistakably quadratic.
      expect(z13, greaterThan(z12 * 2));
    });

    test('the estimate grows with the radius', () {
      double mb(double radiusKm) => TileMath.estimatedMb(
        AreaGrid.around(_riyadh, radiusKm: radiusKm),
        minZoom: OfflineMapConfig.areaMinZoom,
        maxZoom: OfflineMapConfig.areaMaxZoom,
      );

      expect(mb(5), lessThan(mb(15)));
      expect(mb(15), lessThan(mb(30)));
    });

    test('the default area lands in a size a driver would accept', () {
      final mb = TileMath.estimatedMb(
        boxes,
        minZoom: OfflineMapConfig.areaMinZoom,
        maxZoom: OfflineMapConfig.areaMaxZoom,
      );

      // A guard on the tuning, not on the arithmetic: if a config change
      // ever turns the default download into hundreds of MB, the driver
      // should hear it from a failing test and not from their data bill.
      expect(mb, greaterThan(1));
      expect(mb, lessThan(60));
    });

    test('the biggest area the guard allows fits under the tile ceiling', () {
      // The picker lets a driver frame anything, so the only thing standing
      // between a selection and the native tile ceiling is the MB guard.
      // Grow a square until it trips that guard, then check the pack it
      // would have downloaded still fits — past the ceiling native stops
      // storing tiles mid-download and the pack silently comes out holed.
      var radiusKm = 10.0;
      var tiles = 0;
      while (radiusKm < 2000) {
        final boxes = AreaGrid.around(_riyadh, radiusKm: radiusKm);
        final mb = TileMath.estimatedMb(
          boxes,
          minZoom: OfflineMapConfig.areaMinZoom,
          maxZoom: OfflineMapConfig.areaMaxZoom,
        );
        if (mb > OfflineMapConfig.maxAreaMb) break;
        tiles = TileMath.tilesFor(
          boxes,
          minZoom: OfflineMapConfig.areaMinZoom,
          maxZoom: OfflineMapConfig.areaMaxZoom,
        );
        radiusKm += 5;
      }

      expect(tiles, greaterThan(0), reason: 'the guard rejected everything');
      expect(tiles, lessThan(OfflineMapConfig.offlineRegionTileLimit));
    });
  });

  group('AreaGrid.cover', () {
    // The rectangle a driver would frame on the map: wider than it is tall.
    final wide = CoordinateBounds(
      southWest: LatLng(
        _riyadh.latitude - 9 * _degPerKmLat,
        _riyadh.longitude - 24 * _degPerKmLat / 0.9085,
      ),
      northEast: LatLng(
        _riyadh.latitude + 9 * _degPerKmLat,
        _riyadh.longitude + 24 * _degPerKmLat / 0.9085,
      ),
    );

    test('an inside-out or empty rectangle yields no cells', () {
      final point = CoordinateBounds(southWest: _riyadh, northEast: _riyadh);
      expect(AreaGrid.cover(point), isEmpty);

      final inverted = CoordinateBounds(
        southWest: wide.northEast,
        northEast: wide.southWest,
      );
      expect(AreaGrid.cover(inverted), isEmpty);
    });

    test('the grid follows the rectangle rather than squaring it off', () {
      // 48 km across by 18 km tall at a 12 km cell → 4 columns, 2 rows.
      final boxes = AreaGrid.cover(wide, cellKm: 12);

      expect(boxes, hasLength(8));
    });

    test('every point inside the rectangle falls inside some cell', () {
      final boxes = AreaGrid.cover(wide);

      for (var northKm = -9.0; northKm <= 9.0; northKm += 1.5) {
        for (var eastKm = -24.0; eastKm <= 24.0; eastKm += 3) {
          final p = LatLng(
            _riyadh.latitude + northKm * _degPerKmLat,
            _riyadh.longitude + eastKm * _degPerKmLat / 0.9085,
          );
          expect(
            _covered(boxes, p),
            isTrue,
            reason: '($northKm km N, $eastKm km E) is not covered by any cell',
          );
        }
      }
    });

    test('a rectangle far past the cap stretches its cells, and returns', () {
      // The pathological framing: a whole continent at low zoom. This must
      // stay bounded *and* terminate — shrinking a 1000 × 1000 grid one
      // step at a time would not.
      final huge = CoordinateBounds(
        southWest: const LatLng(10, 10),
        northEast: const LatLng(50, 50),
      );

      final boxes = AreaGrid.cover(huge, cellKm: 1);

      expect(boxes.length, lessThanOrEqualTo(OfflineMapConfig.maxAreaCells));
      expect(_covered(boxes, const LatLng(30, 30)), isTrue);
    });

    test('the size a driver reads matches the rectangle they framed', () {
      final size = AreaGrid.sizeKm(wide);

      expect(size.widthKm, closeTo(48, 1));
      expect(size.heightKm, closeTo(18, 0.5));
    });
  });

  group('AreaGrid.isSameArea', () {
    // What the driver framed and saved last week.
    final saved = AreaGrid.squareAround(_riyadh, radiusKm: 15);

    test('a hand-reframed version of the same place is the same area', () {
      // Nobody reproduces a rectangle by thumb: a couple of km of drift and
      // a slightly different zoom is what "the same city" actually looks
      // like on the second visit.
      final again = AreaGrid.squareAround(
        LatLng(
          _riyadh.latitude + 2 * _degPerKmLat,
          _riyadh.longitude + 1.5 * _degPerKmLat / 0.9085,
        ),
        radiusKm: 17,
      );

      expect(AreaGrid.isSameArea(again, saved), isTrue);
    });

    test('another city is not the same area', () {
      // The bug this whole model exists to prevent: framing Jeddah while
      // Riyadh is saved must not read as an update — the download would
      // have replaced Riyadh.
      final jeddah = AreaGrid.squareAround(
        const LatLng(21.4858, 39.1925),
        radiusKm: 15,
      );

      expect(AreaGrid.isSameArea(jeddah, saved), isFalse);
    });

    test('a district inside a saved city is not the whole city', () {
      // Centres nearly coincide here, so size is the only thing that can
      // tell these apart.
      final district = AreaGrid.squareAround(_riyadh, radiusKm: 3);

      expect(AreaGrid.isSameArea(district, saved), isFalse);
    });

    test('a neighbouring area that merely overlaps is still not the same', () {
      final nextDoor = AreaGrid.squareAround(
        LatLng(_riyadh.latitude + 20 * _degPerKmLat, _riyadh.longitude),
        radiusKm: 15,
      );

      expect(AreaGrid.isSameArea(nextDoor, saved), isFalse);
    });
  });

  group('TileMath.normalizedY', () {
    test('round-trips a latitude through the projection', () {
      for (final lat in [-60.0, -24.7, 0.0, 24.7, 60.0]) {
        expect(
          TileMath.latAtNormalizedY(TileMath.normalizedY(lat)),
          closeTo(lat, 1e-6),
        );
      }
    });

    test('latitude is not linear down the screen', () {
      // The whole reason the frame's edges are interpolated in projected
      // space: halfway down a viewport is not halfway down its latitudes.
      final midY = (TileMath.normalizedY(60) + TileMath.normalizedY(0)) / 2;
      final midLat = TileMath.latAtNormalizedY(midY);

      expect(midLat, greaterThan(30.5));
    });
  });
}
