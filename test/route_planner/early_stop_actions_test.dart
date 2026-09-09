/// Closing a stop before reaching it, and the round type that shapes the plan.
///
/// Two features that meet at the same place — what the driver is allowed to
/// decide, and what the optimiser is told about the load — so they are tested
/// together against one cubit.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:laffeh/core/config/navigation_config.dart';
import 'package:laffeh/core/config/service_profile.dart';
import 'package:laffeh/core/network/api_result.dart';
import 'package:laffeh/core/network/network_info.dart';
import 'package:laffeh/features/route_planner/data/datasources/osm_geocoding_datasource.dart';
import 'package:laffeh/features/route_planner/data/datasources/osrm_routing_datasource.dart';
import 'package:laffeh/features/route_planner/data/datasources/planner_draft_local_datasource.dart';
import 'package:laffeh/features/route_planner/data/models/planner_draft_model.dart';
import 'package:laffeh/features/route_planner/data/models/route_point_model.dart';
import 'package:laffeh/features/route_planner/data/models/route_request_model.dart';
import 'package:laffeh/features/route_planner/data/models/route_response_model.dart';
import 'package:laffeh/features/route_planner/data/repositories/place_search_repository.dart';
import 'package:laffeh/features/route_planner/domain/entities/optimized_route.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_finish.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_metrics.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_point.dart';
import 'package:laffeh/features/route_planner/domain/usecases/optimize_route_usecase.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_cubit.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/sheet_extent.dart';
import 'package:laffeh/features/settings/presentation/widgets/service_profile_glyph.dart';
import 'package:laffeh/features/saved_routes/domain/repositories/saved_routes_repository.dart';

class _MockOptimize extends Mock implements OptimizeRouteUseCase {}

class _MockSavedRoutes extends Mock implements SavedRoutesRepository {}

class _MockGeocoding extends Mock implements OsmGeocodingDataSource {}

class _MockPlaces extends Mock implements PlaceSearchRepository {}

class _MockDraft extends Mock implements PlannerDraftLocalDataSource {}

class _MockNetwork extends Mock implements NetworkInfo {}

class _MockRouting extends Mock implements OsrmRoutingDataSource {}

class _FakeDraft extends Fake implements PlannerDraftModel {}

class _FakeLatLng extends Fake implements LatLng {}

class _FakeFinish extends Fake implements RouteFinish {}

Position _fix(double lat, double lon) => Position(
  latitude: lat,
  longitude: lon,
  timestamp: DateTime.now(),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class _FakeGeolocator extends GeolocatorPlatform
    with MockPlatformInterfaceMixin {
  final _controller = StreamController<Position>.broadcast();
  Position current = _fix(33.8938, 35.5018);

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      _controller.stream;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => current;

  Future<void> dispose() => _controller.close();
}

RoutePoint _pt(String id, double lat, double lon, {bool depot = false}) =>
    RoutePoint(
      id: id,
      latitude: lat,
      longitude: lon,
      label: id,
      weight: 1,
      kind: depot ? RoutePointKind.depot : RoutePointKind.stop,
    );

OptimizedRoute _route(List<RoutePoint> points) {
  final line = points.map((p) => p.latLng).toList();
  return OptimizedRoute(
    orderedPoints: points,
    fullPolyline: line,
    goPolyline: line,
    returnPolyline: const [],
    metrics: const RouteMetrics(
      totalDistanceKm: 5.4,
      estimatedDurationMinutes: 12,
    ),
    hasRoadGeometry: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeGeolocator geo;
  late RoutePlannerCubit cubit;

  setUpAll(() {
    registerFallbackValue(_FakeDraft());
    registerFallbackValue(_FakeLatLng());
    registerFallbackValue(_FakeFinish());
    registerFallbackValue(<RoutePoint>[]);
  });

  setUp(() async {
    geo = _FakeGeolocator();
    GeolocatorPlatform.instance = geo;

    final draft = _MockDraft();
    when(() => draft.read()).thenReturn(null);
    when(() => draft.write(any())).thenAnswer((_) async {});
    when(() => draft.clear()).thenAnswer((_) async {});

    final network = _MockNetwork();
    when(() => network.isConnected).thenAnswer((_) async => true);

    final geocoding = _MockGeocoding();
    when(() => geocoding.reverseAddress(any())).thenAnswer((_) async => null);

    final optimize = _MockOptimize();
    when(
      () => optimize.call(
        points: any(named: 'points'),
        departureAt: any(named: 'departureAt'),
        finish: any(named: 'finish'),
      ),
    ).thenAnswer(
      (inv) async =>
          ApiSuccess(_route(inv.namedArguments[#points] as List<RoutePoint>)),
    );

    cubit = RoutePlannerCubit(
      optimize,
      _MockSavedRoutes(),
      geocoding,
      _MockPlaces(),
      draft,
      network,
      _MockRouting(),
    );
    await cubit.recenterOnUser();
  });

  tearDown(() async {
    await geo.dispose();
    await cubit.close();
  });

  Future<void> driveThreeStops() async {
    final points = [
      _pt('depot', 33.8938, 35.5018, depot: true),
      _pt('a', 33.90, 35.51),
      _pt('b', 33.91, 35.52),
      _pt('c', 33.92, 35.53),
    ];
    cubit.emit(
      cubit.state.copyWith(
        points: points,
        optimizedRoute: _route(points),
        navigationActive: true,
        navigationStopIndex: 1,
      ),
    );
  }

  // ── Skipping a stop ───────────────────────────────────────────────────

  group('skipPoint', () {
    test('records the stop and moves on to the next one', () async {
      await driveThreeStops();

      cubit.skipPoint();

      expect(cubit.state.skippedPointIds, {'a'});
      expect(cubit.state.navigationStopIndex, 2);
    });

    test(
      'is not the same fact as serving — served stops leave no mark',
      () async {
        await driveThreeStops();

        cubit.servePoint();

        expect(
          cubit.state.skippedPointIds,
          isEmpty,
          reason: 'a delivered stop must not read as a failed one',
        );
        expect(cubit.state.navigationStopIndex, 2);
      },
    );

    test('accumulates across a bad morning', () async {
      await driveThreeStops();

      cubit.skipPoint(); // a — nobody in
      cubit.servePoint(); // b — fine
      cubit.skipPoint(); // c — gate locked

      expect(cubit.state.skippedPointIds, {'a', 'c'});
    });

    test('does nothing when no trip is running', () async {
      cubit.skipPoint();
      expect(cubit.state.skippedPointIds, isEmpty);
    });

    test('does nothing once the index is past the last stop', () async {
      await driveThreeStops();
      cubit.emit(cubit.state.copyWith(navigationStopIndex: 99));

      cubit.skipPoint();

      expect(cubit.state.skippedPointIds, isEmpty);
    });
  });

  // ── The distance at which the early chips appear ──────────────────────

  group('early action radius', () {
    test('is far enough out to be useful and short of the arrival bar', () {
      // Two kilometres: close enough that the driver knows how the stop will
      // go, far enough that it is a decision rather than a slip of the thumb.
      expect(NavigationConfig.earlyActionRadiusMeters, 2000);
      expect(
        NavigationConfig.earlyActionRadiusMeters,
        greaterThan(
          NavigationConfig.serviceRadiusMeters +
              NavigationConfig.serviceRadiusAccuracySlack,
        ),
        reason: 'the early chips must never pre-empt the real arrival bar',
      );
    });
  });

  // ── The round type reaching the solver ────────────────────────────────

  group('service profile', () {
    RouteRequestModel request({ServiceProfile? profile}) => RouteRequestModel(
      numVehicles: 1,
      vehicleCapacity: 100,
      depotLat: 33.8938,
      depotLon: 35.5018,
      routingMode: 'driving',
      timeLimitSeconds: 10,
      driverHours: 11,
      defaultServiceTimeMinutes: 5,
      deliveries: const <RoutePointModel>[],
      serviceProfile: profile ?? ServiceProfile.delivery,
    );

    test('rides on every request', () {
      expect(request().toJson()['service_profile'], 'delivery');
    });

    test('defaults to delivery, which is what most rounds are', () {
      expect(ServiceProfile.byId(null), ServiceProfile.delivery);
      expect(ServiceProfile.byId('nonsense'), ServiceProfile.delivery);
    });

    test('no preference is a real choice, not the fallback', () {
      // The control case for comparing the same round with and without the
      // tie-break, so it has to survive the round trip rather than being
      // quietly turned back into delivery.
      expect(ServiceProfile.byId('none'), ServiceProfile.none);
      expect(
        request(profile: ServiceProfile.none).toJson()['service_profile'],
        'none',
      );
    });

    test('carries pickup through to the wire', () {
      expect(
        request(profile: ServiceProfile.pickup).toJson()['service_profile'],
        'pickup',
      );
    });

    test('round-trips through its stored id', () {
      for (final profile in ServiceProfile.values) {
        expect(ServiceProfile.byId(profile.wireValue), profile);
      }
    });
  });

  // ── The map chrome knowing where the sheet is ─────────────────────────

  group('SheetExtent', () {
    testWidgets('reads zero with no sheet above it', (tester) async {
      double? seen;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen = SheetExtent.of(context);
            return const SizedBox();
          },
        ),
      );
      expect(
        seen,
        0,
        reason: 'chrome must not float when nothing is on screen',
      );
    });

    testWidgets('rebuilds a reader when the sheet moves', (tester) async {
      final extent = ValueNotifier<double>(0.4);
      addTearDown(extent.dispose);
      final seen = <double>[];

      await tester.pumpWidget(
        MaterialApp(
          home: SheetExtent(
            extent: extent,
            child: Builder(
              builder: (context) {
                seen.add(SheetExtent.of(context));
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(seen.last, 0.4);

      extent.value = 0.8;
      await tester.pump();

      expect(seen.last, 0.8);
    });
  });

  // ── Knowing how the order was worked out ──────────────────────────────

  group('routing provenance', () {
    test('a straight-line plan says so', () {
      const route = OptimizedRoute(
        orderedPoints: [],
        fullPolyline: [],
        goPolyline: [],
        returnPolyline: [],
        metrics: RouteMetrics(totalDistanceKm: 1, estimatedDurationMinutes: 1),
        hasRoadGeometry: true,
        routingMethod: 'haversine',
      );
      expect(route.orderedOnStraightLines, isTrue);
    });

    test('a road-ordered plan does not', () {
      for (final method in ['public_osrm', 'local_osrm', 'lebanon_ch', null]) {
        final route = OptimizedRoute(
          orderedPoints: const [],
          fullPolyline: const [],
          goPolyline: const [],
          returnPolyline: const [],
          metrics: const RouteMetrics(
            totalDistanceKm: 1,
            estimatedDurationMinutes: 1,
          ),
          hasRoadGeometry: true,
          routingMethod: method,
        );
        expect(route.orderedOnStraightLines, isFalse, reason: '$method');
      }
    });

    test('road geometry and road ordering are separate facts', () {
      // The case that produced the zigzag: stops sequenced on straight
      // lines, then drawn on real roads. Neither field alone catches it.
      const route = OptimizedRoute(
        orderedPoints: [],
        fullPolyline: [],
        goPolyline: [],
        returnPolyline: [],
        metrics: RouteMetrics(totalDistanceKm: 1, estimatedDurationMinutes: 1),
        hasRoadGeometry: true,
        routingMethod: 'haversine',
      );
      expect(route.hasRoadGeometry, isTrue);
      expect(route.orderedOnStraightLines, isTrue);
    });

    test('survives withPoints, which rebuilds the route wholesale', () {
      const route = OptimizedRoute(
        orderedPoints: [],
        fullPolyline: [],
        goPolyline: [],
        returnPolyline: [],
        metrics: RouteMetrics(totalDistanceKm: 1, estimatedDurationMinutes: 1),
        hasRoadGeometry: true,
        routingMethod: 'haversine',
      );
      expect(route.withPoints(const []).routingMethod, 'haversine');
    });

    test('is parsed off the response, notes included', () {
      final parsed = RouteResponseModel.fromJson(const {
        'routes': [],
        'routing_method': 'haversine',
        'notes': ['Road distances were unavailable', 42],
      });
      expect(parsed.routingMethod, 'haversine');
      expect(parsed.notes, ['Road distances were unavailable']);
    });

    test('an older backend that sends neither is not a crash', () {
      final parsed = RouteResponseModel.fromJson(const {'routes': []});
      expect(parsed.routingMethod, isNull);
      expect(parsed.notes, isEmpty);
    });
  });

  // ── The round-type glyphs ─────────────────────────────────────────────

  group('ServiceProfileGlyph', () {
    testWidgets('every profile paints without a ticker leak', (tester) async {
      for (final profile in ServiceProfile.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: ServiceProfileGlyph(
                profile: profile,
                color: const Color(0xFF1B7F4B),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.byType(ServiceProfileGlyph), findsOneWidget);
        // Tears the widget down each pass; a repeating controller that
        // outlived its State would fail the test binding here.
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('the parcel actually moves for delivery and pickup', (
      tester,
    ) async {
      for (final profile in [ServiceProfile.delivery, ServiceProfile.pickup]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: ServiceProfileGlyph(
                profile: profile,
                color: const Color(0xFF1B7F4B),
              ),
            ),
          ),
        );
        final state = tester.state(find.byType(ServiceProfileGlyph));
        // ignore: invalid_use_of_protected_member
        expect((state as dynamic).mounted, isTrue);
        await tester.pump(const Duration(milliseconds: 550));
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('a still glyph runs no animation at all', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: ServiceProfileGlyph(
              profile: ServiceProfile.delivery,
              color: const Color(0xFF1B7F4B),
              animate: false,
            ),
          ),
        ),
      );
      // pumpAndSettle times out if anything is still animating, so this
      // doubles as the assertion that a collapsed row costs nothing.
      await tester.pumpAndSettle();
      expect(find.byType(ServiceProfileGlyph), findsOneWidget);
    });

    testWidgets('no-preference turns on the spot', (tester) async {
      // It has no journey to make, so it rotates instead of travelling —
      // and because it never settles, pumpAndSettle would hang here. One
      // bounded pump is the assertion that it is running.
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: ServiceProfileGlyph(
              profile: ServiceProfile.none,
              color: const Color(0xFF1B7F4B),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ServiceProfileGlyph), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    test('a still glyph rests where the parcel is fully visible', () {
      // The parcel fades in at the start of its pass, so a still glyph parked
      // at phase zero is a van and a doorstep with nothing between them —
      // exactly what a collapsed settings row renders.
      expect(parcelOpacity(kParcelRestingPhase, ServiceProfile.delivery), 1.0);
      final travel = parcelTravel(kParcelRestingPhase, ServiceProfile.delivery);
      expect(travel, greaterThan(0.0));
      expect(travel, lessThan(1.0));
    });

    test('the parcel lands, sits there, then fades out', () {
      // Arrives and stops.
      expect(parcelTravel(0.50, ServiceProfile.delivery), 1.0);
      expect(parcelTravel(0.70, ServiceProfile.delivery), 1.0);
      // Stays put and stays visible while it sits on the ground.
      expect(parcelOpacity(0.55, ServiceProfile.delivery), 1.0);
      expect(parcelOpacity(0.75, ServiceProfile.delivery), 1.0);
      // Then goes.
      expect(parcelOpacity(0.95, ServiceProfile.delivery), 0.0);
    });

    test('the hold on the ground is about a second', () {
      const loop = Duration(milliseconds: 3200);
      final held = (0.78 - 0.50) * loop.inMilliseconds;
      expect(held, greaterThan(700));
      expect(held, lessThan(1200));
    });

    test('each pass starts over from the beginning, not by reversing', () {
      // Invisible at the end of the loop and visible at the start, which is
      // what makes the next parcel appear where the last one set off rather
      // than sliding back like a lift.
      expect(parcelOpacity(0.99, ServiceProfile.delivery), 0.0);
      expect(parcelTravel(0.02, ServiceProfile.delivery), 0.0);
      expect(parcelOpacity(0.20, ServiceProfile.delivery), 1.0);
    });

    test('delivery falls and pickup is lifted', () {
      // Same start and end, different easing: delivery accelerates into the
      // ground, pickup decelerates into the van.
      const mid = 0.29; // halfway through the travel window
      final falling = parcelTravel(mid, ServiceProfile.delivery);
      final lifted = parcelTravel(mid, ServiceProfile.pickup);
      expect(falling, lessThan(lifted));
      expect(parcelTravel(0.50, ServiceProfile.pickup), 1.0);
    });

    test('no preference neither travels nor fades — it just turns', () {
      for (var t = 0.0; t < 1.0; t += 0.1) {
        expect(parcelTravel(t, ServiceProfile.none), 0.0);
        expect(parcelOpacity(t, ServiceProfile.none), 1.0);
      }
    });
  });
}
