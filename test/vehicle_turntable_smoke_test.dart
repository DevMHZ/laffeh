import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/theme/vehicle_kind.dart';
import 'package:laffeh/core/widgets/vehicle_turntable.dart';

void main() {
  // Decodes the real baked sheets and drives the cross-fade painter through
  // a chunk of the revolution — catches broken sheet geometry (grid maths)
  // and painter regressions without booting the app.
  testWidgets('turntable plays every baked sheet without errors', (
    tester,
  ) async {
    for (final kind in VehicleKind.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: VehicleTurntable(kind: kind, size: 160)),
        ),
      );
      // Let the sheet decode, then advance through several frames.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(tester.takeException(), isNull, reason: 'kind=$kind');
    }
  });

  testWidgets('static turntable holds the garage thumbnail frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: VehicleTurntable(
            kind: VehicleKind.taxi,
            size: 26,
            animate: false,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}
