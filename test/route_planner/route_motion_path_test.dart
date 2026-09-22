import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:laffeh/core/utils/polyline_utils.dart';
import 'package:laffeh/features/route_planner/presentation/utils/route_motion_path.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/map_geometry.dart';

void main() {
  test('empty and stationary routes have no drawable trail', () {
    final empty = RouteMotionPath(const []);
    expect(empty.sampleAt(0.5), isNull);
    expect(empty.subPath(0, 1), isEmpty);

    for (final vertices in [
      const [LatLng(33.5, 36.3)],
      const [LatLng(33.5, 36.3), LatLng(33.5, 36.3)],
    ]) {
      final path = RouteMotionPath(vertices);
      expect(path.sampleAt(0.5), (point: vertices.first, bearing: 0.0));
      expect(path.subPath(0, 1), isEmpty);
    }
  });

  test('progress follows distance on an unevenly spaced road', () {
    final path = RouteMotionPath(const [
      LatLng(0, 0),
      LatLng(0, 0.001),
      LatLng(0, 0.01),
    ]);
    final middle = path.sampleAt(0.5)!;
    expect(middle.point.latitude, 0);
    expect(middle.point.longitude, closeTo(0.005, 1e-12));
    expect(middle.bearing, 90);
    expect(path.subPath(0.2, 0.8), hasLength(2));
    expect(path.subPath(0.2, 0.8).first.longitude, closeTo(0.002, 1e-12));
    expect(path.subPath(0.2, 0.8).last.longitude, closeTo(0.008, 1e-12));
  });

  test('the incoming bearing is preserved at a corner then turns forward', () {
    final path = RouteMotionPath(const [
      LatLng(0, 0),
      LatLng(0, 0.01),
      LatLng(0.01, 0.01),
    ]);
    expect(path.sampleAt(0.5)!.point, const LatLng(0, 0.01));
    expect(path.sampleAt(0.5)!.bearing, 90);
    expect(path.sampleAt(0.500001)!.bearing, 0);
    expect(path.sampleAt(1)!.bearing, 0);
  });

  test('duplicates keep the same endpoint and trail traversal semantics', () {
    const vertices = [
      LatLng(0, 0),
      LatLng(0, 0),
      LatLng(0, 0.01),
      LatLng(0, 0.01),
      LatLng(0.01, 0.01),
      LatLng(0.01, 0.01),
    ];
    final path = RouteMotionPath(vertices);
    expect(path.sampleAt(0)!.bearing, 0);
    expect(path.sampleAt(0.5)!.bearing, 90);
    expect(path.subPath(0, 1), [
      vertices.first,
      vertices[2],
      vertices[3],
      vertices.last,
    ]);
    expect(path.subPath(0.5, 1), [vertices[2], vertices.last]);
    expect(path.subPath(0, 0.5), [vertices.first, vertices[2]]);
  });

  test('clamped and reversed ranges cannot draw backwards', () {
    const vertices = [LatLng(33.5, 36.3), LatLng(33.51, 36.31)];
    final path = RouteMotionPath(vertices);
    expect(path.sampleAt(-2), path.sampleAt(0));
    expect(path.sampleAt(2), path.sampleAt(1));
    expect(path.subPath(-2, 3), vertices);
    expect(path.subPath(0.8, 0.2), isEmpty);
    expect(path.subPath(0.5, 0.5), isEmpty);
    expect(path.subPath(2, 3), isEmpty);
    expect(path.subPath(-3, -2), isEmpty);
  });

  test('the prepared route is independent of later caller list changes', () {
    final vertices = [const LatLng(0, 0), const LatLng(0, 0.01)];
    final path = RouteMotionPath(vertices);
    final original = path.sampleAt(0.5);
    vertices[1] = const LatLng(0.01, 0);
    vertices.clear();
    expect(path.sampleAt(0.5), original);
    expect(path.subPath(0, 1), const [LatLng(0, 0), LatLng(0, 0.01)]);
  });

  test(
    'cached sampling preserves existing geometry over loops and rewinds',
    () {
      final random = math.Random(401);
      final vertices = <LatLng>[const LatLng(24.741, 46.672)];
      for (var i = 0; i < 300; i++) {
        final previous = vertices.last;
        vertices.add(
          i % 11 == 0
              ? previous
              : LatLng(
                  previous.latitude + (random.nextDouble() - 0.5) / 100,
                  previous.longitude + (random.nextDouble() - 0.5) / 100,
                ),
        );
      }
      vertices.add(vertices.first);
      final path = RouteMotionPath(vertices);
      final progress = [-1.0, 0.0, 1.0, 2.0];
      progress.addAll(List.generate(100, (_) => random.nextDouble()));
      for (final p in progress) {
        expect(path.sampleAt(p), PolylineUtils.sampleAt(vertices, p));
        final from = random.nextDouble();
        expect(path.subPath(from, p), MapGeometry.subPath(vertices, from, p));
        expect(path.subPath(0, p), MapGeometry.subPath(vertices, 0, p));
      }
    },
  );
}
