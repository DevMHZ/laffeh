import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/core/theme/app_theme.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/route_drive_action_bar.dart';

void main() {
  tearDown(() => AppStrings.setLocale(const Locale('en')));

  for (final locale in ['en', 'ar', 'fr']) {
    testWidgets(
      'GPS wait explains and disables start, then allows retry ($locale)',
      (tester) async {
        AppStrings.setLocale(Locale(locale));
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();
        var driveCount = 0;
        var debugCount = 0;

        Widget screen({required bool starting}) => MaterialApp(
          theme: AppTheme.data,
          home: Directionality(
            textDirection: AppStrings.isArabic
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: RouteDriveActionBar(
                  starting: starting,
                  onDrive: () => driveCount++,
                  onDebugLongPress: () => debugCount++,
                ),
              ),
            ),
          ),
        );

        await tester.pumpWidget(screen(starting: true));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text(AppStrings.navigationStartingHint), findsOneWidget);
        final busyLabel =
            '${AppStrings.navigationStarting}. ${AppStrings.navigationStartingHint}';
        expect(
          tester.getSemantics(find.bySemanticsLabel(busyLabel)),
          matchesSemantics(
            label: busyLabel,
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
            isLiveRegion: true,
            hasTapAction: false,
          ),
        );
        await tester.tap(find.text(AppStrings.navigationStarting));
        await tester.longPress(find.text(AppStrings.navigationStarting));
        expect(driveCount, 0);
        expect(debugCount, 0);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(screen(starting: false));
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await tester.tap(find.text(AppStrings.startNavigation));
        expect(driveCount, 1);
        semantics.dispose();
      },
    );
  }
}
