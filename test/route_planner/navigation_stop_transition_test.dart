import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:laffeh/core/network/network_info.dart';
import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/core/config/navigation_config.dart';
import 'package:laffeh/core/utils/polyline_utils.dart';
import 'package:laffeh/core/utils/distance_utils.dart';
import 'package:laffeh/features/route_planner/data/datasources/osm_geocoding_datasource.dart';
import 'package:laffeh/features/route_planner/data/datasources/osrm_routing_datasource.dart';
import 'package:laffeh/features/route_planner/data/datasources/planner_draft_local_datasource.dart';
import 'package:laffeh/features/route_planner/data/models/planner_draft_model.dart';
import 'package:laffeh/features/route_planner/data/repositories/place_search_repository.dart';
import 'package:laffeh/features/route_planner/domain/entities/optimized_route.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_maneuver.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_metrics.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_point.dart';
import 'package:laffeh/features/route_planner/domain/usecases/optimize_route_usecase.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_cubit.dart';
import 'package:laffeh/features/route_planner/presentation/utils/navigation_instructions.dart';
import 'package:laffeh/features/saved_routes/domain/repositories/saved_routes_repository.dart';

class _Optimize extends Mock implements OptimizeRouteUseCase {}

class _Saved extends Mock implements SavedRoutesRepository {}

class _Geocoding extends Mock implements OsmGeocodingDataSource {}

class _Places extends Mock implements PlaceSearchRepository {}

class _Draft extends Mock implements PlannerDraftLocalDataSource {}

class _Network extends Mock implements NetworkInfo {}

class _Routing extends Mock implements OsrmRoutingDataSource {}

class _DraftValue extends Fake implements PlannerDraftModel {}

Position fix(LatLng p) => Position(
  latitude: p.latitude,
  longitude: p.longitude,
  timestamp: DateTime.now(),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 5,
  speed: 0,
  speedAccuracy: 0,
);

class _Gps extends GeolocatorPlatform with MockPlatformInterfaceMixin {
  final fixes = StreamController<Position>.broadcast();
  LatLng current = const LatLng(33.89, 35.50);
  Future<Position> Function()? request;
  int requests = 0;
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    requests++;
    return request == null ? fix(current) : await request!();
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => null;
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      fixes.stream;
  Future<void> at(LatLng p) async {
    current = p;
    fixes.add(fix(p));
    await Future<void>.delayed(Duration.zero);
  }
}

RoutePoint point(String id, double lat, {bool depot = false}) => RoutePoint(
  id: id,
  latitude: lat,
  longitude: 35.50,
  label: id,
  weight: 1,
  kind: depot ? RoutePointKind.depot : RoutePointKind.stop,
);

OptimizedRoute trip() {
  final depot = point('Departure', 33.89, depot: true);
  final first = point('Stop 1', 33.892);
  final second = point('Stop 2', 33.894);
  final path = [
    depot.latLng,
    first.latLng,
    const LatLng(33.893, 35.5),
    second.latLng,
    const LatLng(33.894, 35.502),
    const LatLng(33.89, 35.502),
    depot.latLng,
  ];
  return OptimizedRoute(
    orderedPoints: [depot, first, second, depot],
    fullPolyline: path,
    goPolyline: path.take(4).toList(),
    returnPolyline: path.skip(3).toList(),
    metrics: const RouteMetrics(
      totalDistanceKm: 1.3,
      estimatedDurationMinutes: 5,
    ),
    hasRoadGeometry: true,
    maneuvers: [
      RouteManeuver(
        kind: ManeuverKind.arrive,
        latitude: first.latitude,
        longitude: first.longitude,
      ),
      const RouteManeuver(
        kind: ManeuverKind.turnRight,
        latitude: 33.893,
        longitude: 35.5,
        roadName: 'Next street',
      ),
      RouteManeuver(
        kind: ManeuverKind.arrive,
        latitude: second.latitude,
        longitude: second.longitude,
      ),
      const RouteManeuver(
        kind: ManeuverKind.turnLeft,
        latitude: 33.894,
        longitude: 35.502,
        roadName: 'Home street',
      ),
      RouteManeuver(
        kind: ManeuverKind.arrive,
        latitude: depot.latitude,
        longitude: depot.longitude,
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Gps gps;
  late _Routing routing;
  late RoutePlannerCubit cubit;
  late OptimizedRoute route;
  setUpAll(() {
    registerFallbackValue(_DraftValue());
    registerFallbackValue(const LatLng(0, 0));
  });
  setUp(() async {
    gps = _Gps();
    GeolocatorPlatform.instance = gps;
    final draft = _Draft();
    when(() => draft.write(any())).thenAnswer((_) async {});
    final network = _Network();
    when(() => network.isConnected).thenAnswer((_) async => false);
    routing = _Routing();
    cubit = RoutePlannerCubit(
      _Optimize(),
      _Saved(),
      _Geocoding(),
      _Places(),
      draft,
      network,
      routing,
    );
    route = trip();
    cubit.emit(
      cubit.state.copyWith(
        points: route.orderedPoints,
        optimizedRoute: route,
        isOffline: true,
      ),
    );
    await cubit.startNavigation();
  });
  tearDown(() async {
    await cubit.close();
    await gps.fixes.close();
  });

  test(
    'offline arrival advances target, distance and instructions atomically',
    () async {
      await gps.at(const LatLng(33.89199, 35.5)); // ~1m before arrival maneuver
      expect(cubit.state.navigationArrived, isTrue);
      final transitions = <int>[];
      final sub = cubit.stream.listen(
        (s) => transitions.add(s.navigationStopIndex),
      );
      cubit.servePoint(expectedStopIndex: 1, expectedRoute: route);
      await Future<void>.delayed(Duration.zero);
      expect(transitions, [2]);
      expect(cubit.state.navigationArrived, isFalse);
      expect(cubit.state.navigationStopDistanceMeters, greaterThan(200));
      expect(cubit.state.navigationStopRouteDistanceMeters, greaterThan(200));
      expect(
        NavigationInstructions.compute(cubit.state)?.roadName,
        'Next street',
      );
      await gps.at(const LatLng(33.89199, 35.5));
      expect(cubit.state.navigationArrived, isFalse);
      expect(cubit.state.navigationStopIndex, 2);
      verifyNever(
        () => routing.fetchRoute(
          origin: any(named: 'origin'),
          destination: any(named: 'destination'),
          waypoints: any(named: 'waypoints'),
          includeSteps: any(named: 'includeSteps'),
        ),
      );
      await sub.cancel();
    },
  );

  test(
    'repeat taps and callbacks for an old stop cannot consume the next one',
    () {
      cubit.servePoint(expectedStopIndex: 1, expectedRoute: route);
      cubit.skipPoint(expectedStopIndex: 1, expectedRoute: route);
      cubit.servePoint(expectedStopIndex: 2, expectedRoute: route);
      expect(cubit.state.navigationStopIndex, 2);
      expect(cubit.state.skippedPointIds, isEmpty);
    },
  );

  test(
    'failed delivery remains distinct through return and trip completion',
    () async {
      cubit.servePoint();
      await gps.at(route.orderedPoints[2].latLng);
      cubit.skipPoint();
      expect(cubit.state.navigationStopIndex, 3);
      expect(cubit.state.skippedPointIds, {'Stop 2'});
      expect(cubit.state.navigationArrived, isFalse);
      expect(
        NavigationInstructions.compute(cubit.state)?.roadName,
        'Home street',
      );
      cubit.servePoint();
      expect(cubit.state.navigationActive, isFalse);
      expect(cubit.state.navigationProgress, 1);
      expect(cubit.state.skippedPointIds, {'Stop 2'});
      cubit.skipPoint();
      expect(cubit.state.skippedPointIds, {'Stop 2'});
    },
  );

  test(
    'fresh drive clears prior outcomes and all stale distance channels',
    () async {
      cubit.skipPoint();
      cubit.stopNavigation();
      await cubit.startNavigation();
      expect(cubit.state.navigationStopIndex, 1);
      expect(cubit.state.navigationProgress, lessThan(.01));
      expect(cubit.state.skippedPointIds, isEmpty);
      expect(cubit.state.navigationStopRouteDistanceMeters, isNull);
    },
  );

  test('an in-flight reroute for a served stop is discarded', () async {
    final pending = Completer<OsrmRoute>();
    when(
      () => routing.fetchRoute(
        origin: any(named: 'origin'),
        destination: any(named: 'destination'),
        waypoints: any(named: 'waypoints'),
        includeSteps: any(named: 'includeSteps'),
      ),
    ).thenAnswer((_) => pending.future);
    cubit.emit(cubit.state.copyWith(isOffline: false));
    for (var i = 0; i < 6; i++) {
      await gps.at(LatLng(33.89 + i * .0003, 35.505));
    }
    expect(cubit.state.isRerouting, isTrue);
    cubit.servePoint();
    pending.complete(
      OsrmRoute(
        polyline: const [LatLng(33.89, 35.505), LatLng(33.892, 35.5)],
        distanceMeters: 800,
        durationSeconds: 100,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(identical(cubit.state.optimizedRoute, route), isTrue);
    expect(cubit.state.navigationStopIndex, 2);
    expect(cubit.state.navigationArrived, isFalse);
    expect(cubit.state.isRerouting, isFalse);
  });
  test(
    'early skip retains necessary turns but retires the old arrival',
    () async {
      final changed = OptimizedRoute(
        orderedPoints: route.orderedPoints,
        fullPolyline: route.fullPolyline,
        goPolyline: route.goPolyline,
        returnPolyline: route.returnPolyline,
        metrics: route.metrics,
        hasRoadGeometry: true,
        maneuvers: [
          const RouteManeuver(
            kind: ManeuverKind.turnRight,
            latitude: 33.891,
            longitude: 35.5,
            roadName: 'Required before skipped stop',
          ),
          ...route.maneuvers,
        ],
      );
      cubit.stopNavigation();
      cubit.emit(cubit.state.copyWith(optimizedRoute: changed));
      await cubit.startNavigation();
      cubit.skipPoint();
      expect(
        NavigationInstructions.compute(cubit.state)?.roadName,
        'Required before skipped stop',
      );
      await gps.at(const LatLng(33.89199, 35.5));
      expect(
        NavigationInstructions.compute(cubit.state)?.roadName,
        'Next street',
      );
      expect(cubit.state.navigationArrived, isFalse);
    },
  );

  test(
    'successful reroute includes the connector in stop boundaries',
    () async {
      final pending = Completer<OsrmRoute>();
      when(
        () => routing.fetchRoute(
          origin: any(named: 'origin'),
          destination: any(named: 'destination'),
          waypoints: any(named: 'waypoints'),
          includeSteps: any(named: 'includeSteps'),
        ),
      ).thenAnswer((_) => pending.future);
      cubit.emit(cubit.state.copyWith(isOffline: false));
      await gps.at(const LatLng(33.891, 35.5));
      expect(cubit.state.navigationProgress, greaterThan(0));
      for (var i = 0; i < 3; i++) {
        await gps.at(LatLng(33.891 + i * .0003, 35.505));
      }
      expect(cubit.state.isRerouting, isTrue);
      final fresh = [gps.current, ...route.fullPolyline.skip(1)];
      pending.complete(
        OsrmRoute(
          polyline: fresh,
          distanceMeters: 1800,
          durationSeconds: 300,
          maneuvers: route.maneuvers,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final rebuilt = cubit.state.optimizedRoute!;
      expect(identical(rebuilt, route), isFalse);
      expect(cubit.state.stopFractions.last, closeTo(1, 1e-9));
      expect(cubit.state.maneuverFractions.last, closeTo(1, 1e-9));
      final firstArrival = PolylineUtils.sampleAt(
        rebuilt.fullPolyline,
        cubit.state.stopFractions[1],
      )!.point;
      expect(
        DistanceUtils.haversineKm(firstArrival, route.orderedPoints[1].latLng) *
            1000,
        lessThan(2),
      );
    },
  );

  test(
    'an older GPS start failure cannot stop a newer successful drive',
    () async {
      cubit.stopNavigation();
      final pending = Completer<Position>();
      gps.request = () => pending.future;
      final previousStart = cubit.startNavigation();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.navigationStarting, isTrue);
      cubit.stopNavigation();
      gps.request = null;
      await cubit.startNavigation();
      expect(cubit.state.navigationActive, isTrue);
      pending.completeError(StateError('old request failed'));
      await previousStart;
      expect(cubit.state.navigationActive, isTrue);
      expect(cubit.state.errorMessage, isNull);
    },
  );

  test(
    'repeated start taps share the pending attempt and preserve an active drive',
    () async {
      cubit.stopNavigation();
      final fixReady = Completer<Position>();
      gps.request = () => fixReady.future;
      final before = gps.requests;
      final starting = cubit.startNavigation();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.navigationStarting, isTrue);
      await cubit.startNavigation();
      expect(gps.requests, before + 1);
      fixReady.complete(fix(gps.current));
      await starting;
      expect(cubit.state.navigationStarting, isFalse);
      expect(cubit.state.navigationActive, isTrue);
      cubit.skipPoint();
      final nextStop = cubit.state.navigationStopIndex;
      await cubit.startNavigation();
      expect(cubit.state.navigationStopIndex, nextStop);
      expect(gps.requests, before + 1);
    },
  );

  testWidgets(
    'missing simulator GPS times out visibly and the next tap can retry',
    (tester) async {
      cubit.stopNavigation();
      gps.request = () => Completer<Position>().future;
      final starting = cubit.startNavigation();
      await tester.pump();
      expect(cubit.state.navigationStarting, isTrue);
      await tester.pump(
        NavigationConfig.startFixTimeout + const Duration(seconds: 1),
      );
      await starting;
      expect(cubit.state.navigationStarting, isFalse);
      expect(cubit.state.navigationActive, isFalse);
      expect(cubit.state.errorMessage, AppStrings.errLocationTimeout);
      gps.request = null;
      await cubit.startNavigation();
      expect(cubit.state.navigationActive, isTrue);
      expect(cubit.state.errorMessage, isNull);
    },
  );

  test(
    'canceling acquisition ignores a late fix and clears waiting state',
    () async {
      cubit.stopNavigation();
      final fixReady = Completer<Position>();
      gps.request = () => fixReady.future;
      final starting = cubit.startNavigation();
      await Future<void>.delayed(Duration.zero);
      cubit.stopNavigation();
      expect(cubit.state.navigationStarting, isFalse);
      fixReady.complete(fix(gps.current));
      await starting;
      expect(cubit.state.navigationActive, isFalse);
      expect(cubit.state.errorMessage, isNull);
    },
  );

  test('offline re-optimization keeps the active cached trip intact', () async {
    final before = cubit.state;
    await cubit.reoptimizeRemaining();
    expect(cubit.state.navigationActive, isTrue);
    expect(cubit.state.navigationStopIndex, before.navigationStopIndex);
    expect(
      identical(cubit.state.optimizedRoute, before.optimizedRoute),
      isTrue,
    );
  });

  test('debug stepping waits for the driver at each arrival', () {
    for (var i = 0; i < 20; i++) {
      cubit.debugStepForward();
    }
    expect(cubit.state.navigationStopIndex, 1);
    expect(cubit.state.navigationArrived, isTrue);
    cubit.servePoint();
    for (var i = 0; i < 20; i++) {
      cubit.debugStepForward();
    }
    expect(cubit.state.navigationStopIndex, 2);
    expect(cubit.state.navigationArrived, isTrue);
  });
}
