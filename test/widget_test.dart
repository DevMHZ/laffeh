import 'package:flutter_test/flutter_test.dart';

import 'package:laffeh/core/utils/distance_utils.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  test('haversine zero distance for identical points', () {
    const p = LatLng(24.7136, 46.6753);
    expect(DistanceUtils.haversineKm(p, p), 0);
  });

  test('haversine returns a positive distance between distinct points', () {
    const a = LatLng(24.7136, 46.6753);
    const b = LatLng(24.6702, 46.7394);
    expect(DistanceUtils.haversineKm(a, b), greaterThan(0));
  });
}
