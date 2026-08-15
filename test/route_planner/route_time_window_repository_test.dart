import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:laffeh/core/network/api_result.dart';
import 'package:laffeh/core/network/network_info.dart';
import 'package:laffeh/features/route_planner/data/datasources/ai_route_remote_datasource.dart';
import 'package:laffeh/features/route_planner/data/datasources/osrm_routing_datasource.dart';
import 'package:laffeh/features/route_planner/data/models/route_request_model.dart';
import 'package:laffeh/features/route_planner/data/models/route_response_model.dart';
import 'package:laffeh/features/route_planner/data/repositories/route_repository_impl.dart';
import 'package:laffeh/features/route_planner/domain/entities/optimized_route.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_point.dart';
import 'package:laffeh/features/route_planner/domain/entities/stop_time_window.dart';
import 'package:mocktail/mocktail.dart';

class _MockAi extends Mock implements AiRouteRemoteDataSource {}

class _MockRouting extends Mock implements OsrmRoutingDataSource {}

class _MockNetwork extends Mock implements NetworkInfo {}

class _FakeRequest extends Fake implements RouteRequestModel {}

/// Depot in Beirut; stops fan out from it. Exact geography is irrelevant —
/// the road legs are stubbed.
final _depot = const RoutePoint(
  id: 'depot',
  latitude: 33.8938,
  longitude: 35.5018,
  label: 'Start',
  weight: 0,
  kind: RoutePointKind.depot,
);

RoutePoint _stop(String id, {StopTimeWindow? window, double lat = 33.9}) =>
    RoutePoint(
      id: id,
      latitude: lat,
      longitude: 35.55,
      label: id,
      address: id,
      weight: 10,
      kind: RoutePointKind.stop,
      timeWindow: window,
    );

/// A VRP response listing stops by address, the way the real API does.
RouteResponseModel _response(List<String> addresses) {
  return RouteResponseModel.fromJson({
    'total_distance': 20.0,
    'vehicles_used': 1,
    'routes': [
      {
        'vehicle_id': 1,
        'total_distance': 20.0,
        'total_load': 30.0,
        'stops': [
          {'address': 'DEPOT', 'lat': 33.8938, 'lon': 35.5018, 'weight': 0},
          for (final a in addresses)
            {
              'address': a,
              'lat': 33.9,
              'lon': 35.55,
              'weight': 10,
              // The deployed backend always reports 0 here.
              'arrival_time': 0,
            },
          {'address': 'DEPOT', 'lat': 33.8938, 'lon': 35.5018, 'weight': 0},
        ],
      },
    ],
  });
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeRequest());
    registerFallbackValue(const LatLng(0, 0));
  });

  late _MockAi ai;
  late _MockRouting routing;
  late _MockNetwork network;
  late RouteRepositoryImpl repo;

  /// Stubs OSRM with one leg per hop, each [minutesPerLeg] long.
  void stubRoad(int legCount, {double minutesPerLeg = 30}) {
    when(
      () => routing.fetchRoute(
        origin: any(named: 'origin'),
        destination: any(named: 'destination'),
        waypoints: any(named: 'waypoints'),
        profile: any(named: 'profile'),
        includeSteps: any(named: 'includeSteps'),
      ),
    ).thenAnswer(
      (_) async => OsrmRoute(
        polyline: const [LatLng(33.89, 35.50), LatLng(33.90, 35.55)],
        distanceMeters: 20000,
        durationSeconds: minutesPerLeg * 60 * legCount,
        legDurationsSeconds: List.filled(legCount, minutesPerLeg * 60),
      ),
    );
  }

  setUp(() {
    ai = _MockAi();
    routing = _MockRouting();
    network = _MockNetwork();
    when(() => network.isConnected).thenAnswer((_) async => true);
    repo = RouteRepositoryImpl(ai: ai, routing: routing, network: network);
  });

  OptimizedRoute expectSuccess(ApiResult<OptimizedRoute> result) {
    expect(result, isA<ApiSuccess<OptimizedRoute>>());
    return (result as ApiSuccess<OptimizedRoute>).data;
  }

  test('converts clock windows to minutes after departure in the request', () async {
    when(() => ai.optimize(any())).thenAnswer((_) async => _response(['a', 'b']));
    stubRoad(3);

    await repo.optimize(
      points: [
        _depot,
        _stop(
          'a',
          window: const StopTimeWindow(
            startMinuteOfDay: 14 * 60,
            endMinuteOfDay: 15 * 60,
          ),
        ),
        _stop('b', lat: 33.95),
      ],
      // Departing 08:00 puts the 14:00–15:00 window at 360..420.
      departureAt: DateTime(2026, 8, 14, 8, 0),
    );

    final sent = verify(() => ai.optimize(captureAny())).captured.single
        as RouteRequestModel;
    final json = sent.toJson();
    final deliveries = json['deliveries'] as List;

    final withWindow = deliveries.firstWhere((d) => d['address'] == 'a') as Map;
    expect(withWindow['time_window_start'], 360);
    expect(withWindow['time_window_end'], 420);

    // The stop without a deadline stays unconstrained rather than being
    // pinned to a window the user never asked for.
    final free = deliveries.firstWhere((d) => d['address'] == 'b') as Map;
    expect(free.containsKey('time_window_start'), isFalse);
    expect(free.containsKey('time_window_end'), isFalse);
  });

  test('raises driver_hours so a late window stays inside the working day', () async {
    when(() => ai.optimize(any())).thenAnswer((_) async => _response(['a']));
    stubRoad(2);

    await repo.optimize(
      points: [
        _depot,
        _stop(
          'a',
          window: const StopTimeWindow(
            startMinuteOfDay: 20 * 60,
            endMinuteOfDay: 21 * 60,
          ),
        ),
        _stop('b', lat: 33.95),
      ],
      // 08:00 → a 21:00 deadline is 780 minutes out, past the default
      // 8-hour (480 min) day.
      departureAt: DateTime(2026, 8, 14, 8, 0),
    );

    final sent = verify(() => ai.optimize(captureAny())).captured.single
        as RouteRequestModel;
    expect(sent.toJson()['driver_hours'], 13);
  });

  test('flags a stop the solver silently dropped, and keeps it in the route',
      () async {
    // The API answers with only 'a' — 'b' had an impossible window and was
    // discarded without appearing in unassigned_deliveries.
    when(() => ai.optimize(any())).thenAnswer((_) async => _response(['a']));
    stubRoad(3);

    final result = await repo.optimize(
      points: [
        _depot,
        _stop('a'),
        _stop(
          'b',
          lat: 33.95,
          window: const StopTimeWindow(
            startMinuteOfDay: 8 * 60,
            endMinuteOfDay: 8 * 60 + 2,
          ),
        ),
      ],
      departureAt: DateTime(2026, 8, 14, 8, 0),
    );

    final route = expectSuccess(result);
    final b = route.orderedPoints.firstWhere((p) => p.id == 'b');
    expect(b.timeWindowMissed, isTrue, reason: 'dropped stop must be flagged');

    // The user does not lose the destination just because the clock slipped.
    expect(route.orderedPoints.map((p) => p.id), contains('b'));

    final a = route.orderedPoints.firstWhere((p) => p.id == 'a');
    expect(a.timeWindowMissed, isFalse);
  });

  test('computes per-stop ETAs from the road legs, not the response', () async {
    when(() => ai.optimize(any())).thenAnswer((_) async => _response(['a', 'b']));
    // depot → a → b → depot, 30 minutes per leg.
    stubRoad(3, minutesPerLeg: 30);

    final result = await repo.optimize(
      points: [_depot, _stop('a'), _stop('b', lat: 33.95)],
      departureAt: DateTime(2026, 8, 14, 8, 0),
    );

    final route = expectSuccess(result);
    final byId = {for (final p in route.orderedPoints) p.id: p};

    // The response says arrival_time = 0 for every stop; these values can
    // only come from our own leg accounting.
    expect(byId['depot']!.etaMinutesFromDeparture, 0);
    expect(byId['a']!.etaMinutesFromDeparture, 30);
    // 30 min drive + 5 min served at 'a' + 30 min drive.
    expect(byId['b']!.etaMinutesFromDeparture, 65);
  });

  test('holds the ETA until the window opens, and delays later stops', () async {
    when(() => ai.optimize(any())).thenAnswer((_) async => _response(['a', 'b']));
    stubRoad(3, minutesPerLeg: 30);

    final result = await repo.optimize(
      points: [
        _depot,
        _stop(
          'a',
          // Reachable in 30 min, but the door doesn't open until 10:00 —
          // two hours after departure.
          window: const StopTimeWindow(
            startMinuteOfDay: 10 * 60,
            endMinuteOfDay: 11 * 60,
          ),
        ),
        _stop('b', lat: 33.95),
      ],
      departureAt: DateTime(2026, 8, 14, 8, 0),
    );

    final route = expectSuccess(result);
    final byId = {for (final p in route.orderedPoints) p.id: p};

    // Arriving at 08:30 means waiting until 10:00, not arriving early.
    expect(byId['a']!.etaMinutesFromDeparture, 120);
    expect(byId['a']!.timeWindowMissed, isFalse);
    // The wait pushes everything downstream: 120 + 5 served + 30 drive.
    expect(byId['b']!.etaMinutesFromDeparture, 155);
  });

  test('flags a stop the solver accepted but the road time overshoots', () async {
    // The solver scheduled both stops — nothing was dropped.
    when(() => ai.optimize(any())).thenAnswer((_) async => _response(['a', 'b']));
    stubRoad(3, minutesPerLeg: 90);

    final result = await repo.optimize(
      points: [
        _depot,
        _stop(
          'a',
          // Due by 09:00, but the road puts arrival at 09:30.
          window: const StopTimeWindow(
            startMinuteOfDay: 8 * 60,
            endMinuteOfDay: 9 * 60,
          ),
        ),
        _stop('b', lat: 33.95),
      ],
      departureAt: DateTime(2026, 8, 14, 8, 0),
    );

    final route = expectSuccess(result);
    final a = route.orderedPoints.firstWhere((p) => p.id == 'a');
    expect(a.etaMinutesFromDeparture, 90);
    expect(a.timeWindowMissed, isTrue);
    // Arrives 09:30 against a 09:00 deadline — the user needs the "30", not
    // just a red badge.
    expect(a.latenessMinutes, 30);
  });

  test('clears a stale lateness figure once a stop fits again', () async {
    when(() => ai.optimize(any())).thenAnswer((_) async => _response(['a', 'b']));
    stubRoad(3, minutesPerLeg: 10);

    final result = await repo.optimize(
      points: [
        _depot,
        // Carries the verdict from a previous, slower solve.
        _stop(
          'a',
          window: const StopTimeWindow(
            startMinuteOfDay: 8 * 60,
            endMinuteOfDay: 9 * 60,
          ),
        ).copyWith(timeWindowMissed: true, latenessMinutes: 45),
        _stop('b', lat: 33.95),
      ],
      departureAt: DateTime(2026, 8, 14, 8, 0),
    );

    final route = expectSuccess(result);
    final a = route.orderedPoints.firstWhere((p) => p.id == 'a');
    expect(a.timeWindowMissed, isFalse);
    expect(a.latenessMinutes, isNull);
  });

  test('leaves ETAs null when there is no road geometry to measure', () async {
    when(() => ai.optimize(any())).thenAnswer((_) async => _response(['a', 'b']));
    when(
      () => routing.fetchRoute(
        origin: any(named: 'origin'),
        destination: any(named: 'destination'),
        waypoints: any(named: 'waypoints'),
        profile: any(named: 'profile'),
        includeSteps: any(named: 'includeSteps'),
      ),
    ).thenAnswer((_) async => OsrmRoute.empty);

    final result = await repo.optimize(
      points: [_depot, _stop('a'), _stop('b', lat: 33.95)],
      departureAt: DateTime(2026, 8, 14, 8, 0),
    );

    final route = expectSuccess(result);
    final a = route.orderedPoints.firstWhere((p) => p.id == 'a');
    // No invented arrival times — the UI shows nothing rather than a guess.
    expect(a.etaMinutesFromDeparture, isNull);
    expect(a.timeWindowMissed, isFalse);
  });
}
