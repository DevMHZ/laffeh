import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/network/api_result.dart';
import 'package:laffeh/core/network/network_info.dart';
import 'package:laffeh/features/route_planner/data/datasources/osm_geocoding_datasource.dart';
import 'package:laffeh/features/route_planner/data/datasources/osrm_routing_datasource.dart';
import 'package:laffeh/features/route_planner/data/datasources/planner_draft_local_datasource.dart';
import 'package:laffeh/features/route_planner/data/models/planner_draft_model.dart';
import 'package:laffeh/features/route_planner/domain/entities/optimized_route.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_metrics.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_point.dart';
import 'package:laffeh/features/route_planner/domain/entities/stop_time_window.dart';
import 'package:laffeh/features/route_planner/domain/usecases/optimize_route_usecase.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_cubit.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_state.dart';
import 'package:laffeh/features/saved_routes/domain/repositories/saved_routes_repository.dart';
import 'package:mocktail/mocktail.dart';

class _MockOptimize extends Mock implements OptimizeRouteUseCase {}

class _MockSavedRoutes extends Mock implements SavedRoutesRepository {}

class _MockGeocoding extends Mock implements OsmGeocodingDataSource {}

class _MockDraft extends Mock implements PlannerDraftLocalDataSource {}

class _MockNetwork extends Mock implements NetworkInfo {}

class _MockRouting extends Mock implements OsrmRoutingDataSource {}

class _FakeDraft extends Fake implements PlannerDraftModel {}

const _depot = RoutePoint(
  id: 'depot',
  latitude: 33.8938,
  longitude: 35.5018,
  label: 'Start',
  weight: 0,
  kind: RoutePointKind.depot,
);

/// A stop due by [dueHour]:00, arriving [lateBy] minutes past it.
RoutePoint _lateStop(String id, {required int dueHour, required int lateBy}) =>
    RoutePoint(
      id: id,
      latitude: 33.9,
      longitude: 35.55,
      label: id,
      weight: 10,
      kind: RoutePointKind.stop,
      timeWindow: StopTimeWindow(
        startMinuteOfDay: (dueHour - 1) * 60,
        endMinuteOfDay: dueHour * 60,
      ),
      timeWindowMissed: true,
      latenessMinutes: lateBy,
    );

void main() {
  setUpAll(() => registerFallbackValue(_FakeDraft()));

  late RoutePlannerCubit cubit;
  late _MockOptimize optimize;
  late _MockDraft draft;

  setUp(() {
    optimize = _MockOptimize();
    draft = _MockDraft();
    when(() => draft.read()).thenReturn(null);
    when(() => draft.write(any())).thenAnswer((_) async {});
    when(() => draft.clear()).thenAnswer((_) async {});
    when(
      () => optimize(
        points: any(named: 'points'),
        routingMode: any(named: 'routingMode'),
        departureAt: any(named: 'departureAt'),
      ),
    ).thenAnswer(
      (_) async => ApiSuccess(
        const OptimizedRoute(
          orderedPoints: [],
          fullPolyline: [],
          goPolyline: [],
          returnPolyline: [],
          metrics: RouteMetrics(),
          hasRoadGeometry: false,
        ),
      ),
    );

    cubit = RoutePlannerCubit(
      optimize,
      _MockSavedRoutes(),
      _MockGeocoding(),
      draft,
      _MockNetwork(),
      _MockRouting(),
    );
  });

  tearDown(() => cubit.close());

  void seed(List<RoutePoint> points, {DateTime? departureAt}) {
    cubit.emit(
      RoutePlannerState(
        points: points,
        departureAt: departureAt,
        status: RoutePlannerStatus.optimizedSuccess,
      ),
    );
  }

  group('requiredEarlierDepartureMinutes', () {
    test('is null when nothing runs late', () {
      seed([_depot]);
      expect(cubit.requiredEarlierDepartureMinutes, isNull);
    });

    test('takes the worst overshoot, plus slack', () {
      seed([
        _depot,
        _lateStop('a', dueHour: 10, lateBy: 12),
        _lateStop('b', dueHour: 11, lateBy: 40),
      ]);
      // Fixing the worst stop fixes the rest; +10 slack so the next solve
      // doesn't come back late by a minute.
      expect(cubit.requiredEarlierDepartureMinutes, 50);
    });
  });

  group('canDepartEarlier', () {
    test('is false when the trip leaves now — you cannot start sooner', () {
      seed([_depot, _lateStop('a', dueHour: 10, lateBy: 20)]);
      expect(cubit.state.departureAt, isNull);
      expect(cubit.canDepartEarlier, isFalse);
    });

    test('is false when the shift would land in the past', () {
      seed(
        [_depot, _lateStop('a', dueHour: 10, lateBy: 90)],
        // Leaving in 20 minutes can't absorb a 100-minute shift.
        departureAt: DateTime.now().add(const Duration(minutes: 20)),
      );
      expect(cubit.canDepartEarlier, isFalse);
    });

    test('is true when there is room to set off sooner', () {
      seed(
        [_depot, _lateStop('a', dueHour: 10, lateBy: 20)],
        departureAt: DateTime.now().add(const Duration(hours: 5)),
      );
      expect(cubit.canDepartEarlier, isTrue);
    });
  });

  group('relaxMissedTimeWindows', () {
    /// The points handed to the solver by the re-solve that follows a repair.
    /// Asserted on rather than `state.points`, because the solver's own
    /// response overwrites the working list right afterwards.
    Map<String, RoutePoint> sentPoints() {
      final captured = verify(
        () => optimize(
          points: captureAny(named: 'points'),
          routingMode: any(named: 'routingMode'),
          departureAt: any(named: 'departureAt'),
        ),
      ).captured.single as List<RoutePoint>;
      return {for (final p in captured) p.id: p};
    }

    test('pushes each deadline out by its own overshoot, plus slack', () async {
      seed([
        _depot,
        _lateStop('a', dueHour: 10, lateBy: 12),
        _lateStop('b', dueHour: 15, lateBy: 40),
      ]);

      await cubit.relaxMissedTimeWindows();

      final byId = sentPoints();
      // 10:00 + 12 late + 10 slack = 10:22
      expect(byId['a']!.timeWindow!.endMinuteOfDay, 10 * 60 + 22);
      // 15:00 + 40 late + 10 slack = 15:50
      expect(byId['b']!.timeWindow!.endMinuteOfDay, 15 * 60 + 50);

      // The verdict is cleared so the banner doesn't linger on stale data.
      expect(byId['a']!.timeWindowMissed, isFalse);
      expect(byId['a']!.latenessMinutes, isNull);
    });

    test('wraps a deadline pushed past midnight', () async {
      seed([_depot, _lateStop('a', dueHour: 23, lateBy: 55)]);

      await cubit.relaxMissedTimeWindows();

      // 23:00 + 55 + 10 = 00:05 the next day.
      expect(sentPoints()['a']!.timeWindow!.endMinuteOfDay, 5);
    });

    test('re-solves so the user sees a fixed route, not a stale one', () async {
      seed([_depot, _lateStop('a', dueHour: 10, lateBy: 12)]);

      await cubit.relaxMissedTimeWindows();

      verify(
        () => optimize(
          points: any(named: 'points'),
          routingMode: any(named: 'routingMode'),
          departureAt: any(named: 'departureAt'),
        ),
      ).called(1);
    });

    test('does nothing when no stop is late', () async {
      seed([_depot]);
      await cubit.relaxMissedTimeWindows();
      verifyNever(
        () => optimize(
          points: any(named: 'points'),
          routingMode: any(named: 'routingMode'),
          departureAt: any(named: 'departureAt'),
        ),
      );
    });
  });

  group('departEarlierToMakeWindows', () {
    test('moves the departure back by the worst overshoot and re-solves',
        () async {
      final departure = DateTime.now().add(const Duration(hours: 5));
      seed([_depot, _lateStop('a', dueHour: 10, lateBy: 25)], departureAt: departure);

      await cubit.departEarlierToMakeWindows();

      // 25 late + 10 slack = 35 minutes earlier.
      expect(
        cubit.state.departureAt,
        departure.subtract(const Duration(minutes: 35)),
      );
      verify(
        () => optimize(
          points: any(named: 'points'),
          routingMode: any(named: 'routingMode'),
          departureAt: any(named: 'departureAt'),
        ),
      ).called(1);
    });

    test('is a no-op when the trip already leaves now', () async {
      seed([_depot, _lateStop('a', dueHour: 10, lateBy: 25)]);
      await cubit.departEarlierToMakeWindows();
      expect(cubit.state.departureAt, isNull);
    });
  });
}
