// Visual preview of the playback car marker at various bearings.
// Run: flutter test test/marker_preview_test.dart --update-goldens
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laffeh/core/theme/app_colors.dart';
import 'package:laffeh/core/theme/vehicle_kind.dart';
import 'package:laffeh/core/utils/marker_factory.dart';

Widget _vehicleAt(VehicleKind kind, double bearing) => Transform.rotate(
  angle: bearing * math.pi / 180,
  child: SizedBox(
    width: 40,
    height: 40,
    child: CustomPaint(painter: kind.painter()),
  ),
);

void main() {
  testWidgets('vehicle marker bearings', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 280 * 3);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          // Map-ish backdrop so contrast is realistic.
          backgroundColor: const Color(0xFFE8ECDF),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final bearing in const [0.0, 45.0, 90.0, 180.0, 270.0])
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 56,
                            height: 56,
                            child: Center(
                              child: _vehicleAt(VehicleKind.vwBus, bearing),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${bearing.round()}°',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Vespa preview (the other selectable vehicle icon).
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final bearing in const [0.0, 90.0, 180.0])
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: Center(
                          child: _vehicleAt(VehicleKind.vespa, bearing),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 26),
                // Playback stop states: visited / visiting / upcoming.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: Center(
                        child: MarkerFactory.stop(
                          1,
                          visit: StopVisitState.visited,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: Center(
                        child: MarkerFactory.stop(
                          2,
                          visit: StopVisitState.visiting,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: Center(
                        child: MarkerFactory.stop(
                          3,
                          visit: StopVisitState.upcoming,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/vehicle_marker.png'),
    );
  });
}
