import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/core/network/network_info.dart';
import 'package:laffeh/features/route_planner/data/datasources/osm_geocoding_datasource.dart';
import 'package:laffeh/features/route_planner/data/repositories/place_search_repository.dart';
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
import 'package:laffeh/features/route_planner/presentation/widgets/route_summary_sheet.dart';
import 'package:laffeh/features/saved_routes/domain/repositories/saved_routes_repository.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';

class _MockOptimize extends Mock implements OptimizeRouteUseCase {}

class _MockSavedRoutes extends Mock implements SavedRoutesRepository {}

class _MockGeocoding extends Mock implements OsmGeocodingDataSource {}

class _MockPlaces extends Mock implements PlaceSearchRepository {}

class _MockDraft extends Mock implements PlannerDraftLocalDataSource {}

class _MockNetwork extends Mock implements NetworkInfo {}

class _MockRouting extends Mock implements OsrmRoutingDataSource {}

class _FakeDraft extends Fake implements PlannerDraftModel {}

const _depot = RoutePoint(
  id: 'depot',
  latitude: 33.8938,
  longitude: 35.5018,
  label: 'الانطلاق',
  weight: 0,
  kind: RoutePointKind.depot,
);

/// Asked for 12:00–12:30, would arrive 13:07 — the exact shape the user
/// complained about: a red projected time with no sign of what was wanted.
const _lateStop = RoutePoint(
  id: 'late',
  latitude: 33.9,
  longitude: 35.55,
  label: 'الصيدلية',
  weight: 10,
  kind: RoutePointKind.stop,
  timeWindow: StopTimeWindow(
    startMinuteOfDay: 12 * 60,
    endMinuteOfDay: 12 * 60 + 30,
  ),
  // Departure is 08:00, so 307 minutes out is 13:07.
  etaMinutesFromDeparture: 307,
  timeWindowMissed: true,
  latenessMinutes: 37,
);

void main() {
  setUpAll(() => registerFallbackValue(_FakeDraft()));

  late RoutePlannerCubit cubit;

  setUp(() {
    AppStrings.setLocale(const Locale('ar'));
    final draft = _MockDraft();
    when(() => draft.read()).thenReturn(null);
    when(() => draft.write(any())).thenAnswer((_) async {});

    cubit = RoutePlannerCubit(
      _MockOptimize(),
      _MockSavedRoutes(),
      _MockGeocoding(),
      _MockPlaces(),
      draft,
      _MockNetwork(),
      _MockRouting(),
    );

    const order = [_depot, _lateStop];
    cubit.emit(
      RoutePlannerState(
        status: RoutePlannerStatus.optimizedSuccess,
        points: order,
        departureAt: DateTime(2026, 8, 14, 8, 0),
        optimizedRoute: const OptimizedRoute(
          orderedPoints: order,
          fullPolyline: [LatLng(33.89, 35.50), LatLng(33.90, 35.55)],
          goPolyline: [LatLng(33.89, 35.50), LatLng(33.90, 35.55)],
          returnPolyline: [],
          metrics: RouteMetrics(
            totalDistanceKm: 12,
            estimatedDurationMinutes: 30,
          ),
          hasRoadGeometry: true,
        ),
      ),
    );
  });

  tearDown(() {
    cubit.close();
    AppStrings.setLocale(const Locale('en'));
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: const Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(child: RouteSummarySheet()),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    // Let the cubit's debounced draft write fire, so no timer is left
    // pending when the tree is torn down.
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets(
    'a late stop shows the requested time next to the projected one',
    (tester) async {
      await pumpSheet(tester);

      // The projected arrival — this part already worked.
      expect(find.text('1:07 PM'), findsWidgets);
      // The time the user actually asked for. This is what used to vanish:
      // the deadline was replaced by the lateness text precisely when the
      // stop ran late, leaving a red clock with nothing to compare against.
      expect(find.text('12:30 PM'), findsWidgets);
      // Both are labelled so neither can be mistaken for the other.
      expect(find.text(AppStrings.expectedArrival), findsWidgets);
      expect(find.text(AppStrings.requiredArrival), findsWidgets);
      // And the size of the gap.
      expect(find.text(AppStrings.lateByMinutes(37)), findsWidgets);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an on-time stop still shows its deadline', (tester) async {
    const onTime = RoutePoint(
      id: 'ok',
      latitude: 33.9,
      longitude: 35.55,
      label: 'المستودع',
      weight: 10,
      kind: RoutePointKind.stop,
      timeWindow: StopTimeWindow(
        startMinuteOfDay: 12 * 60,
        endMinuteOfDay: 12 * 60 + 30,
      ),
      etaMinutesFromDeparture: 200,
    );
    const order = [_depot, onTime];
    cubit.emit(
      cubit.state.copyWith(
        points: order,
        optimizedRoute: const OptimizedRoute(
          orderedPoints: order,
          fullPolyline: [LatLng(33.89, 35.50), LatLng(33.90, 35.55)],
          goPolyline: [LatLng(33.89, 35.50), LatLng(33.90, 35.55)],
          returnPolyline: [],
          metrics: RouteMetrics(),
          hasRoadGeometry: true,
        ),
      ),
    );

    await pumpSheet(tester);

    expect(find.text('11:20 AM'), findsWidgets); // 08:00 + 200 min
    expect(find.text('12:30 PM'), findsWidgets);
    // No warning banner when everything fits.
    expect(find.text(AppStrings.seeDetails), findsNothing);
  });
}
