import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/features/route_planner/presentation/pages/splash_page.dart';

void main() {
  void usePhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('animation remains while startup is still loading', (
    tester,
  ) async {
    usePhoneSize(tester);
    final startup = Completer<void>();
    var finished = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SplashPage(
          startup: startup.future,
          onFinished: () => finished++,
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(SplashPage), findsOneWidget);
    expect(finished, 0);

    startup.complete();
    await tester.pump();
    expect(finished, 1);
  });

  testWidgets('startup can finish before the road animation completes', (
    tester,
  ) async {
    usePhoneSize(tester);
    final startup = Completer<void>();
    var finished = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SplashPage(
          startup: startup.future,
          onFinished: () => finished++,
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));
    startup.complete();
    await tester.pump();
    expect(finished, 1);
  });
}
