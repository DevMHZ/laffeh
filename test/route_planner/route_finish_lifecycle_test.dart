import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:laffeh/core/network/api_result.dart';
import 'package:laffeh/core/network/network_info.dart';
import 'package:laffeh/features/route_planner/data/datasources/osm_geocoding_datasource.dart';
import 'package:laffeh/features/route_planner/data/datasources/osrm_routing_datasource.dart';
import 'package:laffeh/features/route_planner/data/datasources/planner_draft_local_datasource.dart';
import 'package:laffeh/features/route_planner/data/models/planner_draft_model.dart';
import 'package:laffeh/features/route_planner/data/repositories/place_search_repository.dart';
import 'package:laffeh/features/route_planner/domain/entities/optimized_route.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_finish.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_metrics.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_point.dart';
import 'package:laffeh/features/route_planner/domain/usecases/optimize_route_usecase.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_cubit.dart';
import 'package:laffeh/features/saved_routes/domain/entities/saved_route.dart';
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

SavedRoute _saved(List<RoutePoint> ordered) => SavedRoute(
  id: 's1',
  name: 'yesterday',
  savedAt: DateTime(2026, 1, 1),
  routingMode: 'driving',
  orderedPoints: ordered,
  metrics: const RouteMetrics(
    totalDistanceKm: 5.4,
    estimatedDurationMinutes: 12,
  ),
  fullPolyline: ordered.map((p) => p.latLng).toList(),
  goPolyline: ordered.map((p) => p.latLng).toList(),
  returnPolyline: const [],
  hasRoadGeometry: true,
  maneuvers: const [],
);

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
    await cubit.close();
    await geo.dispose();
  });

  group('the end of the day belongs to one trip, not to the app', () {
    test('clearing the trip forgets where the day was going to end', () async {
      await cubit.setRouteFinish(
        RouteFinish.at(const LatLng(33.87, 35.49), label: 'Home'),
      );
      expect(cubit.state.finish.effectiveMode, RouteEndMode.custom);

      cubit.clearAll();

      expect(
        cubit.state.finish,
        const RouteFinish.depot(),
        reason: 'a fresh trip must not inherit the last one\'s finish point',
      );
      expect(cubit.state.departureAt, isNull);
    });

    test('loading a saved round trip resets an inherited finish', () async {
      await cubit.setRouteFinish(
        RouteFinish.at(const LatLng(33.87, 35.49), label: 'Home'),
      );

      final depot = _pt('depot', 33.89, 35.50, depot: true);
      cubit.loadSavedRoute(
        _saved([
          depot,
          _pt('a', 33.90, 35.51),
          _pt('b', 33.91, 35.52),
          depot.copyWith(id: 'depot_return'),
        ]),
      );

      expect(cubit.state.finish, const RouteFinish.depot());
    });

    test('loading a saved route that ended somewhere else restores it',
        () async {
      final depot = _pt('depot', 33.89, 35.50, depot: true);
      cubit.loadSavedRoute(
        _saved([
          depot,
          _pt('a', 33.90, 35.51),
          RoutePoint(
            id: 'depot$kFinishPointIdSuffix',
            latitude: 33.95,
            longitude: 35.60,
            label: 'Finish',
            weight: 0,
            kind: RoutePointKind.depot,
          ),
        ]),
      );

      expect(cubit.state.finish.effectiveMode, RouteEndMode.custom);
      expect(cubit.state.finish.location, const LatLng(33.95, 35.60));
    });

    test('loading a saved open route comes back as an open route', () async {
      final depot = _pt('depot', 33.89, 35.50, depot: true);
      cubit.loadSavedRoute(
        _saved([depot, _pt('a', 33.90, 35.51), _pt('b', 33.91, 35.52)]),
      );

      expect(cubit.state.finish, const RouteFinish.open());
    });
  });
}
