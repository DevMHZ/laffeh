// Visual previews of the single-destination (navigator) shape — the screen a
// driver sees when they just want to get to one place.
// Run: flutter test test/navigator_shape_preview_test.dart --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/core/theme/app_theme.dart';
import 'package:laffeh/features/route_planner/domain/entities/optimized_route.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_metrics.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_point.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/destination_card.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/where_to_bar.dart';

const _destination = RoutePoint(
  id: 's1',
  latitude: 33.8938,
  longitude: 35.5018,
  label: 'Stop 1',
  weight: 1,
  kind: RoutePointKind.stop,
  address: 'Rue Gouraud, Gemmayzeh, Beirut',
);

OptimizedRoute _route() => const OptimizedRoute(
  orderedPoints: [
    RoutePoint(
      id: 'd',
      latitude: 33.88,
      longitude: 35.49,
      label: 'Departure',
      weight: 0,
      kind: RoutePointKind.depot,
    ),
    _destination,
  ],
  fullPolyline: [LatLng(33.88, 35.49), LatLng(33.8938, 35.5018)],
  goPolyline: [LatLng(33.88, 35.49), LatLng(33.8938, 35.5018)],
  returnPolyline: [],
  metrics: RouteMetrics(totalDistanceKm: 5.4, estimatedDurationMinutes: 12),
  hasRoadGeometry: true,
);

Future<void> _loadFonts() async {
  final loader = FontLoader('Almarai')
    ..addFont(rootBundle.load('assets/fonts/Almarai-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Almarai-Bold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Almarai-ExtraBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Almarai-Light.ttf'));
  await loader.load();
}

/// The card and the bar both float over the live map, so they are previewed
/// over a flat stand-in for it rather than on a blank page.
Widget _overMap(Widget child, {required TextDirection direction}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.data,
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(
                child: ColoredBox(color: Color(0xFFDFE7DA)),
              ),
              Align(alignment: Alignment.bottomCenter, child: child),
            ],
          ),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await _loadFonts();
  });

  tearDown(() => AppStrings.setLocale(const Locale('en')));

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    // Clear the previous preview off the raster before laying out at this
    // size, otherwise its bottom strip rides along into the capture.
    await tester.pumpWidget(const SizedBox.shrink());
  }

  testWidgets('empty map — where to?', (tester) async {
    await phone(tester);
    await tester.pumpWidget(
      _overMap(
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 30),
          child: WhereToBar(
            onSearch: () {},
            onPickOnMap: () {},
            onGoogleMaps: () {},
            onWhatsapp: () {},
            onPlanMultiStop: () {},
            onExitMultiStop: () {},
          ),
        ),
        direction: TextDirection.ltr,
      ),
    );
    await tester.pumpAndSettle();
    // A second frame at the new view size: the first one can still carry the
    // previous test's raster into the capture.
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/where_to_empty_state.png'),
    );
  });

  testWidgets('empty map — where to?, ar', (tester) async {
    AppStrings.setLocale(const Locale('ar'));
    await phone(tester);
    await tester.pumpWidget(
      _overMap(
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 30),
          child: WhereToBar(
            onSearch: () {},
            onPickOnMap: () {},
            onGoogleMaps: () {},
            onWhatsapp: () {},
            onPlanMultiStop: () {},
            onExitMultiStop: () {},
          ),
        ),
        direction: TextDirection.rtl,
      ),
    );
    await tester.pumpAndSettle();
    // A second frame at the new view size: the first one can still carry the
    // previous test's raster into the capture.
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/where_to_empty_state_ar.png'),
    );
  });

  testWidgets('one destination — routed', (tester) async {
    await phone(tester);
    await tester.pumpWidget(
      _overMap(
        DestinationCard(
          destination: _destination,
          route: _route(),
          routing: false,
          // Pinned so the arrival clock is the same on every run.
          departureAt: DateTime(2026, 1, 1, 9, 0),
          onGo: () {},
          onAddAnotherStop: () {},
          onChangeDestination: () {},
          onChangeDeparture: () {},
        ),
        direction: TextDirection.ltr,
      ),
    );
    await tester.pumpAndSettle();
    // A second frame at the new view size: the first one can still carry the
    // previous test's raster into the capture.
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/destination_card.png'),
    );
  });

  testWidgets('one destination — routed, ar', (tester) async {
    AppStrings.setLocale(const Locale('ar'));
    await phone(tester);
    await tester.pumpWidget(
      _overMap(
        DestinationCard(
          destination: _destination,
          route: _route(),
          routing: false,
          // Pinned so the arrival clock is the same on every run.
          departureAt: DateTime(2026, 1, 1, 9, 0),
          onGo: () {},
          onAddAnotherStop: () {},
          onChangeDestination: () {},
          onChangeDeparture: () {},
        ),
        direction: TextDirection.rtl,
      ),
    );
    await tester.pumpAndSettle();
    // A second frame at the new view size: the first one can still carry the
    // previous test's raster into the capture.
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/destination_card_ar.png'),
    );
  });

  testWidgets('one destination — name not yet resolved', (tester) async {
    AppStrings.setLocale(const Locale('ar'));
    await phone(tester);
    await tester.pumpWidget(
      _overMap(
        DestinationCard(
          // No address yet: the point's own name stands in, and for a lone
          // destination that name is "the destination" — never "stop 1".
          destination: _destination.copyWith(
            clearAddress: true,
            label: AppStrings.destinationTitle,
          ),
          route: _route(),
          routing: false,
          departureAt: DateTime(2026, 1, 1, 9, 0),
          onGo: () {},
          onAddAnotherStop: () {},
          onChangeDestination: () {},
          onChangeDeparture: () {},
        ),
        direction: TextDirection.rtl,
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/destination_card_unnamed_ar.png'),
    );
  });

  // The driver said up front that this trip has several stops: same ways in,
  // and the screen says the mode back to them rather than switching silently.
  testWidgets('empty map — multi-stop declared, ar', (tester) async {
    AppStrings.setLocale(const Locale('ar'));
    await phone(tester);
    await tester.pumpWidget(
      _overMap(
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 30),
          child: WhereToBar(
            multiStop: true,
            onSearch: () {},
            onPickOnMap: () {},
            onGoogleMaps: () {},
            onWhatsapp: () {},
            onPlanMultiStop: () {},
            onExitMultiStop: () {},
          ),
        ),
        direction: TextDirection.rtl,
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/where_to_multi_stop_ar.png'),
    );
  });

  // The trip does not start where the driver is standing — a dispatcher
  // planning from a desk, or a shift that starts at the warehouse. The card
  // names the place instead of the default.
  testWidgets('one destination — departure chosen, ar', (tester) async {
    AppStrings.setLocale(const Locale('ar'));
    await phone(tester);
    await tester.pumpWidget(
      _overMap(
        DestinationCard(
          destination: _destination,
          route: _route(),
          routing: false,
          departureAt: DateTime(2026, 1, 1, 9, 0),
          departureFrom: const RoutePoint(
            id: 'depot_custom',
            latitude: 33.87,
            longitude: 35.51,
            label: 'Departure',
            weight: 0,
            kind: RoutePointKind.depot,
            address: 'مستودع الحازمية',
          ),
          onGo: () {},
          onAddAnotherStop: () {},
          onChangeDestination: () {},
          onChangeDeparture: () {},
        ),
        direction: TextDirection.rtl,
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/destination_card_departure_ar.png'),
    );
  });

  testWidgets('one destination — still finding the way', (tester) async {
    await phone(tester);
    await tester.pumpWidget(
      _overMap(
        DestinationCard(
          destination: _destination,
          route: null,
          routing: true,
          onGo: () {},
          onAddAnotherStop: () {},
          onChangeDestination: () {},
          onChangeDeparture: () {},
        ),
        direction: TextDirection.ltr,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/destination_card_routing.png'),
    );
  });
}
