import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:laffeh/core/utils/polyline_utils.dart';
import 'package:laffeh/features/route_planner/presentation/utils/navigation_route_progress.dart';

void main() {
  const outAndBack = [LatLng(0, 0), LatLng(0.01, 0), LatLng(0, 0)];

  test('keeps repeated roads inside the active leg', () {
    final outbound = NavigationRouteProgress.project(
      outAndBack,
      const LatLng(0.004, 0),
      to: 0.5,
    )!;
    final inbound = NavigationRouteProgress.project(
      outAndBack,
      const LatLng(0.004, 0),
      from: 0.5,
    )!;
    expect(outbound.progress, closeTo(0.2, 1e-8));
    expect(inbound.progress, closeTo(0.8, 1e-8));
  });

  test('a single leg follows the return pass after its U-turn', () {
    var previous = 0.0;
    for (var i = 0; i <= 100; i++) {
      final expected = i / 100;
      final location = PolylineUtils.interpolateByLength(outAndBack, expected)!;
      final projection = NavigationRouteProgress.project(
        outAndBack,
        location,
        previousProgress: previous,
        heading: expected <= 0.5 ? 0 : 180,
      )!;
      expect(projection.progress, closeTo(expected, 1e-8), reason: 'sample $i');
      previous = projection.progress;
    }
  });

  test('backward GPS noise cannot snap an outbound driver onto the return', () {
    for (final heading in <double?>[0, null, double.nan]) {
      // About 28 m behind the last fix, slightly outside the retained 20 m.
      final projection = NavigationRouteProgress.project(
        outAndBack,
        const LatLng(0.00475, 0),
        previousProgress: 0.25,
        heading: heading,
        accuracyMeters: 15,
      )!;
      expect(projection.progress, inInclusiveRange(0.24, 0.25));
      expect(projection.offRouteMeters, lessThan(15));
    }
  });

  test(
    'moving south disambiguates an otherwise identical road at a U-turn',
    () {
      final projection = NavigationRouteProgress.project(
        outAndBack,
        const LatLng(0.0099, 0),
        previousProgress: 0.5,
        heading: 180,
      )!;
      expect(projection.progress, closeTo(0.505, 1e-8));
    },
  );

  test(
    'far from the route remains off-route rather than inventing progress',
    () {
      final projection = NavigationRouteProgress.project(
        outAndBack,
        const LatLng(0.005, 0.002),
        previousProgress: 0.25,
        heading: 0,
      )!;
      expect(projection.offRouteMeters, greaterThan(200));
    },
  );

  test('dense vertices keep resolving small forward movements precisely', () {
    final dense = [for (var i = 0; i <= 100; i++) LatLng(i * 0.00001, 0)];
    for (var i = 1; i <= 100; i++) {
      final projection = NavigationRouteProgress.project(
        dense,
        dense[i],
        previousProgress: (i - 1) / 100,
        heading: 0,
      )!;
      expect(projection.progress, closeTo(i / 100, 1e-8));
      expect(projection.offRouteMeters, closeTo(0, 0.001));
    }
  });

  test('duplicate vertices and route limits remain finite', () {
    final projection = NavigationRouteProgress.project(
      [outAndBack.first, outAndBack.first, ...outAndBack.skip(1)],
      outAndBack.last,
      from: 0.5,
      to: 0.8,
      previousProgress: 0.79,
    )!;
    expect(projection.progress, closeTo(0.8, 1e-8));
    expect(projection.offRouteMeters.isFinite, isTrue);
    expect(NavigationRouteProgress.project([], const LatLng(0, 0)), isNull);
    expect(
      NavigationRouteProgress.project([
        const LatLng(0, 0),
        const LatLng(0, 0),
      ], const LatLng(0, 0)),
      isNull,
    );
  });
}
