import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laffeh/core/theme/app_theme.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/map_compass.dart';

/// The one way back from a hand-tilted map.
///
/// The planning map can now be leaned over with two fingers, and this
/// control is the only thing that undoes it — so what matters is that it
/// *shows up* for an angle, not just for a heading, and that a tap resets
/// both. Before tilt existed it was unreachable UI: nothing could turn the
/// planning map off north either.

Widget _harness(
  ValueNotifier<double> bearing,
  ValueNotifier<double> tilt, {
  VoidCallback? onTap,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.data,
    home: Scaffold(
      body: Center(
        child: MapCompass(bearing: bearing, tilt: tilt, onTap: onTap ?? () {}),
      ),
    ),
  );
}

/// The control is always mounted and fades; opacity is what "visible" means.
double _opacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find.descendant(
        of: find.byType(MapCompass),
        matching: find.byType(AnimatedOpacity),
      ),
    )
    .opacity;

void main() {
  testWidgets('stays out of the way of a flat, north-up map', (tester) async {
    await tester.pumpWidget(_harness(ValueNotifier(0), ValueNotifier(0)));
    await tester.pump(const Duration(milliseconds: 300));

    expect(_opacity(tester), 0);
  });

  testWidgets('appears once the map is tilted, even facing north', (
    tester,
  ) async {
    final tilt = ValueNotifier<double>(0);
    await tester.pumpWidget(_harness(ValueNotifier(0), tilt));
    await tester.pump(const Duration(milliseconds: 300));
    expect(_opacity(tester), 0, reason: 'flat to begin with');

    // Two fingers dragged up: the map leans over, and the way back has to
    // arrive with it.
    tilt.value = 45;
    await tester.pump(const Duration(milliseconds: 300));

    expect(_opacity(tester), 1);
  });

  testWidgets('appears when the map is turned off north, as it always did', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(ValueNotifier(37), ValueNotifier(0)));
    await tester.pump(const Duration(milliseconds: 300));

    expect(_opacity(tester), 1);
  });

  testWidgets('a degree of camera noise is not a driver decision', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(ValueNotifier(0.4), ValueNotifier(0.6)));
    await tester.pump(const Duration(milliseconds: 300));

    expect(_opacity(tester), 0);
  });

  testWidgets('tapping it asks the host to put the map back', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _harness(ValueNotifier(0), ValueNotifier(50), onTap: () => taps++),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byType(MapCompass));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('while hidden it does not swallow taps meant for the map', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _harness(ValueNotifier(0), ValueNotifier(0), onTap: () => taps++),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byType(MapCompass), warnIfMissed: false);
    await tester.pump();

    expect(taps, 0);
  });
}
