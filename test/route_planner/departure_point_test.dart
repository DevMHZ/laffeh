import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

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

/// A geolocator whose fix can be moved between calls — the driver walking
/// away from where they planned the trip.
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

    final network = _MockNetwork();
    when(() => network.isConnected).thenAnswer((_) async => true);

    final geocoding = _MockGeocoding();
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
    await cubit.recenterOnUser();
  });

  tearDown(() async {
    await cubit.close();
    await geo.dispose();
  });

  /// Lets the auto-route future (and the address lookup ahead of it) settle.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  /// The points the last optimize call was handed.
  List<RoutePoint> lastSolved() =>
      verify(
            () => optimize.call(
              points: captureAny(named: 'points'),
              departureAt: any(named: 'departureAt'),
            ),
          ).captured.last
          as List<RoutePoint>;

  group('the trip starts where the driver is, until they say otherwise', () {
    test('the default departure is the live location', () async {
      await cubit.addPoint(const LatLng(33.90, 35.51), address: 'Hamra St');
      await settle();

      expect(cubit.state.departureIsCurrentLocation, isTrue);
      expect(cubit.state.departurePoint!.id, kCurrentLocationDepotId);
    });

    test('a chosen departure replaces it and keeps the stops', () async {
      await cubit.addPoint(const LatLng(33.90, 35.51), address: 'Hamra St');
      await settle();

      await cubit.setDeparture(
        const LatLng(33.85, 35.54),
        address: 'Hazmieh depot',
      );
      await settle();

      final departure = cubit.state.departurePoint!;
      expect(departure.id, kCustomDepotId);
      expect(departure.latitude, 33.85);
      expect(departure.address, 'Hazmieh depot');
      expect(cubit.state.departureIsCurrentLocation, isFalse);
      // The destination is untouched, and the trip is still a navigator.
      expect(cubit.state.destinationCount, 1);
      expect(cubit.state.isSingleDestination, isTrue);
    });

    test('choosing one re-routes from there, quietly', () async {
      await cubit.addPoint(const LatLng(33.90, 35.51), address: 'Hamra St');
      await settle();
      clearInteractions(optimize);

      await cubit.setDeparture(const LatLng(33.85, 35.54));
      await settle();

      expect(cubit.state.hasOptimizedRoute, isTrue);
      expect(cubit.state.isOptimizing, isFalse);
      expect(lastSolved().firstWhere((p) => p.isDepot).latitude, 33.85);
    });

    test(
      'optimizing does not drag a chosen departure to the new fix',
      () async {
        await cubit.addPoint(const LatLng(33.90, 35.51), address: 'Hamra St');
        await settle();
        await cubit.setDeparture(const LatLng(33.85, 35.54));
        await settle();

        // The driver moves after choosing where the trip starts.
        geo.current = _fix(34.10, 35.70);
        await cubit.recenterOnUser();
        clearInteractions(optimize);

        await cubit.optimize();

        final solvedDepot = lastSolved().firstWhere((p) => p.isDepot);
        expect(solvedDepot.latitude, 33.85);
        expect(solvedDepot.longitude, 35.54);
      },
    );

    test('the automatic departure does follow the driver', () async {
      await cubit.addPoint(const LatLng(33.90, 35.51), address: 'Hamra St');
      await settle();

      geo.current = _fix(34.10, 35.70);
      await cubit.recenterOnUser();
      clearInteractions(optimize);

      await cubit.optimize();

      expect(lastSolved().firstWhere((p) => p.isDepot).latitude, 34.10);
    });

    test('handing it back restores the live location', () async {
      await cubit.addPoint(const LatLng(33.90, 35.51), address: 'Hamra St');
      await settle();
      await cubit.setDeparture(const LatLng(33.85, 35.54));
      await settle();

      cubit.useCurrentLocationAsDeparture();
      await settle();

      expect(cubit.state.departureIsCurrentLocation, isTrue);
      expect(cubit.state.departurePoint!.id, kCurrentLocationDepotId);
      expect(cubit.state.destinationCount, 1);
    });
  });

  group('a driver who already knows they want several stops', () {
    test('saying so up front opens the planner on the first point', () async {
      cubit.beginMultiStopTrip();
      await cubit.addPoint(const LatLng(33.90, 35.51), address: 'Hamra St');
      await settle();

      expect(cubit.state.destinationCount, 1);
      // One destination, but the planner shape — because they asked for it.
      expect(cubit.state.isSingleDestination, isFalse);
    });

    test('changing their mind hands the navigator card back', () async {
      cubit.beginMultiStopTrip();
      await cubit.addPoint(const LatLng(33.90, 35.51), address: 'Hamra St');
      await settle();

      cubit.endMultiStopTrip();

      expect(cubit.state.multiStopIntent, isFalse);
      expect(cubit.state.isSingleDestination, isTrue);
    });

    test('a second destination outlives the declaration', () async {
      cubit.beginMultiStopTrip();
      await cubit.addPoint(const LatLng(33.90, 35.51), address: 'Hamra St');
      await settle();
      await cubit.addPoint(const LatLng(33.91, 35.52), address: 'Mar Mikhael');
      await settle();

      cubit.endMultiStopTrip();

      // The trip *is* multi-stop now; the flag was only ever about the shape
      // before the second stop arrived.
      expect(cubit.state.isSingleDestination, isFalse);
    });

    test('clearing the trip clears the declaration with it', () async {
      cubit.beginMultiStopTrip();
      await cubit.addPoint(const LatLng(33.90, 35.51), address: 'Hamra St');
      await settle();

      cubit.clearAll();

      expect(cubit.state.multiStopIntent, isFalse);
      expect(cubit.state.points, isEmpty);
    });
  });
}
