// Visual previews of the redesigned trip flow (not regression gates).
// Run: flutter test test/trip_flow_preview_test.dart --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:laffeh/core/theme/app_colors.dart';
import 'package:laffeh/core/theme/app_theme.dart';
import 'package:laffeh/features/route_planner/domain/entities/optimized_route.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_metrics.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_point.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_cubit.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_state.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/route_navigation_overlay.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/route_points_sheet.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/route_simulation_overlay.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/route_summary_sheet.dart';

/// Render-only stand-in: holds a fixed state, ignores all commands.
class _FakeRouteCubit extends Cubit<RoutePlannerState>
    implements RoutePlannerCubit {
  _FakeRouteCubit(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

RoutePoint _pt(String id, String label, double lat, double lon,
    {bool depot = false, String? address}) {
  return RoutePoint(
    id: id,
    latitude: lat,
    longitude: lon,
    label: label,
    weight: 1,
    kind: depot ? RoutePointKind.depot : RoutePointKind.stop,
    address: address,
  );
}

OptimizedRoute _fixtureRoute() {
  final depot = _pt('d', 'Departure', 33.51, 36.27,
      depot: true, address: 'Warehouse, Old Town Rd');
  final stops = [
    _pt('1', 'Stop 1', 33.52, 36.28, address: 'Al-Malki St 14'),
    _pt('2', 'Stop 2', 33.53, 36.29, address: 'Baghdad Ave 7'),
    _pt('3', 'Stop 3', 33.54, 36.30, address: 'Mazzeh Highway 22'),
    _pt('4', 'Stop 4', 33.55, 36.31, address: 'Abu Roumaneh 3'),
  ];
  final line = [
    const LatLng(33.51, 36.27),
    const LatLng(33.55, 36.31),
  ];
  return OptimizedRoute(
    orderedPoints: [depot, ...stops, depot],
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

Future<void> _loadFonts() async {
  final loader = FontLoader('Almarai')
    ..addFont(rootBundle.load('assets/fonts/Almarai-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Almarai-Bold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Almarai-ExtraBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Almarai-Light.ttf'));
  await loader.load();
}

Widget _harness(RoutePlannerState state, Widget child,
    {bool inStack = false}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: BlocProvider<RoutePlannerCubit>.value(
      value: _FakeRouteCubit(state),
      child: Scaffold(
        // Fake "map" backdrop.
        body: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: const Color(0xFFDFE7DA)),
            ),
            if (inStack)
              child
            else
              Align(
                alignment: Alignment.bottomCenter,
                child: Material(
                  color: AppColors.surface,
                  clipBehavior: Clip.antiAlias,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: SingleChildScrollView(child: child),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await _loadFonts();
  });

  testWidgets('trip preview overlay', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;

    final state = RoutePlannerState(
      status: RoutePlannerStatus.optimizedSuccess,
      optimizedRoute: _fixtureRoute(),
      simulationActive: true,
      simulationPlaying: true,
      simulationProgress: 0.46,
      // True arc-length fractions of [depot, s1..s4, depot] — drives the
      // headline / timeline / scrubber ticks.
      stopFractions: const [0.0, 0.2, 0.45, 0.65, 0.85, 1.0],
    );

    await tester.pumpWidget(
      _harness(state, const RouteSimulationOverlay(), inStack: true),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/trip_preview_overlay.png'),
    );
  });

  testWidgets('drive hud overlay', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;

    final state = RoutePlannerState(
      status: RoutePlannerStatus.optimizedSuccess,
      optimizedRoute: _fixtureRoute(),
      navigationActive: true,
      navigationProgress: 0.42,
      userLocation: const LatLng(33.532, 36.292),
      navigationSpeedMps: 13.6,
    );

    await tester.pumpWidget(
      _harness(
        state,
        RouteNavigationOverlay(onOpenGoogleMaps: () {}),
        inStack: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/drive_hud_overlay.png'),
    );
  });

  testWidgets('summary sheet', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;

    final state = RoutePlannerState(
      status: RoutePlannerStatus.optimizedSuccess,
      optimizedRoute: _fixtureRoute(),
    );

    await tester.pumpWidget(
      _harness(
        state,
        RouteSummarySheet(onOpenGoogleMaps: () {}, onExportCsv: () {}),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/summary_sheet.png'),
    );

    // Bottom of the sheet: route order list + red start-fresh button.
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -700),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/summary_sheet_bottom.png'),
    );
  });

  testWidgets('points sheet with stops', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;

    final route = _fixtureRoute();
    final state = RoutePlannerState(
      status: RoutePlannerStatus.pointsUpdated,
      points: route.orderedPoints.sublist(0, 4),
    );

    await tester.pumpWidget(
      _harness(
        state,
        RoutePointsSheet(
          onAddHere: () {},
          onShowImport: () {},
          onOpenWhatsapp: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/points_sheet.png'),
    );
  });
}
