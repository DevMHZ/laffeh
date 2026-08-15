import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_point.dart';
import 'package:laffeh/features/route_planner/domain/entities/stop_time_window.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/missed_time_window_sheet.dart';

RoutePoint _late(String label, int lateBy) => RoutePoint(
  id: label,
  latitude: 33.9,
  longitude: 35.55,
  label: label,
  weight: 10,
  kind: RoutePointKind.stop,
  timeWindow: const StopTimeWindow(
    startMinuteOfDay: 9 * 60,
    endMinuteOfDay: 10 * 60,
  ),
  timeWindowMissed: true,
  latenessMinutes: lateBy,
);

/// Copy comes from [AppStrings], which is driven by its own static locale
/// rather than MaterialApp's — so the host stays on the default delegates
/// (they only ship English) and only the text direction is switched.
Widget _host(Widget child, {String locale = 'ar'}) {
  AppStrings.setLocale(Locale(locale));
  return MaterialApp(
    home: Scaffold(
      body: Directionality(
        textDirection: locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        child: Center(child: SingleChildScrollView(child: child)),
      ),
    ),
  );
}

void main() {
  tearDown(() => AppStrings.setLocale(const Locale('en')));

  testWidgets('banner names each late stop with how late it is', (tester) async {
    await tester.pumpWidget(
      _host(
        MissedWindowBanner(
          points: [_late('صيدلية', 25), _late('مستودع', 90)],
          onTap: () {},
        ),
      ),
    );

    // The stop names, so the user knows which ones.
    expect(find.text('صيدلية'), findsOneWidget);
    expect(find.text('مستودع'), findsOneWidget);
    // The size of each overshoot — the point of this change.
    expect(find.text(AppStrings.lateByMinutes(25)), findsOneWidget);
    expect(find.text(AppStrings.lateByMinutes(90)), findsOneWidget);
    // And a way forward, not just a red box.
    expect(find.text(AppStrings.seeDetails), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('banner is tappable', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _host(
        MissedWindowBanner(
          points: [_late('صيدلية', 25)],
          onTap: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.text(AppStrings.seeDetails));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('lateness reads as hours once past an hour', (tester) async {
    AppStrings.setLocale(const Locale('en'));
    expect(AppStrings.lateByMinutes(45), '45 min late');
    expect(AppStrings.lateByMinutes(60), '1 h late');
    expect(AppStrings.lateByMinutes(95), '1 h 35 min late');
  });

  testWidgets('banner renders in every supported language', (tester) async {
    for (final code in ['en', 'ar', 'fr']) {
      await tester.pumpWidget(
        _host(
          MissedWindowBanner(points: [_late('Stop', 25)], onTap: () {}),
          locale: code,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'locale $code');
    }
  });
}
