import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/core/theme/app_theme.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/stop_arrival_actions.dart';

void main() {
  tearDown(() => AppStrings.setLocale(const Locale('en')));
  for (final locale in ['en', 'ar', 'fr']) {
    testWidgets(
      'arrival outcomes and contact at narrow width / large text: $locale',
      (tester) async {
        AppStrings.setLocale(Locale(locale));
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final actions = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.data,
            home: Directionality(
              textDirection: locale == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(12),
                    child: StopArrivalActions(
                      deliveredLabel: AppStrings.deliveredNext,
                      nextLabel: AppStrings.continueToNextStop,
                      onDelivered: () => actions.add('delivered'),
                      onUnableToDeliver: () => actions.add('unable'),
                      onCall: () => actions.add('call'),
                      onWhatsapp: () => actions.add('whatsapp'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        final delivered = find.byKey(const ValueKey('arrival-delivered'));
        final unable = find.byKey(const ValueKey('arrival-unable'));
        expect(
          tester.getSize(delivered).width,
          closeTo(tester.getSize(unable).width * 2, 0.01),
        );
        expect(tester.getSize(delivered).height, tester.getSize(unable).height);
        expect(tester.getSize(delivered).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
        await tester.tap(find.text(AppStrings.stopCall));
        await tester.tap(find.text(AppStrings.stopWhatsapp));
        expect(actions, [
          'call',
          'whatsapp',
        ], reason: 'Contact never completes a delivery.');
        await tester.tap(delivered);
        await tester.tap(unable);
        expect(actions, ['call', 'whatsapp', 'delivered', 'unable']);
        final semantics = tester.ensureSemantics();
        final node = tester.getSemantics(delivered);
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        expect(node.label, contains(AppStrings.continueToNextStop));
        semantics.dispose();
      },
    );
  }
}
