/// Arc-length fractions on a round trip.
///
/// A round trip's polyline ends where it began, so the depot is near *both*
/// ends of it. The nearest-vertex search for the first stop is therefore free
/// to pick the last vertex — and because the search pointer only ever moves
/// forward, every stop after it gets pinned to the end too. Observed in the
/// field as a whole round of fractions reading 1.000, which left every stop
/// permanently "still ahead" during preview and completed the lot at once
/// when the car got home.
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:laffeh/core/utils/polyline_utils.dart';

/// Out along one street and back along the next one over, ending a hair
/// closer to the depot than it started — which is what road snapping does
/// when the outbound and the return use opposite sides of the carriageway.
({List<LatLng> path, List<LatLng> stops}) _roundTrip() {
  const depot = LatLng(25.2000, 55.2700);
  // Out along one side of the road and back along the other. Nothing on the
  // outbound sits exactly on the depot — it snapped a few metres off, as road
  // geometry does — while the return leg lands right on it. So the closest
  // vertex to the depot in the whole polyline is the very last one.
  final out = [
    for (var i = 0; i <= 60; i++) LatLng(25.20003 + i * 0.0005, 55.27002),
  ];
  final back = [
    for (var i = 60; i >= 1; i--) LatLng(25.20003 + i * 0.0005, 55.26998),
  ];
  final path = [...out, ...back, depot];
  final stops = [
    depot,
    const LatLng(25.2050, 55.2700),
    const LatLng(25.2100, 55.2700),
    const LatLng(25.2200, 55.2700),
    depot,
  ];
  return (path: path, stops: stops);
}

void main() {
  test('a round trip does not collapse every stop onto the last vertex', () {
    final t = _roundTrip();
    final f = PolylineUtils.stopFractions(t.path, t.stops);

    expect(f.length, t.stops.length);
    expect(
      f.toSet().length,
      greaterThan(1),
      reason: 'every stop landed on the same vertex: $f',
    );
    expect(f.first, lessThan(0.5), reason: 'the depot is the start: $f');
    expect(f.last, greaterThan(0.5), reason: 'the return is the end: $f');
  });

  test('the stops keep their order along the path', () {
    final t = _roundTrip();
    final f = PolylineUtils.stopFractions(t.path, t.stops);
    for (var i = 1; i < f.length; i++) {
      expect(f[i], greaterThanOrEqualTo(f[i - 1]), reason: '$f');
    }
  });

  test('the middle stops are spread across the outbound leg', () {
    final t = _roundTrip();
    final f = PolylineUtils.stopFractions(t.path, t.stops);
    // Three stops going out, so none of them should be sitting at the end.
    expect(f[1], lessThan(0.5), reason: '$f');
    expect(f[2], lessThan(0.5), reason: '$f');
    expect(f[3], lessThan(0.75), reason: '\$f');
  });

  test('a one-way route is unaffected', () {
    final path = [for (var i = 0; i <= 100; i++) LatLng(i * 0.0005, 0)];
    final stops = [
      const LatLng(0, 0),
      const LatLng(0.0125, 0),
      const LatLng(0.025, 0),
      const LatLng(0.05, 0),
    ];
    final f = PolylineUtils.stopFractions(path, stops);
    expect(f.first, 0.0);
    expect(f.last, closeTo(1.0, 0.02));
    expect(f.toSet().length, 4);
  });
}
