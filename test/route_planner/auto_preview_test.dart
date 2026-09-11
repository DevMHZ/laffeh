import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:laffeh/core/config/preview_prefs.dart';
import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/core/theme/app_theme.dart';
import 'package:laffeh/features/route_planner/domain/entities/optimized_route.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_metrics.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_point.dart';
import 'package:laffeh/features/route_planner/domain/entities/stop_time_window.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_state.dart';
import 'package:laffeh/features/route_planner/presentation/utils/auto_preview_controller.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/route_preview_actions.dart';
import '../support/preview_fonts.dart';

OptimizedRoute route({bool approximate = false}) => OptimizedRoute(
  orderedPoints: const [
    RoutePoint(
      id: 'd',
      latitude: 33.89,
      longitude: 35.50,
      label: 'Departure',
      weight: 1,
      kind: RoutePointKind.depot,
    ),
    RoutePoint(
      id: 'a',
      latitude: 33.90,
      longitude: 35.51,
      label: 'First',
      weight: 1,
      kind: RoutePointKind.stop,
    ),
    RoutePoint(
      id: 'b',
      latitude: 33.91,
      longitude: 35.52,
      label: 'Second',
      weight: 1,
      kind: RoutePointKind.stop,
    ),
  ],
  fullPolyline: const [LatLng(33.89, 35.50), LatLng(33.91, 35.52)],
  goPolyline: const [LatLng(33.89, 35.50), LatLng(33.91, 35.52)],
  returnPolyline: const [],
  metrics: const RouteMetrics(totalDistanceKm: 10),
  hasRoadGeometry: true,
  routingMethod: approximate ? 'haversine' : 'local_osrm',
);

class Rig {
  bool allowed = true;
  int starts = 0;
  RoutePlannerState state = RoutePlannerState(
    status: RoutePlannerStatus.optimizedSuccess,
    optimizedRoute: route(),
  );
  late final controller = AutoPreviewController(
    canStart: (route) =>
        allowed &&
        identical(route, state.optimizedRoute) &&
        AutoPreviewController.eligible(state),
    onStart: () => starts++,
  );

  void optimize() {
    state = state.copyWith(previewRequestId: state.previewRequestId + 1);
    controller.update(state);
  }

  void ready() => controller.mapReady(state.optimizedRoute);
  void update(RoutePlannerState next) {
    state = next;
    controller.update(state);
  }
}

void main() {
  setUpAll(() async {
    await loadPreviewIconFonts();
    final font = FontLoader('Almarai');
    for (final weight in ['Regular', 'Bold', 'ExtraBold', 'Light']) {
      font.addFont(rootBundle.load('assets/fonts/Almarai-$weight.ttf'));
    }
    await font.load();
  });
  setUp(() {
    AppStrings.setLocale(const Locale('en'));
    PreviewPrefs.notifier.value = true;
  });
  tearDown(() {
    AppStrings.setLocale(const Locale('en'));
    PreviewPrefs.notifier.value = true;
  });

  testWidgets(
    'waits for the rendered route, then gives five full seconds once',
    (tester) async {
      final rig = Rig();
      addTearDown(rig.controller.dispose);
      rig.optimize();
      await tester.pump(const Duration(seconds: 20));
      expect(rig.controller.secondsRemaining, isNull);
      expect(rig.starts, 0);
      rig.ready();
      expect(rig.controller.secondsRemaining, 5);
      for (var second = 4; second > 0; second--) {
        await tester.pump(const Duration(seconds: 1));
        rig.ready(); // More native callbacks must not reset the countdown.
        rig.controller.update(rig.state);
        expect(rig.controller.secondsRemaining, second);
      }
      expect(rig.starts, 0);
      await tester.pump(const Duration(seconds: 1));
      expect(rig.starts, 1);
      rig.update(rig.state.copyWith(simulationActive: true));
      rig.update(rig.state.copyWith(simulationActive: false));
      rig.ready();
      await tester.pump(const Duration(seconds: 10));
      expect(rig.starts, 1);
    },
  );

  for (final issue in ['missed time window', 'approximate stop order']) {
    testWidgets('$issue keeps the review banners on screen', (tester) async {
      final rig = Rig();
      addTearDown(rig.controller.dispose);
      final planned = route(approximate: issue == 'approximate stop order');
      rig.state = rig.state.copyWith(
        optimizedRoute: planned,
        points: [
          for (final point in planned.orderedPoints)
            if (issue == 'missed time window' && point.id == 'a')
              point.copyWith(
                timeWindow: const StopTimeWindow(
                  startMinuteOfDay: 600,
                  endMinuteOfDay: 660,
                ),
                timeWindowMissed: true,
              )
            else
              point,
        ],
      );
      rig.optimize();
      rig.ready();
      await tester.pump(const Duration(seconds: 6));
      expect(rig.starts, 0);
      expect(rig.controller.secondsRemaining, isNull);
    });
  }

  testWidgets('a restored route never requests playback', (tester) async {
    final rig = Rig();
    addTearDown(rig.controller.dispose);
    rig.controller.update(rig.state);
    rig.ready();
    await tester.pump(const Duration(seconds: 10));
    expect(rig.starts, 0);
    expect(rig.controller.secondsRemaining, isNull);
  });

  testWidgets('cancelling while the map loads consumes the request', (
    tester,
  ) async {
    final rig = Rig();
    addTearDown(rig.controller.dispose);
    rig.optimize();
    rig.controller.cancel();
    rig.ready();
    await tester.pump(const Duration(seconds: 6));
    expect(rig.starts, 0);
    rig.optimize();
    expect(rig.controller.secondsRemaining, 5);
    await tester.pump(const Duration(seconds: 5));
    expect(rig.starts, 1);
  });

  for (final interruption in [
    'edit',
    'drive',
    'map reload',
    'background or covered page',
    'preference or reduced motion',
  ]) {
    testWidgets('$interruption cancels and does not resume the old request', (
      tester,
    ) async {
      final rig = Rig();
      addTearDown(rig.controller.dispose);
      rig.optimize();
      rig.ready();
      await tester.pump(const Duration(seconds: 4));
      switch (interruption) {
        case 'edit':
          rig.update(rig.state.copyWith(manualPlacement: true));
        case 'drive':
          rig.update(rig.state.copyWith(navigationActive: true));
        case 'map reload':
          rig.controller.mapReady(null);
        default:
          rig.allowed = false;
      }
      await tester.pump(const Duration(seconds: 1));
      expect(rig.starts, 0);
      rig.allowed = true;
      rig.update(
        rig.state.copyWith(manualPlacement: false, navigationActive: false),
      );
      rig.ready();
      await tester.pump(const Duration(seconds: 6));
      expect(rig.starts, 0);
    });
  }

  testWidgets('an obsolete map callback cannot start a replacement route', (
    tester,
  ) async {
    final rig = Rig();
    addTearDown(rig.controller.dispose);
    final oldRoute = rig.state.optimizedRoute;
    rig.optimize();
    rig.update(
      rig.state.copyWith(optimizedRoute: route(), previewRequestId: 2),
    );
    rig.controller.mapReady(oldRoute);
    await tester.pump(const Duration(seconds: 6));
    expect(rig.starts, 0);
    rig.ready();
    expect(rig.controller.secondsRemaining, 5);
    await tester.pump(const Duration(seconds: 5));
    expect(rig.starts, 1);
  });

  testWidgets('disabled requests stay manual after the preference is enabled', (
    tester,
  ) async {
    final rig = Rig()..allowed = false;
    addTearDown(rig.controller.dispose);
    rig.optimize();
    rig.ready();
    rig.allowed = true;
    rig.controller.update(rig.state);
    await tester.pump(const Duration(seconds: 6));
    expect(rig.starts, 0);
  });

  testWidgets('Cancel at the deadline cannot become a Play tap', (
    tester,
  ) async {
    final rig = Rig();
    addTearDown(rig.controller.dispose);
    var manualPlays = 0;
    rig.optimize();
    rig.ready();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.data,
        home: AutoPreviewScope(
          controller: rig.controller,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => rig.controller.cancel(),
            child: Scaffold(
              body: RoutePreviewActions(onPreview: () => manualPlays++),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 4900));
    final press = await tester.startGesture(
      tester.getCenter(find.text(AppStrings.cancel)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await press.up();
    await tester.pump();
    expect(rig.starts, 0);
    expect(manualPlays, 0);
    expect(find.text(AppStrings.playRoutePreview), findsOneWidget);
    await tester.tap(find.text(AppStrings.playRoutePreview));
    expect(manualPlays, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('automatic preview preference survives a reload', () async {
    SharedPreferences.setMockInitialValues({});
    await PreviewPrefs.init();
    expect(PreviewPrefs.enabled, isTrue);
    await PreviewPrefs.setEnabled(false);
    PreviewPrefs.notifier.value = true;
    await PreviewPrefs.init();
    expect(PreviewPrefs.enabled, isFalse);
  });

  for (final language in ['en', 'ar', 'fr']) {
    for (final largeText in [false, true]) {
      testWidgets(
        '$language preview actions ${largeText ? 'at 180% text' : 'visual preview'}',
        (tester) async {
          tester.view.physicalSize = Size(largeText ? 320 : 390, 680);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          AppStrings.setLocale(Locale(language));
          final rig = Rig();
          addTearDown(rig.controller.dispose);
          rig.optimize();
          rig.ready();
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.data,
              home: AutoPreviewScope(
                controller: rig.controller,
                child: MediaQuery(
                  data: MediaQueryData(
                    textScaler: TextScaler.linear(largeText ? 1.8 : 1),
                  ),
                  child: Directionality(
                    textDirection: language == 'ar'
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    child: Scaffold(
                      body: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 20),
                            RoutePreviewActions(
                              onPreview: () {},
                              onOpenGoogleMaps: () {},
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull);
          expect(find.text(AppStrings.cancel), findsOneWidget);
          if (!largeText) {
            await expectLater(
              find.byType(Scaffold),
              matchesGoldenFile('../goldens/auto_preview_$language.png'),
            );
          }
          rig.controller.cancel();
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.text(AppStrings.playRoutePreview), findsOneWidget);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
