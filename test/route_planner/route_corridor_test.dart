import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/config/offline_map_config.dart';
import 'package:laffeh/core/utils/distance_utils.dart';
import 'package:laffeh/core/utils/route_corridor.dart';
import 'package:latlong2/latlong.dart';

/// Walks north from Riyadh in ~1 km steps, giving a straight route of a
/// known length to reason about.
List<LatLng> _northLine({required double km, double stepKm = 1}) {
  const degPerKm = 1 / 110.574;
  final out = <LatLng>[];
  for (double d = 0; d <= km; d += stepKm) {
    out.add(LatLng(24.7136 + d * degPerKm, 46.6753));
  }
  return out;
}

void main() {
  group('RouteCorridor.chunk', () {
    test('empty polyline yields no boxes', () {
      expect(RouteCorridor.chunk(const []), isEmpty);
    });

    test('single point still yields one padded box around it', () {
      final boxes = RouteCorridor.chunk([const LatLng(24.7136, 46.6753)]);

      expect(boxes, hasLength(1));
      expect(boxes.first.southWest.latitude, lessThan(24.7136));
      expect(boxes.first.northEast.latitude, greaterThan(24.7136));
    });

    test('short route fits in a single box', () {
      final boxes = RouteCorridor.chunk(_northLine(km: 3));
      expect(boxes, hasLength(1));
    });

    test('long route is split roughly every chunkKm', () {
      // 40 km at the 8 km default → about 5 boxes. The exact count depends
      // on where the accumulator crosses the threshold, so assert the band.
      final boxes = RouteCorridor.chunk(_northLine(km: 40));

      expect(boxes.length, greaterThanOrEqualTo(4));
      expect(boxes.length, lessThanOrEqualTo(6));
    });

    test('very long route is capped at maxCorridorChunks', () {
      final boxes = RouteCorridor.chunk(_northLine(km: 900, stepKm: 5));

      expect(
        boxes.length,
        lessThanOrEqualTo(OfflineMapConfig.maxCorridorChunks),
        reason: 'a cross-country trip must stretch its chunks, not multiply',
      );
    });

    test('consecutive boxes overlap, so the corridor has no seams', () {
      final boxes = RouteCorridor.chunk(_northLine(km: 40));

      for (var i = 1; i < boxes.length; i++) {
        final previousTop = boxes[i - 1].northEast.latitude;
        final nextBottom = boxes[i].southWest.latitude;
        expect(
          nextBottom,
          lessThan(previousTop),
          reason: 'box $i must start below where box ${i - 1} ended',
        );
      }
    });

    test('every route vertex falls inside some box', () {
      final route = _northLine(km: 40);
      final boxes = RouteCorridor.chunk(route);

      for (final p in route) {
        final covered = boxes.any(
          (b) =>
              p.latitude >= b.southWest.latitude &&
              p.latitude <= b.northEast.latitude &&
              p.longitude >= b.southWest.longitude &&
              p.longitude <= b.northEast.longitude,
        );
        expect(covered, isTrue, reason: '$p is not covered by any box');
      }
    });

    test('padding widens a straight line into a usable corridor', () {
      // A due-north line has zero width before padding; afterwards it must
      // be at least the configured margin on each side.
      final boxes = RouteCorridor.chunk(_northLine(km: 5));
      final box = boxes.first;

      final widthKm = DistanceUtils.haversineKm(
        LatLng(box.southWest.latitude, box.southWest.longitude),
        LatLng(box.southWest.latitude, box.northEast.longitude),
      );

      expect(widthKm, greaterThan(OfflineMapConfig.corridorPaddingKm));
    });

    test('a chunked corridor is far smaller than one bbox for an L route', () {
      // Two legs at right angles: the naive single bbox covers the whole
      // square, most of which is nowhere near the road.
      const degPerKm = 1 / 110.574;
      final route = <LatLng>[
        for (double d = 0; d <= 40; d += 1) LatLng(24.7 + d * degPerKm, 46.7),
        for (double d = 1; d <= 40; d += 1)
          LatLng(24.7 + 40 * degPerKm, 46.7 + d * degPerKm),
      ];

      final boxes = RouteCorridor.chunk(route);
      final single = DistanceUtils.boundsOf(route);

      double area(double swLat, double swLon, double neLat, double neLon) =>
          (neLat - swLat).abs() * (neLon - swLon).abs();

      final corridorArea = boxes.fold<double>(
        0,
        (sum, b) =>
            sum +
            area(
              b.southWest.latitude,
              b.southWest.longitude,
              b.northEast.latitude,
              b.northEast.longitude,
            ),
      );
      final singleArea = area(
        single.southWest.latitude,
        single.southWest.longitude,
        single.northEast.latitude,
        single.northEast.longitude,
      );

      expect(
        corridorArea,
        lessThan(singleArea / 2),
        reason: 'chunking must beat a single bbox on an L-shaped route',
      );
    });
  });
}
