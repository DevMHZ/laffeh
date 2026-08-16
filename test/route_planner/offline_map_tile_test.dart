import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FontLoader, MethodChannel, rootBundle;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/core/theme/app_theme.dart';
import 'package:laffeh/features/route_planner/domain/entities/optimized_route.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_metrics.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_point.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_cubit.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_state.dart';
import 'package:laffeh/features/route_planner/presentation/widgets/route_summary_sheet.dart';
import 'package:latlong2/latlong.dart';

class _FakeRouteCubit extends Cubit<RoutePlannerState>
    implements RoutePlannerCubit {
  _FakeRouteCubit(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

RoutePoint _pt(String id, double lat, double lon, {bool depot = false}) {
  return RoutePoint(
    id: id,
    latitude: lat,
    longitude: lon,
    label: id,
    weight: 1,
    kind: depot ? RoutePointKind.depot : RoutePointKind.stop,
  );
}

/// A ~30 km run, long enough that the corridor needs several boxes and the
/// estimate is a real number rather than zero.
OptimizedRoute _route() {
  const degPerKm = 1 / 110.574;
  final line = [
    for (double d = 0; d <= 30; d += 1) LatLng(24.7 + d * degPerKm, 46.7),
  ];
  return OptimizedRoute(
    orderedPoints: [
      _pt('depot', 24.7, 46.7, depot: true),
      _pt('a', 24.8, 46.7),
      _pt('back', 24.7, 46.7, depot: true),
    ],
    fullPolyline: line,
    goPolyline: line,
    returnPolyline: line,
    metrics: const RouteMetrics(
      totalDistanceKm: 30,
      estimatedDurationMinutes: 45,
    ),
    hasRoadGeometry: true,
  );
}

Widget _harness() {
  return MaterialApp(
    theme: AppTheme.data,
    home: BlocProvider<RoutePlannerCubit>.value(
      value: _FakeRouteCubit(
        RoutePlannerState(
          status: RoutePlannerStatus.optimizedSuccess,
          optimizedRoute: _route(),
        ),
      ),
      child: const Scaffold(
        body: SingleChildScrollView(child: RouteSummarySheet()),
      ),
    ),
  );
}

/// The sheet's metric row is laid out for the real font; the test-runner
/// fallback measures wider and overflows it, which would drown the tile's own
/// layout in unrelated noise.
Future<void> _loadFonts() async {
  final loader = FontLoader('Almarai')
    ..addFont(rootBundle.load('assets/fonts/Almarai-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Almarai-Bold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Almarai-ExtraBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Almarai-Light.ttf'));
  await loader.load();
}

/// The maplibre plugin's global channel, which the offline cache talks to.
const MethodChannel _mapLibreGlobal = MethodChannel(
  'plugins.flutter.io/maplibre_gl',
);

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AppStrings.setLocale(const Locale('ar'));
    await _loadFonts();

    // Stand in for the native offline database with an empty one, so the
    // tile resolves to a real state instead of hanging on a missing plugin.
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _mapLibreGlobal,
      (call) async => switch (call.method) {
        'getListOfRegions' => '[]',
        _ => null,
      },
    );
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _mapLibreGlobal,
      null,
    );
  });

  testWidgets('summary sheet offers the offline map with a size estimate', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness());
    // The tile probes the cache asynchronously on mount; these pumps let the
    // "checking" spinner resolve into the real state.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(AppStrings.offlineMapTitle), findsOneWidget);
    expect(find.text(AppStrings.offlineMapDownload), findsOneWidget);

    // The mocked offline database is empty, so the tile must land on the
    // idle state — offering the download, not claiming a map is saved.
    expect(
      find.textContaining(AppStrings.offlineMapIdleHint),
      findsOneWidget,
      reason: 'idle hint carries the ≈ MB estimate the driver decides on',
    );
    expect(find.textContaining('ميغابايت'), findsOneWidget);
  });

  testWidgets('availability wording replaced the old arrival-time copy', (
    tester,
  ) async {
    expect(AppStrings.arrivalTime, 'وقت توفّر العميل');

    AppStrings.setLocale(const Locale('en'));
    expect(AppStrings.arrivalTime, 'Customer availability');

    AppStrings.setLocale(const Locale('fr'));
    expect(AppStrings.arrivalTime, 'Disponibilite du client');

    AppStrings.setLocale(const Locale('ar'));
  });
}
