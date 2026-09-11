// Reproduces the reported white screen when preview/drive activates,
// by mounting the REAL RoutePlannerPage with a faked cubit.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;
import 'package:laffeh/core/constants/app_constants.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:laffeh/core/services/location_ping_service.dart';
import 'package:laffeh/features/auth/presentation/cubit/auth_cubit.dart';

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

class _MockPing extends Mock implements LocationPingService {}

class _AuthenticatedCubit extends Cubit<AuthState> implements AuthCubit {
  _AuthenticatedCubit() : super(const AuthUnauthenticated());

  @override
  bool get isAuthenticated => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeRouteCubit extends Cubit<RoutePlannerState>
    implements RoutePlannerCubit {
  _FakeRouteCubit(super.initialState);

  int exits = 0;

  void advance() => emit(
    state.copyWith(
      simulationProgress: (state.simulationProgress + 0.001).clamp(0, 1),
    ),
  );

  @override
  void exitSimulation() {
    exits++;
    emit(state.copyWith(simulationActive: false, simulationPlaying: false));
  }

  @override
  void setSimulationCameraMode(SimulationCameraMode mode) =>
      emit(state.copyWith(simulationCameraMode: mode));

  @override
  void pauseSimulation() => emit(state.copyWith(simulationPlaying: false));

  @override
  void resumeSimulation() => emit(state.copyWith(simulationPlaying: true));

  @override
  Future<void> initialize() async {}

  @override
  bool get debugDriveSimActive => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Native camera recorder attached to the real map widget's callbacks.
/// Holding an animation open reproduces a busy native renderer.
class _CameraRecorder implements ml.MapLibreMapController {
  @override
  ml.CameraPosition cameraPosition = const ml.CameraPosition(
    target: ml.LatLng(33.52, 36.28),
    zoom: 16,
  );
  @override
  final onSymbolTapped = ml.ArgumentCallbacks<ml.Symbol>();
  void Function(ml.CameraPosition)? onMove;
  Completer<bool?>? holdNextAnimation;
  final positions = <ml.CameraPosition>[];
  int animations = 0;
  final trackingPositions = <ml.CameraPosition>[];
  final interpolations = <ml.CameraAnimationInterpolation?>[];

  void apply(ml.CameraUpdate update) {
    final json = update.toJson() as List<dynamic>;
    final previous = cameraPosition;
    if (json[0] == 'newCameraPosition') {
      final position = json[1] as Map;
      final target = position['target'] as List;
      cameraPosition = ml.CameraPosition(
        target: ml.LatLng(target[0] as double, target[1] as double),
        zoom: position['zoom'] as double,
        tilt: position['tilt'] as double,
        bearing: position['bearing'] as double,
      );
    } else {
      cameraPosition = ml.CameraPosition(
        target: previous.target,
        zoom: json[0] == 'zoomTo' ? json[1] as double : previous.zoom,
        tilt: json[0] == 'tiltTo' ? json[1] as double : previous.tilt,
        bearing: json[0] == 'bearingTo' ? json[1] as double : previous.bearing,
      );
    }
    positions.add(cameraPosition);
    onMove?.call(cameraPosition);
  }

  @override
  Future<bool?> moveCamera(ml.CameraUpdate update) async {
    apply(update);
    return true;
  }

  @override
  Future<bool?> animateCamera(ml.CameraUpdate update, {Duration? duration}) {
    animations++;
    apply(update);
    final held = holdNextAnimation;
    holdNextAnimation = null;
    return held?.future ?? Future.value(true);
  }

  @override
  Future<bool> easeCamera(
    ml.CameraUpdate update, {
    Duration? duration,
    ml.CameraAnimationInterpolation? interpolation,
  }) {
    apply(update);
    trackingPositions.add(cameraPosition);
    interpolations.add(interpolation);
    final held = holdNextAnimation;
    holdNextAnimation = null;
    return held?.future.then((value) => value ?? false) ?? Future.value(true);
  }

  @override
  Future<List> getLayerIds() async => [];

  @override
  Future<math.Point> toScreenLocation(ml.LatLng location) async =>
      const math.Point(400, 300);

  @override
  Future<ml.LatLng> toLatLng(math.Point point) async => cameraPosition.target;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

RoutePoint _pt(
  String id,
  String label,
  double lat,
  double lon, {
  bool depot = false,
}) {
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
    orderedPoints: [
      depot,
      ...stops,
      _pt('return_d', 'Departure', 33.51, 36.27, depot: true),
    ],
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

  Future<_FakeRouteCubit> pumpPage(
    WidgetTester tester,
    RoutePlannerState state,
  ) async {
    final cubit = _FakeRouteCubit(state);
    sl.registerFactory<RoutePlannerCubit>(() => cubit);
    final ping = _MockPing();
    when(() => ping.ping()).thenAnswer((_) async {});
    sl.registerSingleton<LocationPingService>(ping);
    final auth = _AuthenticatedCubit();
    addTearDown(auth.close);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.data,
        home: BlocProvider<AuthCubit>.value(
          value: auth,
          child: const RoutePlannerPage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    return cubit;
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
  Future<(_FakeRouteCubit, _CameraRecorder)> preview(
    WidgetTester tester,
  ) async {
    final cubit = await pumpPage(
      tester,
      RoutePlannerState(
        status: RoutePlannerStatus.optimizedSuccess,
        optimizedRoute: _fixtureRoute(),
        simulationActive: true,
        simulationPlaying: true,
        simulationProgress: 0.4,
        simulationCameraMode: SimulationCameraMode.chase,
      ),
    );
    final map = tester.widget<ml.MapLibreMap>(find.byType(ml.MapLibreMap));
    final camera = _CameraRecorder()..onMove = map.onCameraMove;
    map.onMapCreated!(camera);
    map.onStyleLoadedCallback!();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    return (cubit, camera);
  }

  Future<void> ticks(
    WidgetTester tester,
    _FakeRouteCubit cubit,
    int count,
  ) async {
    for (var i = 0; i < count; i++) {
      cubit.advance();
      await tester.pump(const Duration(milliseconds: 33));
    }
  }

  testWidgets('2D and 3D choices survive subsequent playback frames', (
    tester,
  ) async {
    final (cubit, camera) = await preview(tester);
    expect(camera.cameraPosition.tilt, 60);
    await tester.tap(find.byTooltip(AppStrings.viewFlat));
    await ticks(tester, cubit, 12);
    expect(camera.cameraPosition.tilt, 0);
    expect(find.byTooltip(AppStrings.view3d), findsOneWidget);
    await tester.tap(find.byTooltip(AppStrings.view3d));
    await ticks(tester, cubit, 12);
    expect(camera.cameraPosition.tilt, 55);
    expect(tester.takeException(), isNull);
  });

  for (final mode in [
    SimulationCameraMode.follow,
    SimulationCameraMode.chase,
  ]) {
    testWidgets(
      '${mode.name} retargets continuously; Exit prevents stale follow work',
      (tester) async {
        final (cubit, camera) = await preview(tester);
        cubit.setSimulationCameraMode(mode);
        await ticks(tester, cubit, 2);
        final blocked = Completer<bool?>();
        camera.holdNextAnimation = blocked;
        final before = camera.trackingPositions.length;
        await ticks(tester, cubit, 5);
        expect(
          camera.trackingPositions.length,
          greaterThanOrEqualTo(before + 4),
          reason: 'new targets must not wait for animation completion',
        );
        expect(
          camera.trackingPositions
              .skip(before)
              .map((p) => p.target)
              .toSet()
              .length,
          greaterThanOrEqualTo(4),
        );
        expect(
          camera.interpolations,
          everyElement(ml.CameraAnimationInterpolation.linear),
        );
        final press = await tester.startGesture(
          tester.getCenter(find.byTooltip(AppStrings.exitSimulation)),
        );
        await ticks(
          tester,
          cubit,
          3,
        ); // Playback advances while the finger is down.
        await press.up();
        await tester.pump();
        expect(cubit.exits, 1);
        expect(cubit.state.simulationActive, isFalse);
        expect(find.byType(RouteSimulationOverlay), findsNothing);
        expect(camera.cameraPosition.tilt, 0);
        final targetsAtExit = camera.trackingPositions.length;
        blocked.complete(true);
        await tester.pump(const Duration(milliseconds: 400));
        expect(camera.trackingPositions.length, targetsAtExit);
        expect(
          camera.cameraPosition.tilt,
          0,
          reason: 'old follow frames cannot re-tilt after exit',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('camera-mode buttons accept each tap across playback updates', (
    tester,
  ) async {
    final (cubit, _) = await preview(tester);
    for (final mode in [
      SimulationCameraMode.follow,
      SimulationCameraMode.chase,
      SimulationCameraMode.follow,
      SimulationCameraMode.chase,
    ]) {
      final button = find.byTooltip(
        mode == SimulationCameraMode.follow
            ? AppStrings.cameraFollow
            : AppStrings.cameraChase,
      );
      final press = await tester.startGesture(tester.getCenter(button));
      await ticks(tester, cubit, 3);
      await press.up();
      await tester.pump();
      expect(cubit.state.simulationCameraMode, mode);
    }
    expect(tester.takeException(), isNull);
  });
}
