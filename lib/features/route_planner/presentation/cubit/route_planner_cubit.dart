import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../../../core/utils/link_parser.dart';
import '../../../../core/utils/location_utils.dart';
import '../../../saved_routes/domain/entities/saved_route.dart';
import '../../../saved_routes/domain/repositories/saved_routes_repository.dart';
import '../../data/datasources/osm_geocoding_datasource.dart';
import '../../domain/entities/optimized_route.dart';
import '../../domain/entities/route_point.dart';
import '../../domain/usecases/optimize_route_usecase.dart';
import 'route_planner_state.dart';

class RoutePlannerCubit extends Cubit<RoutePlannerState> {
  final OptimizeRouteUseCase _optimize;
  final SavedRoutesRepository _savedRoutes;
  final OsmGeocodingDataSource _geocoding;

  /// Drives the simulation marker forward. Cancelled on stop / reset
  /// and when the cubit closes.
  Timer? _simTimer;
  StreamSubscription<Position>? _navSub;

  /// Wall-clock time covered by one full preview playback. There is
  /// no user-facing speed control anymore — one good pace: 45s reads
  /// as a calm guided tour that doesn't overstay its welcome.
  static const Duration _simBaseDuration = Duration(seconds: 45);

  /// How often we tick. 60ms ≈ 16 FPS — smooth marker glide, cheap
  /// per emission.
  static const Duration _simTickInterval = Duration(milliseconds: 60);

  RoutePlannerCubit(this._optimize, this._savedRoutes, this._geocoding)
    : super(const RoutePlannerState());

  // Debounce / dedup state for tap-to-add. Map widgets may occasionally
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
    emit(
      state.copyWith(
        status: RoutePlannerStatus.loadingLocation,
        clearError: true,
      ),
    );

    try {
      final loc = await LocationUtils.getCurrentLatLng();
      emit(
        state.copyWith(
          status: RoutePlannerStatus.locationReady,
          userLocation: loc,
          cameraTarget: loc,
        ),
      );
    } on LocationException catch (e) {
      developer.log('Location unavailable: ${e.message}');
      emit(
        state.copyWith(
          status: RoutePlannerStatus.locationReady,
          cameraTarget: const LatLng(
            AppConfig.fallbackLat,
            AppConfig.fallbackLon,
          ),
          errorMessage: _mapLocationError(e),
        ),
      );
    } catch (e) {
      developer.log('initialize() failed', error: e);
      emit(
        state.copyWith(
          status: RoutePlannerStatus.locationReady,
          cameraTarget: const LatLng(
            AppConfig.fallbackLat,
            AppConfig.fallbackLon,
          ),
          errorMessage: AppStrings.errLocationUnavailable,
        ),
      );
    }
  }

  /// Backs the "Enable location" button shown on the location error
  /// banner. Sends the user to the right place to grant access (OS
  /// location settings / permission prompt / app settings) and, if that
  /// succeeds, retries the location fetch so the error clears itself.
  Future<void> resolveLocationAccess() async {
    try {
      final granted = await LocationUtils.resolveAccess();
      if (granted) await initialize();
    } catch (e) {
      developer.log('resolveLocationAccess() failed', error: e);
    }
  }

  // ── Point management ──────────────────────────────────────

  Future<void> addPoint(LatLng position) async {
    // ── Guard 1: time-based debounce ────────────────────
    final now = DateTime.now();
    if (_lastTapAt != null && now.difference(_lastTapAt!) < _addPointDebounce) {
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
      final meters = DistanceUtils.haversineKm(p.latLng, position) * 1000;
      if (meters < _minSeparationMeters) {
        return;
      }
    }

    _cancelSimTimer();
    _cancelNavigationStream();

    final isFirst = state.points.isEmpty;
    final id = 'p_${now.microsecondsSinceEpoch}';

    final label = isFirst
        ? AppStrings.departure
        : AppStrings.stopLabel(state.points.length);

    final tentative = RoutePoint(
      id: id,
      latitude: position.latitude,
      longitude: position.longitude,
      label: label,
      weight: AppConfig.defaultStopWeight,
      kind: isFirst ? RoutePointKind.depot : RoutePointKind.stop,
    );

    emit(
      state.copyWith(
        status: RoutePlannerStatus.pointsUpdated,
        points: [...state.points, tentative],
        clearOptimizedRoute: true,
        clearError: true,
        simulationActive: false,
        simulationPlaying: false,
        simulationProgress: 0.0,
        navigationActive: false,
        navigationProgress: 0.0,
        clearNavigationHeading: true,
        clearNavigationSpeed: true,
      ),
    );

    _resolveAddress(tentative).then((withAddr) {
      if (withAddr == null) return;
      final idx = state.points.indexWhere((p) => p.id == withAddr.id);
      if (idx < 0) return;
      final updated = [...state.points]..[idx] = withAddr;
      emit(state.copyWith(points: updated));
    }).catchError((_) {});
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

    emit(
      state.copyWith(
        points: newList,
        status: RoutePlannerStatus.pointsUpdated,
        clearOptimizedRoute: true,
        clearError: true,
        // Cancel any sim that was running for the now-stale route.
        simulationActive: false,
        simulationPlaying: false,
        simulationProgress: 0.0,
        navigationActive: false,
        navigationProgress: 0.0,
        clearNavigationHeading: true,
        clearNavigationSpeed: true,
      ),
    );
    _cancelSimTimer();
    _cancelNavigationStream();

    // Refresh address in the background.
    _resolveAddress(updated).then((withAddr) {
      if (withAddr == null) return;
      final i = state.points.indexWhere((p) => p.id == withAddr.id);
      if (i < 0) return;
      final list = [...state.points]..[i] = withAddr;
      emit(state.copyWith(points: list));
    }).catchError((_) {});
  }

  Future<RoutePoint?> _resolveAddress(RoutePoint p) async {
    final address = await _geocoding.reverseAddress(p.latLng);
    if (address == null || address.isEmpty) return null;
    return p.copyWith(address: address);
  }

  void renamePoint(String id, String newLabel) {
    final list = state.points.map((p) {
      if (p.id != id) return p;
      return p.copyWith(label: newLabel);
    }).toList();
    emit(
      state.copyWith(points: list, status: RoutePlannerStatus.pointsUpdated),
    );
  }

  void removePoint(String id) {
    _cancelNavigationStream();
    final updated = state.points.where((p) => p.id != id).toList();
    final rebalanced = _ensureSingleDepot(updated);

    emit(
      state.copyWith(
        points: _relabel(rebalanced),
        status: RoutePlannerStatus.pointsUpdated,
        clearOptimizedRoute: true,
        navigationActive: false,
        navigationProgress: 0.0,
        clearNavigationHeading: true,
        clearNavigationSpeed: true,
      ),
    );
  }

  void reorderPoint(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    _cancelNavigationStream();
    final list = [...state.points];
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);

    final fixed = list.asMap().entries.map((e) {
      final p = e.value;
      final kind = e.key == 0 ? RoutePointKind.depot : RoutePointKind.stop;
      return p.copyWith(kind: kind);
    }).toList();

    emit(
      state.copyWith(
        points: _relabel(fixed),
        status: RoutePlannerStatus.pointsUpdated,
        clearOptimizedRoute: true,
        navigationActive: false,
        navigationProgress: 0.0,
        clearNavigationHeading: true,
        clearNavigationSpeed: true,
      ),
    );
  }

  void setAsDeparture(String id) {
    _cancelNavigationStream();
    final list = state.points;
    final idx = list.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    final reordered = [list[idx], ...list.where((p) => p.id != id)];
    final fixed = reordered.asMap().entries.map((e) {
      final p = e.value;
      final kind = e.key == 0 ? RoutePointKind.depot : RoutePointKind.stop;
      return p.copyWith(kind: kind);
    }).toList();
    emit(
      state.copyWith(
        points: _relabel(fixed),
        status: RoutePlannerStatus.pointsUpdated,
        clearOptimizedRoute: true,
        navigationActive: false,
        navigationProgress: 0.0,
        clearNavigationHeading: true,
        clearNavigationSpeed: true,
      ),
    );
  }

  void clearAll() {
    _cancelSimTimer();
    _cancelNavigationStream();
    emit(
      state.copyWith(
        points: const [],
        status: RoutePlannerStatus.pointsUpdated,
        clearOptimizedRoute: true,
        clearError: true,
        displaySegment: RouteSegment.full,
        simulationActive: false,
        simulationPlaying: false,
        simulationProgress: 0.0,
        navigationActive: false,
        navigationProgress: 0.0,
        clearNavigationHeading: true,
        clearNavigationSpeed: true,
      ),
    );
  }

  // ── Bulk add from text ─────────────────────────────────────

  /// Parse multi-line text (one address per line), forward-geocode each,
  /// and add matching points to the map. Returns the count of points added.
  Future<int> addPointsFromText(String text) async {
    final lines = text
        .split(RegExp(r'[\n\r]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) return 0;

    int added = 0;
    for (final line in lines) {
      try {
        // 1- Try to parse as a map URL (Google Maps, Apple Maps, …)
        final parsed = await _tryParseMapLine(line);
        LatLng? latLng;
        if (parsed != null) {
          latLng = parsed;
        } else {
          // 2- Try raw lat,lng pair (e.g. "33.5131, 36.2767")
          latLng = LinkParser.parseLatLngPair(line);
        }
        // 3- Fall back to forward-geocoding
        latLng ??= await _geocoding.searchAddress(line);
        if (latLng == null) continue;
        await addPoint(latLng);
        added++;
      } catch (_) {
        continue;
      }
    }
    return added;
  }

  // ── Optimize ──────────────────────────────────────────────

  Future<void> optimize() async {
    _cancelNavigationStream();

    if (state.points.length < 2) {
      emit(
        state.copyWith(
          status: RoutePlannerStatus.optimizedFailure,
          errorMessage: AppStrings.errMinTwoPoints,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: RoutePlannerStatus.optimizing,
        clearError: true,
        navigationActive: false,
        navigationProgress: 0.0,
        clearNavigationHeading: true,
        clearNavigationSpeed: true,
        simulationActive: false,
        simulationPlaying: false,
        simulationProgress: 0.0,
      ),
    );

    final result = await _optimize(points: state.points);

    result.when(
      success: (route) {
        emit(
          state.copyWith(
            status: RoutePlannerStatus.optimizedSuccess,
            optimizedRoute: route,
            points: _stripReturnDuplicate(route.orderedPoints),
            displaySegment: RouteSegment.full,
            simulationActive: false,
            simulationPlaying: false,
            simulationProgress: 0.0,
            navigationActive: false,
            navigationProgress: 0.0,
            clearNavigationHeading: true,
            clearNavigationSpeed: true,
          ),
        );
      },
      failure: (f) {
        emit(
          state.copyWith(
            status: RoutePlannerStatus.optimizedFailure,
            errorMessage: f.message.isEmpty
                ? AppStrings.errOptimize
                : f.message,
          ),
        );
      },
    );
  }

  void showSegment(RouteSegment segment) {
    if (state.optimizedRoute == null) return;
    emit(state.copyWith(displaySegment: segment));
  }

  // ── Live navigation ───────────────────────────────────────

  Future<void> startNavigation() async {
    final route = state.optimizedRoute;
    if (route == null) return;

    _cancelSimTimer();
    _cancelNavigationStream();

    try {
      final loc = await LocationUtils.getCurrentLatLng();
      emit(
        state.copyWith(
          userLocation: loc,
          cameraTarget: loc,
          navigationActive: true,
          navigationProgress: _progressAlongPath(route.fullPolyline, loc),
          clearNavigationHeading: true,
          clearNavigationSpeed: true,
          simulationActive: false,
          simulationPlaying: false,
          simulationProgress: 0.0,
          displaySegment: RouteSegment.full,
          clearError: true,
        ),
      );

      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
      _navSub = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(_onNavigationPosition, onError: _onNavigationError);
    } on LocationException catch (e) {
      emit(
        state.copyWith(
          errorMessage: _mapLocationError(e),
          navigationActive: false,
          navigationProgress: 0.0,
          clearNavigationHeading: true,
          clearNavigationSpeed: true,
        ),
      );
    } catch (e) {
      developer.log('startNavigation() failed', error: e);
      emit(
        state.copyWith(
          errorMessage: AppStrings.errLocationUnavailable,
          navigationActive: false,
          navigationProgress: 0.0,
          clearNavigationHeading: true,
          clearNavigationSpeed: true,
        ),
      );
    }
  }

  void stopNavigation() {
    _cancelNavigationStream();
    emit(
      state.copyWith(
        navigationActive: false,
        navigationProgress: 0.0,
        clearNavigationHeading: true,
        clearNavigationSpeed: true,
      ),
    );
  }

  void _onNavigationPosition(Position position) {
    if (!state.navigationActive) return;
    final route = state.optimizedRoute;
    if (route == null) {
      stopNavigation();
      return;
    }

    final loc = LatLng(position.latitude, position.longitude);
    final heading = position.heading.isFinite && position.heading >= 0
        ? position.heading
        : null;
    final speed = position.speed.isFinite && position.speed >= 0
        ? position.speed
        : null;

    emit(
      state.copyWith(
        userLocation: loc,
        cameraTarget: loc,
        navigationProgress: _progressAlongPath(route.fullPolyline, loc),
        navigationHeading: heading,
        navigationSpeedMps: speed,
      ),
    );
  }

  void _onNavigationError(Object error) {
    developer.log('navigation stream error', error: error);
    _cancelNavigationStream();
    emit(
      state.copyWith(
        errorMessage: AppStrings.errLocationUnavailable,
        navigationActive: false,
        clearNavigationHeading: true,
        clearNavigationSpeed: true,
      ),
    );
  }

  void _cancelNavigationStream() {
    _navSub?.cancel();
    _navSub = null;
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
    final trimmed = name.trim().isEmpty
        ? AppStrings.defaultRouteName
        : name.trim();

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
    _cancelNavigationStream();
    emit(
      state.copyWith(
        status: RoutePlannerStatus.optimizedSuccess,
        points: _stripReturnDuplicate(saved.orderedPoints),
        optimizedRoute: saved.toOptimizedRoute(),
        displaySegment: RouteSegment.full,
        simulationActive: false,
        simulationPlaying: false,
        simulationProgress: 0.0,
        navigationActive: false,
        navigationProgress: 0.0,
        clearNavigationHeading: true,
        clearNavigationSpeed: true,
        clearError: true,
      ),
    );
  }

  // ── Simulation ────────────────────────────────────────────

  /// Opens the simulation sheet and starts the playback timer.
  /// If no optimized route exists, this is a no-op.
  void startSimulation() {
    if (state.optimizedRoute == null) return;
    _cancelSimTimer();
    _cancelNavigationStream();
    emit(
      state.copyWith(
        simulationActive: true,
        simulationPlaying: true,
        simulationProgress: 0.0,
        navigationActive: false,
        navigationProgress: 0.0,
        clearNavigationHeading: true,
        clearNavigationSpeed: true,
        simulationSpeed: state.simulationSpeed == 0
            ? 1.0
            : state.simulationSpeed,
        displaySegment: RouteSegment.full,
      ),
    );
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
      emit(state.copyWith(simulationProgress: 0.0, simulationPlaying: true));
    } else {
      emit(state.copyWith(simulationPlaying: true));
    }
    _startSimTimer();
  }

  void resetSimulation() {
    _cancelSimTimer();
    emit(state.copyWith(simulationPlaying: false, simulationProgress: 0.0));
  }

  void exitSimulation() {
    _cancelSimTimer();
    emit(
      state.copyWith(
        simulationActive: false,
        simulationPlaying: false,
        simulationProgress: 0.0,
      ),
    );
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

    final totalMs =
        _simBaseDuration.inMilliseconds /
        state.simulationSpeed.clamp(0.25, 8.0);
    final step = _simTickInterval.inMilliseconds / totalMs;
    final next = (state.simulationProgress + step).clamp(0.0, 1.0);

    if (next >= 1.0) {
      _cancelSimTimer();
      emit(state.copyWith(simulationProgress: 1.0, simulationPlaying: false));
      return;
    }
    emit(state.copyWith(simulationProgress: next));
  }

  // ── Internals ──────────────────────────────────────────────

  Future<LatLng?> _tryParseMapLine(String line) async {
    final parsed = LinkParser.tryParseMapUrl(line);
    if (parsed != null) return parsed;

    final uri = Uri.tryParse(line.trim());
    if (uri == null || !_looksLikeShortMapLink(uri)) return null;

    final expanded = await _expandShortMapLink(uri);
    if (expanded == null) return null;
    return LinkParser.tryParseMapUrl(expanded.toString());
  }

  bool _looksLikeShortMapLink(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'maps.app.goo.gl' ||
        host == 'goo.gl' ||
        host == 'maps.google.com' && uri.pathSegments.contains('maps');
  }

  Future<Uri?> _expandShortMapLink(Uri uri) async {
    try {
      final dio = Dio(
        BaseOptions(
          followRedirects: true,
          maxRedirects: 6,
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
        ),
      );
      final response = await dio.getUri<String>(uri);
      final realUri = response.realUri;
      if (realUri.toString() != uri.toString()) return realUri;
      final location = response.headers.value('location');
      if (location == null || location.trim().isEmpty) return null;
      return uri.resolve(location.trim());
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  double _progressAlongPath(List<LatLng> path, LatLng point) {
    if (path.length < 2) return 0.0;
    final totalKm = DistanceUtils.pathLengthKm(path);
    if (totalKm <= 0) return 0.0;

    double traveledKm = 0;
    double bestMeters = double.infinity;
    double bestProgress = 0;

    for (var i = 0; i < path.length - 1; i++) {
      final start = path[i];
      final end = path[i + 1];
      final segmentKm = DistanceUtils.haversineKm(start, end);
      final t = _projectionFraction(start, end, point);
      final projected = LatLng(
        start.latitude + (end.latitude - start.latitude) * t,
        start.longitude + (end.longitude - start.longitude) * t,
      );
      final distanceMeters = DistanceUtils.haversineKm(projected, point) * 1000;
      if (distanceMeters < bestMeters) {
        bestMeters = distanceMeters;
        bestProgress = ((traveledKm + segmentKm * t) / totalKm).clamp(0.0, 1.0);
      }
      traveledKm += segmentKm;
    }

    return bestProgress;
  }

  double _projectionFraction(LatLng start, LatLng end, LatLng point) {
    final meanLat = _degToRad((start.latitude + end.latitude) / 2);
    final sx = start.longitude * math.cos(meanLat);
    final sy = start.latitude;
    final ex = end.longitude * math.cos(meanLat);
    final ey = end.latitude;
    final px = point.longitude * math.cos(meanLat);
    final py = point.latitude;

    final dx = ex - sx;
    final dy = ey - sy;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) return 0;

    return (((px - sx) * dx + (py - sy) * dy) / lengthSquared).clamp(0.0, 1.0);
  }

  double _degToRad(double deg) => deg * math.pi / 180.0;

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
      final label = AppStrings.stopLabel(stopCounter++);
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
    _cancelNavigationStream();
    return super.close();
  }
}
