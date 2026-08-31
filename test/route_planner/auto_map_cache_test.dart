import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/config/offline_map_config.dart';
import 'package:laffeh/core/services/auto_map_cache.dart';
import 'package:laffeh/core/utils/area_grid.dart';
import 'package:laffeh/core/utils/distance_utils.dart';
import 'package:laffeh/core/utils/tile_math.dart';
import 'package:latlong2/latlong.dart';

/// The automatic square: the shape of what gets downloaded, and the rule
/// that decides whether to download it at all.
///
/// Both are pure, which is deliberate — this is the one feature in the app
/// that spends a driver's mobile data without asking, so the decision to
/// spend it has to be readable and testable on its own, with no platform
/// and no widget tree in the way.

const _damascus = LatLng(33.5138, 36.2765);

/// Roughly how far apart two points are in kilometres, north-south only —
/// enough to place a driver a chosen distance away without pulling in the
/// projection maths under test.
LatLng _northOf(LatLng from, double km) =>
    LatLng(from.latitude + km / 110.574, from.longitude);

void main() {
  group('the automatic square', () {
    final square = AreaGrid.squareAround(
      _damascus,
      radiusKm: OfflineMapConfig.autoAreaHalfEdgeKm,
    );

    test('measures the configured edge on both sides', () {
      final size = AreaGrid.sizeKm(square);

      expect(size.widthKm, closeTo(OfflineMapConfig.autoAreaEdgeKm, 0.5));
      expect(size.heightKm, closeTo(OfflineMapConfig.autoAreaEdgeKm, 0.5));
    });

    test('downloads in four cells, so a lost corner is only a corner', () {
      final boxes = AreaGrid.cover(
        square,
        cellKm: OfflineMapConfig.autoAreaCellKm,
      );

      expect(boxes, hasLength(4));
    });

    test('costs little enough to spend without asking', () {
      final boxes = AreaGrid.cover(
        square,
        cellKm: OfflineMapConfig.autoAreaCellKm,
      );
      final mb = TileMath.estimatedMb(
        boxes,
        minZoom: OfflineMapConfig.areaMinZoom,
        maxZoom: OfflineMapConfig.areaMaxZoom,
      );

      // The whole justification for downloading this unasked. If a change
      // to the edge, the cells or the zoom span pushes it past a handful of
      // megabytes, it stops being a cache and starts being a decision the
      // driver should have made.
      expect(mb, lessThan(15));
    });
  });

  group('AreaGrid.containsWithMargin', () {
    final square = AreaGrid.squareAround(
      _damascus,
      radiusKm: OfflineMapConfig.autoAreaHalfEdgeKm,
    );

    test('the centre is covered', () {
      expect(
        AreaGrid.containsWithMargin(
          square,
          _damascus,
          marginFraction: OfflineMapConfig.autoAreaCoveredMargin,
        ),
        isTrue,
      );
    });

    test('a point just inside the edge is NOT covered', () {
      // 9 km north of centre is inside a 10 km half-edge — and exactly the
      // driver a margin-free check would strand: still technically on the
      // stored map, one minute from being off it.
      final nearEdge = _northOf(_damascus, 9);

      expect(
        AreaGrid.containsWithMargin(square, nearEdge),
        isTrue,
        reason: 'it really is inside the rectangle',
      );
      expect(
        AreaGrid.containsWithMargin(
          square,
          nearEdge,
          marginFraction: OfflineMapConfig.autoAreaCoveredMargin,
        ),
        isFalse,
        reason: 'but not comfortably enough to skip the refresh',
      );
    });

    test('a point outside is never covered', () {
      expect(
        AreaGrid.containsWithMargin(square, _northOf(_damascus, 40)),
        isFalse,
      );
    });

    test('a degenerate rectangle covers nothing', () {
      const flat = CoordinateBounds(southWest: _damascus, northEast: _damascus);

      expect(AreaGrid.containsWithMargin(flat, _damascus), isFalse);
    });
  });

  group('AutoMapCache.isDue', () {
    final now = DateTime(2026, 8, 29, 12);

    /// Far enough that the stored square is no longer around the driver.
    final away = _northOf(
      _damascus,
      OfflineMapConfig.autoAreaHalfEdgeKm *
              OfflineMapConfig.autoAreaRefreshFraction +
          1,
    );

    test('a device that has never cached is always due', () {
      expect(
        AutoMapCache.isDue(
          now: now,
          lastAttemptAt: null,
          lastAttemptCentre: null,
          where: _damascus,
        ),
        isTrue,
      );
    });

    test('is not due again from the same spot minutes later', () {
      expect(
        AutoMapCache.isDue(
          now: now,
          lastAttemptAt: now.subtract(const Duration(minutes: 20)),
          lastAttemptCentre: _damascus,
          where: _northOf(_damascus, 1),
        ),
        isFalse,
      );
    });

    test('driving somewhere new does not wait out the long interval', () {
      // Half the half-edge is the threshold: past it the stored square no
      // longer sits around the driver, and six hours of waiting would leave
      // them on the edge of their own map.
      expect(
        AutoMapCache.isDue(
          now: now,
          lastAttemptAt: now.subtract(
            OfflineMapConfig.autoAreaFloorInterval + const Duration(minutes: 1),
          ),
          lastAttemptCentre: _damascus,
          where: away,
        ),
        isTrue,
      );
    });

    test('but the floor holds even then — this is the bill for a long run', () {
      // The case that would otherwise run away: a driver crossing a
      // province leaves the square every twenty minutes or so, and without
      // this each departure would buy a fresh one.
      expect(
        AutoMapCache.isDue(
          now: now,
          lastAttemptAt: now.subtract(
            OfflineMapConfig.autoAreaFloorInterval - const Duration(minutes: 1),
          ),
          lastAttemptCentre: _damascus,
          where: away,
        ),
        isFalse,
      );
    });

    test('the interval eventually frees a driver who never moved', () {
      expect(
        AutoMapCache.isDue(
          now: now,
          lastAttemptAt: now.subtract(
            OfflineMapConfig.autoAreaMinInterval + const Duration(minutes: 1),
          ),
          lastAttemptCentre: _damascus,
          where: _damascus,
        ),
        isTrue,
      );
    });
  });
}
