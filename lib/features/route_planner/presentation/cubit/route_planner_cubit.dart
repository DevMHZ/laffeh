import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/config/env_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../../../core/utils/location_utils.dart';
import '../../../saved_routes/domain/entities/saved_route.dart';
import '../../../saved_routes/domain/repositories/saved_routes_repository.dart';
import '../../domain/entities/optimized_route.dart';
import '../../domain/entities/route_point.dart';
import '../../domain/usecases/optimize_route_usecase.dart';
import 'route_planner_state.dart';

class RoutePlannerCubit extends Cubit<RoutePlannerState> {
  final OptimizeRouteUseCase _optimize;
  final SavedRoutesRepository _savedRoutes;

  /// Drives the simulation marker forward. Cancelled on stop / reset
  /// and when the cubit closes.
  Timer? _simTimer;

  /// Wall-clock time covered by one full simulation playback (at 1×).
  /// 60s @ 1× reads as a calm "guided tour" — short enough to watch
  /// without getting bored, slow enough that the eye can follow the
  /// vehicle on the map. Speeds halve / double from here.
  static const Duration _simBaseDuration = Duration(seconds: 60);

  /// How often we tick. 60ms ≈ 16 FPS — smooth marker glide, cheap
  /// per emission.
  static const Duration _simTickInterval = Duration(milliseconds: 60);

  RoutePlannerCubit(this._optimize, this._savedRoutes)
      : super(const RoutePlannerState());

  // Debounce / dedup state for tap-to-add. Google Maps occasionally
  // fires `onTap` twice in quick succession on some devices/emulators,
  // which led to a depot + "Point 1" appearing together on the very
  // first tap. We reject any add that arrives:
  //   * within 350 ms of the previous one, AND/OR
  //   * within ~8 m of an existing point.
  DateTime? _lastTapAt;
  LatLng? _lastTapPos;
  static const Duration _addPointDebounce = Duration(milliseconds: 350);
  static const double _minSeparationMeters = 8.0;

  // ── Bootstrap ──────────────────────────────────────────────

  Future<void> initialize() async {
    emit(state.copyWith(
      status: RoutePlannerStatus.loadingLocation,
      missingMapsKey: !EnvConfig.hasGoogleMapsKey,
      clearError: true,
    ));

    try {
      final loc = await LocationUtils.getCurrentLatLng();
      emit(state.copyWith(
        status: RoutePlannerStatus.locationReady,
        userLocation: loc,
        cameraTarget: loc,
      ));
    } on LocationException catch (e) {
      developer.log('Location unavailable: ${e.message}');
      emit(state.copyWith(
        status: RoutePlannerStatus.locationReady,
        cameraTarget: const LatLng(
          AppConfig.fallbackLat,
          AppConfig.fallbackLon,
        ),
        errorMessage: _mapLocationError(e),
      ));
    } catch (e) {
      developer.log('initialize() failed', error: e);
      emit(state.copyWith(
        status: RoutePlannerStatus.locationReady,
        cameraTarget: const LatLng(
          AppConfig.fallbackLat,
          AppConfig.fallbackLon,
        ),
        errorMessage: AppStrings.errLocationUnavailable,
      ));
    }
  }

  // ── Point management ──────────────────────────────────────

  Future<void> addPoint(LatLng position) async {
    // ── Guard 1: time-based debounce ────────────────────
    final now = DateTime.now();
    if (_lastTapAt != null &&
        now.difference(_lastTapAt!) < _addPointDebounce) {
      // Same tap fired twice — ignore the duplicate.
      if (_lastTapPos != null &&
          DistanceUtils.haversineKm(_lastTapPos!, position) * 1000 <
              _minSeparationMeters * 6) {
        return;
      }
    }
    _lastTapAt = now;
    _lastTapPos = position;

    // ── Guard 2: don't place a new point on top of an existing one
    for (final p in state.points) {
      final meters =
          DistanceUtils.haversineKm(p.latLng, position) * 1000;
      if (meters < _minSeparationMeters) {
        return;
      }
    }

    final isFirst = state.points.isEmpty;
    final id = 'p_${now.microsecondsSinceEpoch}';

    final label = isFirst
        ? AppStrings.departure
        : '${AppStrings.stop} ${state.points.length}';

    final tentative = RoutePoint(
      id: id,
      latitude: position.latitude,
      longitude: position.longitude,
      label: label,
      weight: AppConfig.defaultStopWeight,
      kind: isFirst ? RoutePointKind.depot : RoutePointKind.stop,
    );

    emit(state.copyWith(
      status: RoutePlannerStatus.pointsUpdated,
      points: [...state.points, tentative],
      clearOptimizedRoute: true,
      clearError: true,
    ));

    _resolveAddress(tentative).then((withAddr) {
      if (withAddr == null) return;
      final idx = state.points.indexWhere((p) => p.id == withAddr.id);
      if (idx < 0) return;
      final updated = [...state.points]..[idx] = withAddr;
      emit(state.copyWith(points: updated));
    });
  }

  /// Move an existing point to a new lat/lon (called from
  /// marker `onDragEnd`).
  ///
  /// Invalidates any optimized result (the geometry no longer
  /// matches), and re-resolves the human-readable address.
  void updatePointPosition(String id, LatLng newPosition) {
    final idx = state.points.indexWhere((p) => p.id == id);
    if (idx < 0) return;

    final current = state.points[idx];
    final updated = current.copyWith(
      latitude: newPosition.latitude,
      longitude: newPosition.longitude,
      clearAddress: true,
    );
    final newList = [...state.points]..[idx] = updated;

    emit(state.copyWith(
      points: newList,
      status: RoutePlannerStatus.pointsUpdated,
      clearOptimizedRoute: true,
      clearError: true,
      // Cancel any sim that was running for the now-stale route.
      simulationActive: false,
      simulationPlaying: false,
      simulationProgress: 0.0,
    ));
    _cancelSimTimer();

    // Refresh address in the background.
    _resolveAddress(updated).then((withAddr) {
      if (withAddr == null) return;
      final i = state.points.indexWhere((p) => p.id == withAddr.id);
      if (i < 0) return;
      final list = [...state.points]..[i] = withAddr;
      emit(state.copyWith(points: list));
    });
  }

  Future<RoutePoint?> _resolveAddress(RoutePoint p) async {
    try {
      final placemarks =
          await geo.placemarkFromCoordinates(p.latitude, p.longitude);
      if (placemarks.isEmpty) return null;
      final pm = placemarks.first;
      final parts = [
        if ((pm.street ?? '').isNotEmpty) pm.street,
        if ((pm.subLocality ?? '').isNotEmpty) pm.subLocality,
        if ((pm.locality ?? '').isNotEmpty) pm.locality,
      ].whereType<String>().toList();
      final addr = parts.isEmpty ? null : parts.join('، ');
      return p.copyWith(address: addr);
    } catch (_) {
      return null;
    }
  }

  void renamePoint(String id, String newLabel) {
    final list = state.points.map((p) {
      if (p.id != id) return p;
      return p.copyWith(label: newLabel);
    }).toList();
    emit(state.copyWith(points: list, status: RoutePlannerStatus.pointsUpdated));
  }

  void removePoint(String id) {
    final updated = state.points.where((p) => p.id != id).toList();
    final rebalanced = _ensureSingleDepot(updated);

    emit(state.copyWith(
      points: _relabel(rebalanced),
      status: RoutePlannerStatus.pointsUpdated,
      clearOptimizedRoute: true,
    ));
  }

  void reorderPoint(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final list = [...state.points];
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);

    final fixed = list.asMap().entries.map((e) {
      final p = e.value;
      final kind = e.key == 0 ? RoutePointKind.depot : RoutePointKind.stop;
      return p.copyWith(kind: kind);
    }).toList();

    emit(state.copyWith(
      points: _relabel(fixed),
      status: RoutePlannerStatus.pointsUpdated,
      clearOptimizedRoute: true,
    ));
  }

  void setAsDeparture(String id) {
    final list = state.points;
    final idx = list.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    final reordered = [list[idx], ...list.where((p) => p.id != id)];
    final fixed = reordered.asMap().entries.map((e) {
      final p = e.value;
      final kind = e.key == 0 ? RoutePointKind.depot : RoutePointKind.stop;
      return p.copyWith(kind: kind);
    }).toList();
    emit(state.copyWith(
      points: _relabel(fixed),
      status: RoutePlannerStatus.pointsUpdated,
      clearOptimizedRoute: true,
    ));
  }

  void clearAll() {
    _cancelSimTimer();
    emit(state.copyWith(
      points: const [],
      status: RoutePlannerStatus.pointsUpdated,
      clearOptimizedRoute: true,
      clearError: true,
      displaySegment: RouteSegment.full,
      simulationActive: false,
      simulationPlaying: false,
      simulationProgress: 0.0,
    ));
  }

  // ── Optimize ──────────────────────────────────────────────

  Future<void> optimize() async {
    if (state.points.length < 2) {
      emit(state.copyWith(
        status: RoutePlannerStatus.optimizedFailure,
        errorMessage: AppStrings.errMinTwoPoints,
      ));
      return;
    }

    emit(state.copyWith(
      status: RoutePlannerStatus.optimizing,
      clearError: true,
    ));

    final result = await _optimize(points: state.points);

    result.when(
      success: (route) {
        emit(state.copyWith(
          status: RoutePlannerStatus.optimizedSuccess,
          optimizedRoute: route,
          points: _stripReturnDuplicate(route.orderedPoints),
          displaySegment: RouteSegment.full,
          simulationActive: false,
          simulationPlaying: false,
          simulationProgress: 0.0,
        ));
      },
      failure: (f) {
        emit(state.copyWith(
          status: RoutePlannerStatus.optimizedFailure,
          errorMessage: f.message.isEmpty ? AppStrings.errOptimize : f.message,
        ));
      },
    );
  }

  void showSegment(RouteSegment segment) {
    if (state.optimizedRoute == null) return;
    emit(state.copyWith(displaySegment: segment));
  }

  // ── Saved routes integration ───────────────────────────────

  /// Persist the currently-optimized route to local history.
  /// Returns the saved entity, or `null` if there was nothing to save.
  /// Throws on storage failure — the UI is responsible for converting
  /// that into a user-facing error.
  Future<SavedRoute?> saveCurrentRouteToHistory(String name) async {
    final route = state.optimizedRoute;
    if (route == null) {
      developer.log(
        'saveCurrentRouteToHistory: skipped — no optimizedRoute in state',
        name: '💾 SaveRoute',
      );
      return null;
    }
    final trimmed =
        name.trim().isEmpty ? AppStrings.defaultRouteName : name.trim();

    final entity = SavedRoute(
      id: '',
      name: trimmed,
      savedAt: DateTime.now(),
      routingMode: AppConfig.defaultRoutingMode,
      orderedPoints: route.orderedPoints,
      metrics: route.metrics,
      fullPolyline: route.fullPolyline,
      goPolyline: route.goPolyline,
      returnPolyline: route.returnPolyline,
      hasRoadGeometry: route.hasRoadGeometry,
    );

    developer.log(
      'saveCurrentRouteToHistory: writing "$trimmed" '
      '(${route.orderedPoints.length} points, '
      '${route.fullPolyline.length} polyline vertices)',
      name: '💾 SaveRoute',
    );

    final saved = await _savedRoutes.upsert(entity);

    developer.log(
      'saveCurrentRouteToHistory: ✅ saved id=${saved.id} name="${saved.name}"',
      name: '💾 SaveRoute',
    );
    return saved;
  }

  /// Replace the current planner state with a previously-saved route
  /// so the user can review / re-simulate it.
  void loadSavedRoute(SavedRoute saved) {
    _cancelSimTimer();
    emit(state.copyWith(
      status: RoutePlannerStatus.optimizedSuccess,
      points: _stripReturnDuplicate(saved.orderedPoints),
      optimizedRoute: saved.toOptimizedRoute(),
      displaySegment: RouteSegment.full,
      simulationActive: false,
      simulationPlaying: false,
      simulationProgress: 0.0,
      clearError: true,
    ));
  }

  // ── Simulation ────────────────────────────────────────────

  /// Opens the simulation sheet and starts the playback timer.
  /// If no optimized route exists, this is a no-op.
  void startSimulation() {
    if (state.optimizedRoute == null) return;
    _cancelSimTimer();
    emit(state.copyWith(
      simulationActive: true,
      simulationPlaying: true,
      simulationProgress: 0.0,
      simulationSpeed: state.simulationSpeed == 0 ? 1.0 : state.simulationSpeed,
      displaySegment: RouteSegment.full,
    ));
    _startSimTimer();
  }

  void pauseSimulation() {
    if (!state.simulationActive) return;
    _cancelSimTimer();
    emit(state.copyWith(simulationPlaying: false));
  }

  void resumeSimulation() {
    if (!state.simulationActive) return;
    // Already finished: rewind to the start instead of staying stuck at 1.0.
    if (state.simulationProgress >= 1.0) {
      emit(state.copyWith(
        simulationProgress: 0.0,
        simulationPlaying: true,
      ));
    } else {
      emit(state.copyWith(simulationPlaying: true));
    }
    _startSimTimer();
  }

  void resetSimulation() {
    _cancelSimTimer();
    emit(state.copyWith(
      simulationPlaying: false,
      simulationProgress: 0.0,
    ));
  }

  void exitSimulation() {
    _cancelSimTimer();
    emit(state.copyWith(
      simulationActive: false,
      simulationPlaying: false,
      simulationProgress: 0.0,
    ));
  }

  void setSimulationSpeed(double speed) {
    if (speed == state.simulationSpeed) return;
    emit(state.copyWith(simulationSpeed: speed));
    if (state.simulationActive && state.simulationPlaying) {
      _cancelSimTimer();
      _startSimTimer();
    }
  }

  void setSimulationCameraMode(SimulationCameraMode mode) {
    if (mode == state.simulationCameraMode) return;
    emit(state.copyWith(simulationCameraMode: mode));
  }

  void _startSimTimer() {
    _simTimer = Timer.periodic(_simTickInterval, (_) => _onSimTick());
  }

  void _cancelSimTimer() {
    _simTimer?.cancel();
    _simTimer = null;
  }

  void _onSimTick() {
    if (!state.simulationActive || !state.simulationPlaying) return;

    final totalMs = _simBaseDuration.inMilliseconds /
        state.simulationSpeed.clamp(0.25, 8.0);
    final step = _simTickInterval.inMilliseconds / totalMs;
    final next = (state.simulationProgress + step).clamp(0.0, 1.0);

    if (next >= 1.0) {
      _cancelSimTimer();
      emit(state.copyWith(
        simulationProgress: 1.0,
        simulationPlaying: false,
      ));
      return;
    }
    emit(state.copyWith(simulationProgress: next));
  }

  // ── Internals ──────────────────────────────────────────────

  List<RoutePoint> _ensureSingleDepot(List<RoutePoint> points) {
    if (points.isEmpty) return points;
    final hasDepot = points.any((p) => p.isDepot);
    if (hasDepot) return points;
    return [
      points.first.copyWith(kind: RoutePointKind.depot),
      ...points.skip(1).map((p) => p.copyWith(kind: RoutePointKind.stop)),
    ];
  }

  List<RoutePoint> _relabel(List<RoutePoint> points) {
    var stopCounter = 1;
    return points.asMap().entries.map((e) {
      final p = e.value;
      if (p.isDepot) {
        return p.copyWith(label: AppStrings.departure);
      }
      final label = '${AppStrings.stop} ${stopCounter++}';
      return p.copyWith(label: label);
    }).toList();
  }

  List<RoutePoint> _stripReturnDuplicate(List<RoutePoint> ordered) {
    if (ordered.length < 2) return ordered;
    if (ordered.first.latitude == ordered.last.latitude &&
        ordered.first.longitude == ordered.last.longitude) {
      return ordered.sublist(0, ordered.length - 1);
    }
    return ordered;
  }

  String _mapLocationError(LocationException e) {
    switch (e.message) {
      case 'LOCATION_SERVICE_DISABLED':
        return AppStrings.errLocationServiceDisabled;
      case 'LOCATION_PERMISSION_DENIED':
      case 'LOCATION_PERMISSION_DENIED_FOREVER':
        return AppStrings.errLocationPermissionDenied;
      default:
        return AppStrings.errLocationUnavailable;
    }
  }

  @override
  Future<void> close() {
    _cancelSimTimer();
    return super.close();
  }
}
