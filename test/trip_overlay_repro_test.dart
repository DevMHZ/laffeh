// Reproduces the reported white screen when preview/drive activates,
// by mounting the REAL RoutePlannerPage with a faked cubit.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:laffeh/core/di/service_locator.dart';
import 'package:laffeh/core/theme/app_theme.dart';
import 'package:laffeh/features/route_planner/domain/entities/optimized_route.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_metrics.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_point.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_cubit.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_state.dart';
import 'package:laffeh/features/route_planner/presentation/pages/route_planner_page.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/route_navigation_overlay.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/route_simulation_overlay.dart';

class _FakeRouteCubit extends Cubit<RoutePlannerState>
    implements RoutePlannerCubit {
  _FakeRouteCubit(super.initialState);

  @override
  Future<void> initialize() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

RoutePoint _pt(String id, String label, double lat, double lon,
    {bool depot = false}) {
  return RoutePoint(
    id: id,
    latitude: lat,
    longitude: lon,
    label: label,
    weight: 1,
    kind: depot ? RoutePointKind.depot : RoutePointKind.stop,
  );
}

OptimizedRoute _fixtureRoute() {
  final depot = _pt('d', 'Departure', 33.51, 36.27, depot: true);
  final stops = [
    _pt('1', 'Stop 1', 33.52, 36.28),
    _pt('2', 'Stop 2', 33.53, 36.29),
  ];
  final line = [const LatLng(33.51, 36.27), const LatLng(33.53, 36.29)];
  return OptimizedRoute(
    orderedPoints: [depot, ...stops, depot],
    fullPolyline: line,
    goPolyline: line,
    returnPolyline: line,
    metrics: const RouteMetrics(
      totalDistanceKm: 12,
      estimatedDurationMinutes: 20,
    ),
    hasRoadGeometry: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    dotenv.loadFromString(envString: 'AI_ROUTE_BASE_URL=https://example.com');
  });

  tearDown(() async {
    await sl.reset();
  });

  Future<void> pumpPage(WidgetTester tester, RoutePlannerState state) async {
    final cubit = _FakeRouteCubit(state);
    sl.registerFactory<RoutePlannerCubit>(() => cubit);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const RoutePlannerPage(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('simulation overlay mounts on the real page', (tester) async {
    await pumpPage(
      tester,
      RoutePlannerState(
        status: RoutePlannerStatus.optimizedSuccess,
        optimizedRoute: _fixtureRoute(),
        simulationActive: true,
        simulationPlaying: true,
        simulationProgress: 0.4,
      ),
    );
    expect(find.byType(RouteSimulationOverlay), findsOneWidget);
    // Regression guard: the page Stack must NOT collapse when the
    // bottom sheet is replaced by the overlay (white-screen bug).
    expect(
      tester.getSize(find.byType(RouteSimulationOverlay)),
      tester.getSize(find.byType(RoutePlannerPage)),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('navigation overlay mounts on the real page', (tester) async {
    await pumpPage(
      tester,
      RoutePlannerState(
        status: RoutePlannerStatus.optimizedSuccess,
        optimizedRoute: _fixtureRoute(),
        navigationActive: true,
        navigationProgress: 0.4,
        userLocation: const LatLng(33.52, 36.28),
      ),
    );
    expect(find.byType(RouteNavigationOverlay), findsOneWidget);
    expect(
      tester.getSize(find.byType(RouteNavigationOverlay)),
      tester.getSize(find.byType(RoutePlannerPage)),
    );
    expect(tester.takeException(), isNull);
  });
}
