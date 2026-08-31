import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax/iconsax.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';

import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/core/network/network_info.dart';
import 'package:laffeh/core/theme/app_theme.dart';
import 'package:laffeh/core/widgets/whatsapp_glyph.dart';
import 'package:laffeh/features/route_planner/data/datasources/osm_geocoding_datasource.dart';
import 'package:laffeh/features/route_planner/data/datasources/osrm_routing_datasource.dart';
import 'package:laffeh/features/route_planner/data/datasources/planner_draft_local_datasource.dart';
import 'package:laffeh/features/route_planner/data/models/planner_draft_model.dart';
import 'package:laffeh/features/route_planner/domain/entities/optimized_route.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_metrics.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_point.dart';
import 'package:laffeh/features/route_planner/data/repositories/place_search_repository.dart';
import 'package:laffeh/features/route_planner/domain/usecases/optimize_route_usecase.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_cubit.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_state.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/route_navigation_overlay.dart';
import 'package:laffeh/features/saved_routes/domain/repositories/saved_routes_repository.dart';

/// Reaching the customer from inside drive mode.
///
/// The gap this closes was total: the stop's number was on the stop the
/// whole time, and the only way to it was to end the drive. So what these
/// check is presence, not prettiness — that the two controls are on screen
/// for the stop being driven to, and absent when there is nobody to ring.

class _MockOptimize extends Mock implements OptimizeRouteUseCase {}

class _MockSavedRoutes extends Mock implements SavedRoutesRepository {}

class _MockGeocoding extends Mock implements OsmGeocodingDataSource {}

class _MockPlaces extends Mock implements PlaceSearchRepository {}

class _MockDraft extends Mock implements PlannerDraftLocalDataSource {}

class _MockNetwork extends Mock implements NetworkInfo {}

class _MockRouting extends Mock implements OsrmRoutingDataSource {}

class _FakeDraft extends Fake implements PlannerDraftModel {}

class _FakeRouteCubit extends Cubit<RoutePlannerState>
    implements RoutePlannerCubit {
  _FakeRouteCubit(super.initialState);

  @override
  bool get debugDriveSimActive => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

RoutePoint _pt(
  String id,
  String label,
  double lat,
  double lon, {
  bool depot = false,
  String? phone,
}) => RoutePoint(
  id: id,
  latitude: lat,
  longitude: lon,
  label: label,
  weight: 1,
  kind: depot ? RoutePointKind.depot : RoutePointKind.stop,
  phone: phone,
);

OptimizedRoute _route({String? firstStopPhone}) {
  final depot = _pt('d', 'Departure', 33.51, 36.27, depot: true);
  final line = [const LatLng(33.51, 36.27), const LatLng(33.55, 36.31)];
  return OptimizedRoute(
    orderedPoints: [
      depot,
      _pt('1', 'Stop 1', 33.52, 36.28, phone: firstStopPhone),
      _pt('2', 'Stop 2', 33.53, 36.29),
      depot.copyWith(id: 'd_return'),
    ],
    fullPolyline: line,
    goPolyline: line,
    returnPolyline: line,
    metrics: const RouteMetrics(
      totalDistanceKm: 24.6,
      estimatedDurationMinutes: 38,
    ),
    hasRoadGeometry: true,
  );
}

Widget _harness(RoutePlannerState state) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.data,
  home: BlocProvider<RoutePlannerCubit>.value(
    value: _FakeRouteCubit(state),
    child: Scaffold(
      body: Stack(children: [RouteNavigationOverlay(onOpenGoogleMaps: () {})]),
    ),
  ),
);

RoutePlannerState _driving(
  OptimizedRoute route, {
  int stopIndex = 1,
  bool arrived = false,
}) => RoutePlannerState(
  status: RoutePlannerStatus.optimizedSuccess,
  optimizedRoute: route,
  navigationActive: true,
  navigationProgress: 0.2,
  navigationStopIndex: stopIndex,
  navigationArrived: arrived,
  userLocation: const LatLng(33.515, 36.275),
  navigationSpeedMps: arrived ? 0 : 11.2,
);

void main() {
  // mocktail needs a real PlannerDraftModel to stand in for `any()`.
  setUpAll(() => registerFallbackValue(_FakeDraft()));

  setUp(() => AppStrings.setLocale(const Locale('en')));

  testWidgets('the stop being driven to can be reached, both ways', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _harness(_driving(_route(firstStopPhone: '+963944123456'))),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(AppStrings.stopWhatsapp), findsOneWidget);
    expect(find.text(AppStrings.stopCall), findsOneWidget);
  });

  testWidgets('a stop with no number offers nothing to press', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(_driving(_route())));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(AppStrings.stopWhatsapp), findsNothing);
    expect(find.text(AppStrings.stopCall), findsNothing);
  });

  testWidgets('the contact follows the target, not the trip', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // Stop 1 has the number; the driver has already served it and is on
    // their way to stop 2, who has none. Showing stop 1's buttons here
    // would dial the wrong customer.
    await tester.pumpWidget(
      _harness(_driving(_route(firstStopPhone: '+963944123456'), stopIndex: 2)),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // The name appears on the pill and again on the timeline strip.
    expect(find.text('Stop 2'), findsAtLeastNWidgets(1));
    expect(find.text(AppStrings.stopCall), findsNothing);
  });

  testWidgets('the leg home offers no one to ring', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _harness(_driving(_route(firstStopPhone: '+963944123456'), stopIndex: 3)),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(AppStrings.stopCall), findsNothing);
  });

  // ── Arrival ────────────────────────────────────────────────────────────
  //
  // The moment the driver actually asked about. Everything collapses to one
  // row — serve, and the two ways to reach the customer as bare circles —
  // and the pill above gives its own pair up, because two identical sets of
  // buttons on one screen is worse than none.

  testWidgets('arriving puts serve and contact on one row', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _harness(
        _driving(_route(firstStopPhone: '+963944123456'), arrived: true),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(AppStrings.pointServed), findsOneWidget);
    // Glyphs, not words: the circles carry no label at the stop.
    expect(find.byType(WhatsappGlyph), findsOneWidget);
    expect(find.byIcon(Iconsax.call), findsOneWidget);
    expect(find.text(AppStrings.stopWhatsapp), findsNothing);
    expect(find.text(AppStrings.stopCall), findsNothing);
    // Nothing recites the number back at a driver standing at the door.
    expect(find.text('+963944123456'), findsNothing);
  });

  testWidgets('arriving at a stop with no number says nothing about it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(_driving(_route(), arrived: true)));
    await tester.pump(const Duration(milliseconds: 400));

    // Most stops carry no contact. The HUD used to answer that with a card
    // explaining the absence and a button opening a keypad — a paragraph
    // and a keyboard, in a vehicle, for the common case.
    expect(find.text(AppStrings.stopPhoneAdd), findsNothing);
    expect(find.byType(WhatsappGlyph), findsNothing);
    expect(find.byIcon(Iconsax.call), findsNothing);
    // The one thing that does belong there is still there.
    expect(find.text(AppStrings.pointServed), findsOneWidget);
  });

  testWidgets('arriving back at the depot ends the trip, alone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _harness(
        _driving(
          _route(firstStopPhone: '+963944123456'),
          stopIndex: 3,
          arrived: true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(WhatsappGlyph), findsNothing);
    expect(find.byIcon(Iconsax.call), findsNothing);
  });

  // ── The write-through that makes the in-drive "add a number" work ──────

  group('a number added mid-drive reaches the route being driven', () {
    late RoutePlannerCubit cubit;

    setUp(() {
      final draft = _MockDraft();
      when(() => draft.read()).thenReturn(null);
      when(() => draft.write(any())).thenAnswer((_) async {});
      final network = _MockNetwork();
      when(() => network.isConnected).thenAnswer((_) async => false);

      cubit = RoutePlannerCubit(
        _MockOptimize(),
        _MockSavedRoutes(),
        _MockGeocoding(),
        _MockPlaces(),
        draft,
        network,
        _MockRouting(),
      );
    });

    tearDown(() => cubit.close());

    test('setPointPhone patches the solved route, not just the plan', () {
      final route = _route();
      final stop = route.orderedPoints[1];
      cubit.emit(
        cubit.state.copyWith(
          points: route.orderedPoints,
          optimizedRoute: route,
        ),
      );

      cubit.setPointPhone(stop.id, '+963944123456');

      // The HUD reads the *route*, so a plan-only edit would leave the card
      // it was opened from exactly as empty as before.
      expect(
        cubit.state.optimizedRoute!.orderedPoints[1].phone,
        '+963944123456',
      );
      expect(cubit.state.points[1].phone, '+963944123456');
    });

    test('clearing it clears both as well', () {
      final route = _route(firstStopPhone: '+963944123456');
      cubit.emit(
        cubit.state.copyWith(
          points: route.orderedPoints,
          optimizedRoute: route,
        ),
      );

      cubit.setPointPhone(route.orderedPoints[1].id, '');

      expect(cubit.state.optimizedRoute!.orderedPoints[1].phone, isNull);
      expect(cubit.state.points[1].phone, isNull);
    });
  });
}
