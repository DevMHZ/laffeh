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

  testWidgets('banner leads with the worst stop and how late it is', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        MissedWindowBanner(
          points: [_late('صيدلية', 25), _late('مستودع', 90)],
          onTap: () {},
        ),
      ),
    );

    // The headline count, so the size of the problem is known before the tap.
    expect(find.text(AppStrings.timeWindowMissedCount(2)), findsOneWidget);
    // The worst offender by name — not the first one in the list.
    expect(find.text('مستودع'), findsOneWidget);
    // In a chip, the compact delta: the long phrase would crowd the name out.
    expect(find.text(AppStrings.lateByShort(90)), findsOneWidget);
    // The rest are counted in the headline, not listed: the sheet is where
    // they belong.
    expect(find.text('صيدلية'), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the compact chip stays short enough to sit beside a name', (
    tester,
  ) async {
    AppStrings.setLocale(const Locale('en'));
    // A chip is a delta, not a sentence — the surrounding red already says
    // "late", and the long form is what pushed the stop name off the row.
    expect(AppStrings.lateByShort(25), '+25 min');
    expect(AppStrings.lateByShort(60), '+1h');
    expect(AppStrings.lateByShort(95), '+1h 35m');
    expect(AppStrings.lateByShort(95).length, lessThan(10));

    // Arabic leads with a word: a "+" is bidi-neutral and would be pushed
    // to the wrong side of the digit, reading as "1+".
    AppStrings.setLocale(const Locale('ar'));
    expect(AppStrings.lateByShort(25), 'تأخير 25 د');
    expect(AppStrings.lateByShort(95), 'تأخير 1 س 35 د');
    expect(AppStrings.lateByShort(95), isNot(startsWith('+')));
  });

  testWidgets('the whole banner is the tap target', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _host(
        MissedWindowBanner(
          points: [_late('صيدلية', 25)],
          onTap: () => tapped = true,
        ),
      ),
    );

    // Tapping the headline — not a small "see details" link — opens it.
    await tester.tap(find.text(AppStrings.timeWindowMissedCount(1)));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('Arabic counts two stops as a dual, not a plural', (
    tester,
  ) async {
    AppStrings.setLocale(const Locale('ar'));
    expect(AppStrings.timeWindowMissedCount(2), contains('نقطتان'));
    expect(AppStrings.timeWindowMissedCount(2), isNot(contains('2 نقاط')));
    // 3–10 take the plural noun, 11+ the singular.
    expect(AppStrings.timeWindowMissedCount(4), contains('4 نقاط'));
    expect(AppStrings.timeWindowMissedCount(12), contains('12 نقطة'));
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
