import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/core/error/failures.dart';
import 'package:laffeh/core/network/api_result.dart';
import 'package:laffeh/core/network/network_info.dart';
import 'package:laffeh/features/route_planner/data/datasources/osm_geocoding_datasource.dart';
import 'package:laffeh/features/route_planner/data/repositories/place_search_repository.dart';
import 'package:laffeh/features/route_planner/data/datasources/osrm_routing_datasource.dart';
import 'package:laffeh/features/route_planner/data/datasources/planner_draft_local_datasource.dart';
import 'package:laffeh/features/route_planner/data/models/planner_draft_model.dart';
import 'package:laffeh/features/route_planner/domain/entities/optimized_route.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_metrics.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_point.dart';
import 'package:laffeh/features/route_planner/domain/usecases/optimize_route_usecase.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_cubit.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_state.dart';
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
  }) async => _fix(33.8938, 35.5018);

  Future<void> dispose() => _controller.close();
}

/// A two-point A→B result, the shape the repository returns for a single
/// destination (no solver involved, no return leg).
OptimizedRoute _directRoute(List<RoutePoint> points) {
  final depot = points.firstWhere((p) => p.isDepot);
  final stop = points.firstWhere((p) => !p.isDepot);
  final line = [depot.latLng, stop.latLng];
  return OptimizedRoute(
    orderedPoints: [depot, stop],
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
  late _MockOptimize optimize;
  late _MockGeocoding geocoding;
  late _MockNetwork network;
  late RoutePlannerCubit cubit;

  setUpAll(() {
    registerFallbackValue(_FakeDraft());
    registerFallbackValue(_FakeLatLng());
    registerFallbackValue(<RoutePoint>[]);
  });

  setUp(() async {
    geo = _FakeGeolocator();
    GeolocatorPlatform.instance = geo;

    final draft = _MockDraft();
    when(() => draft.read()).thenReturn(null);
    when(() => draft.write(any())).thenAnswer((_) async {});
    when(() => draft.clear()).thenAnswer((_) async {});

    network = _MockNetwork();
    when(() => network.isConnected).thenAnswer((_) async => true);

    geocoding = _MockGeocoding();
    when(() => geocoding.reverseAddress(any())).thenAnswer((_) async => null);

    optimize = _MockOptimize();
    when(
      () => optimize.call(
        points: any(named: 'points'),
        departureAt: any(named: 'departureAt'),
      ),
    ).thenAnswer(
      (inv) async => ApiSuccess(
        _directRoute(inv.namedArguments[#points] as List<RoutePoint>),
      ),
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
    // A known location is what makes the first dropped pin a *destination*
    // rather than the departure.
    await cubit.recenterOnUser();
  });

  tearDown(() async {
    await cubit.close();
    await geo.dispose();
  });

  /// Lets the auto-route future (and the address lookup ahead of it) settle.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('one destination is a navigator, not a plan', () {
    test('the first destination routes itself, quietly', () async {
      await cubit.addPoint(const LatLng(33.90, 35.51), address: 'Hamra St');
      await settle();

      expect(cubit.state.isSingleDestination, isTrue);
      expect(cubit.state.hasOptimizedRoute, isTrue);
      expect(cubit.state.optimizedRoute!.metrics.totalDistanceKm, 5.4);
      // Quiet means quiet: the full-screen planning animation is keyed off
      // `isOptimizing`, and it must never appear for a single destination.
      expect(cubit.state.isOptimizing, isFalse);
      expect(cubit.state.quietRouting, isFalse);
      verify(
        () => optimize.call(
          points: any(named: 'points'),
          departureAt: any(named: 'departureAt'),
        ),
      ).called(1);
    });

    test('a pin with no address waits for the lookup before routing', () async {
      when(
        () => geocoding.reverseAddress(any()),
      ).thenAnswer((_) async => 'Rue Gouraud');

      await cubit.addPoint(const LatLng(33.90, 35.51));
      await settle();
      await settle();

      // The route replaces `points`, so racing the lookup would drop the
      // address the card is about to show.
      final destination = cubit.state.points.firstWhere((p) => !p.isDepot);
      expect(destination.address, 'Rue Gouraud');
      expect(cubit.state.hasOptimizedRoute, isTrue);
    });

    test('a second destination turns the trip back into a plan', () async {
      await cubit.addPoint(const LatLng(33.90, 35.51), address: 'Hamra St');
      await settle();
      clearInteractions(optimize);

      await cubit.addPoint(const LatLng(33.91, 35.52), address: 'Mar Mikhael');
      await settle();

      expect(cubit.state.isSingleDestination, isFalse);
      expect(cubit.state.destinationCount, 2);
      // Adding a stop invalidates the old geometry, and ordering two stops is
      // the driver's call — nothing is routed behind their back.
      expect(cubit.state.hasOptimizedRoute, isFalse);
      verifyNever(
        () => optimize.call(
          points: any(named: 'points'),
          departureAt: any(named: 'departureAt'),
        ),
      );
    });

    test('offline, the card is left with its Go button', () async {
      when(() => network.isConnected).thenAnswer((_) async => false);
      when(
        () => optimize.call(
          points: any(named: 'points'),
          departureAt: any(named: 'departureAt'),
        ),
      ).thenAnswer((_) async => ApiFailure(NetworkFailure('offline')));

      await cubit.addPoint(const LatLng(33.90, 35.51), address: 'Hamra St');
      await settle();

      expect(cubit.state.hasOptimizedRoute, isFalse);
      expect(cubit.state.quietRouting, isFalse);
      // Nothing on screen had promised a route, so nothing shouts about it.
      expect(cubit.state.status, isNot(RoutePlannerStatus.optimizedFailure));
      expect(cubit.state.errorMessage, isNull);
    });
  });

  group('naming', () {
    RoutePoint destinationOf(RoutePlannerCubit c) =>
        c.state.points.firstWhere((p) => !p.isDepot);

    test('a lone destination is named, not numbered', () async {
      await cubit.addPoint(const LatLng(33.90, 35.51), address: 'Hamra St');
      await settle();

      expect(destinationOf(cubit).label, AppStrings.destinationTitle);
      expect(destinationOf(cubit).label, isNot(AppStrings.stopLabel(1)));
      // And the routed copy keeps that name — the direct route must not
      // stamp "stop 1" back over it.
      expect(
        cubit.state.optimizedRoute!.orderedPoints.last.label,
        AppStrings.destinationTitle,
      );
    });

    test('it gets its number back when a second one arrives', () async {
      await cubit.addPoint(const LatLng(33.90, 35.51), address: 'Hamra St');
      await settle();
      await cubit.addPoint(const LatLng(33.91, 35.52), address: 'Mar Mikhael');
      await settle();

      final stops = cubit.state.points.where((p) => !p.isDepot).toList();
      expect(stops.map((p) => p.label), [
        AppStrings.stopLabel(1),
        AppStrings.stopLabel(2),
      ]);
    });

    test('a name the driver brought with them is never rewritten', () async {
      await cubit.addPoint(
        const LatLng(33.90, 35.51),
        address: 'Hamra St',
        label: 'مخبز الشام',
      );
      await settle();
      expect(destinationOf(cubit).label, 'مخبز الشام');

      await cubit.addPoint(const LatLng(33.91, 35.52), address: 'Mar Mikhael');
      await settle();
      expect(
        cubit.state.points.where((p) => !p.isDepot).first.label,
        'مخبز الشام',
      );
    });
  });

  group('Go', () {
    test('drives the route that is already there', () async {
      await cubit.addPoint(const LatLng(33.90, 35.51), address: 'Hamra St');
      await settle();
      clearInteractions(optimize);

      await cubit.driveToDestination();

      expect(cubit.state.navigationActive, isTrue);
      verifyNever(
        () => optimize.call(
          points: any(named: 'points'),
          departureAt: any(named: 'departureAt'),
        ),
      );
    });

    test('routes first when the quiet attempt never landed', () async {
      when(
        () => optimize.call(
          points: any(named: 'points'),
          departureAt: any(named: 'departureAt'),
        ),
      ).thenAnswer((_) async => ApiFailure(NetworkFailure('offline')));
      await cubit.addPoint(const LatLng(33.90, 35.51), address: 'Hamra St');
      await settle();
      expect(cubit.state.hasOptimizedRoute, isFalse);

      // Signal is back by the time the driver presses Go.
      when(
        () => optimize.call(
          points: any(named: 'points'),
          departureAt: any(named: 'departureAt'),
        ),
      ).thenAnswer(
        (inv) async => ApiSuccess(
          _directRoute(inv.namedArguments[#points] as List<RoutePoint>),
        ),
      );

      await cubit.driveToDestination();

      expect(cubit.state.hasOptimizedRoute, isTrue);
      expect(cubit.state.navigationActive, isTrue);
    });
  });

  test(
    'clearing the destination empties the screen, departure included',
    () async {
      await cubit.addPoint(const LatLng(33.90, 35.51), address: 'Hamra St');
      await settle();

      cubit.clearDestination();

      expect(cubit.state.points, isEmpty);
      expect(cubit.state.hasOptimizedRoute, isFalse);
    },
  );
}
