import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/map_config.dart';
import '../../../../core/config/navigation_config.dart';
import '../../../../core/config/planner_config.dart';
import '../../../../core/config/routing_config.dart';
import '../../../../core/config/simulation_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/utils/debug_log.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../../../core/utils/link_parser.dart';
import '../../../../core/utils/map_link_resolver.dart';
import '../../../../core/utils/polyline_utils.dart';
import '../../../../core/utils/location_utils.dart';
import '../../../saved_routes/domain/entities/saved_route.dart';
import '../../../saved_routes/domain/repositories/saved_routes_repository.dart';
import '../../data/datasources/osm_geocoding_datasource.dart';
import '../../data/datasources/planner_draft_local_datasource.dart';
import '../../data/models/planner_draft_model.dart';
import '../../domain/entities/optimized_route.dart';
import '../../domain/entities/route_point.dart';
import '../../domain/usecases/optimize_route_usecase.dart';
import 'route_planner_state.dart';

class RoutePlannerCubit extends Cubit<RoutePlannerState> {
  final OptimizeRouteUseCase _optimize;
  final SavedRoutesRepository _savedRoutes;
  final OsmGeocodingDataSource _geocoding;
  final PlannerDraftLocalDataSource _draft;
  final NetworkInfo _network;

  /// Drives the simulation marker forward; cancelled on stop / reset / close.
  Timer? _simTimer;
  StreamSubscription<Position>? _navSub;

  /// Smoothed compass heading so the drive camera glides on noisy bearings.
  double? _smoothedHeading;

  /// Last emitted navigation progress — used to prevent GPS noise from
  /// regressing the trail (you can't un-drive a segment).
  double _lastNavProgress = 0.0;

  RoutePlannerCubit(
    this._optimize,
    this._savedRoutes,
    this._geocoding,
    this._draft,
    this._network,
  ) : super(const RoutePlannerState());

  /// Coalesces rapid draft writes into one debounced disk write.
  Timer? _persistDebounce;

  /// Tap-to-add debounce/dedup state — see [PlannerConfig] for the windows.
  DateTime? _lastTapAt;
  LatLng? _lastTapPos;

  // ── Bootstrap ──────────────────────────────────────────────

  Future<void> initialize() async {
    // 1) Restore any locally-saved draft FIRST so the user always gets
    //    their points back, even if location / network are unavailable.
    _restoreDraft();

    emit(
      state.copyWith(
        status: RoutePlannerStatus.loadingLocation,
        clearError: true,
      ),
    );

    // 2) Probe connectivity in the background (non-blocking).
    unawaited(_refreshConnectivity());

    try {
      final loc = await LocationUtils.getCurrentLatLng();
      emit(
        state.copyWith(
          status: RoutePlannerStatus.locationReady,
          userLocation: loc,
          // Only recentre on the user when there's no restored route to
          // frame — otherwise keep the draft's geometry in view.
          cameraTarget: state.hasOptimizedRoute || state.hasPoints
              ? state.cameraTarget
              : loc,
        ),
      );
    } on LocationException catch (e) {
      developer.log('Location unavailable: ${e.message}');
      emit(
        state.copyWith(
          status: RoutePlannerStatus.locationReady,
          cameraTarget: _fallbackCameraTarget(),
          errorMessage: _mapLocationError(e),
        ),
      );
    } catch (e) {
      developer.log('initialize() failed', error: e);
      emit(
        state.copyWith(
          status: RoutePlannerStatus.locationReady,
          cameraTarget: _fallbackCameraTarget(),
          errorMessage: AppStrings.errLocationUnavailable,
        ),
      );
    }
  }

  /// Explicit "my location" action for the button docked in the planning
  /// sheet. Unlike [initialize] this ALWAYS recentres on the user: it
  /// refetches GPS and refreshes the blue dot, and the map view pans to it
  /// (see `RouteMapViewState.recenterOnUser`) even when points are already
  /// on screen — so the button never feels dead. On failure it surfaces the
  /// usual location error (with the "Enable location" CTA). Returns `true`
  /// when a fresh fix was obtained, so the caller knows whether to pan.
  /// Instant half of the "my location" action: emits the last-known fix (OS
  /// cache, else our previous fix) so the map can pan *immediately* while a
  /// precise fix is still being acquired. Returns the position used, or null
  /// if none is available yet (cold start with no cache). Pair it with
  /// [recenterOnUser] to refine.
  Future<LatLng?> recenterOnUserCached() async {
    final cached =
        await LocationUtils.getLastKnownLatLng() ?? state.userLocation;
    if (cached != null) {
      emit(
        state.copyWith(
          status: RoutePlannerStatus.locationReady,
          userLocation: cached,
          clearError: true,
        ),
      );
    }
    return cached;
  }

  Future<bool> recenterOnUser({bool surfaceError = true}) async {
    try {
      final loc = await LocationUtils.getCurrentLatLng();
      emit(
        state.copyWith(
          status: RoutePlannerStatus.locationReady,
          userLocation: loc,
          clearError: true,
        ),
      );
      return true;
    } on LocationException catch (e) {
      developer.log('recenterOnUser: location unavailable: ${e.message}');
      // When we already panned to a cached fix, a failed refine stays silent.
      if (surfaceError) emit(state.copyWith(errorMessage: _mapLocationError(e)));
      return false;
    } catch (e) {
      developer.log('recenterOnUser() failed', error: e);
      if (surfaceError) {
        emit(state.copyWith(errorMessage: AppStrings.errLocationUnavailable));
      }
      return false;
    }
  }

  /// When location can't be resolved, keep any restored draft in frame
  /// instead of yanking the camera to the Riyadh fallback.
  LatLng _fallbackCameraTarget() {
    if (state.cameraTarget != null &&
        (state.hasPoints || state.hasOptimizedRoute)) {
      return state.cameraTarget!;
    }
    return const LatLng(MapConfig.fallbackLat, MapConfig.fallbackLon);
  }

  /// Re-checks connectivity and updates [RoutePlannerState.isOffline].
  /// Safe to call from app-resume, banner retry, etc.
  Future<void> refreshConnectivity() => _refreshConnectivity();

  Future<void> _refreshConnectivity() async {
    try {
      final connected = await _network.isConnected;
      if (isClosed) return;
      if (state.isOffline == !connected) return; // no change
      emit(state.copyWith(isOffline: !connected));
    } catch (_) {
      // Never let a connectivity probe crash anything.
    }
  }

  // ── Local draft persistence (offline-safe) ────────────────
  //
  // Every change to points / route / shown segment is written to
  // disk (debounced). Restored on the next launch so nothing is ever
  // lost — closing the app, losing internet, or coming back tomorrow
  // all leave the work intact, Google-Forms style.

  /// Persist on any meaningful change. Transient playback fields
  /// (simulation / navigation progress) are intentionally ignored so we
  /// don't thrash the disk 16×/second.
  @override
  void onChange(Change<RoutePlannerState> change) {
    super.onChange(change);
    final a = change.currentState;
    final b = change.nextState;
    if (a.points != b.points ||
        a.optimizedRoute != b.optimizedRoute ||
        a.displaySegment != b.displaySegment) {
      _schedulePersist();
    }
  }

  void _restoreDraft() {
    try {
      final draft = _draft.read();
      if (draft == null) return;
      final points = draft.toPoints();
      if (points.isEmpty) return;

      final optimized = draft.toOptimizedRoute();
      final target = (optimized != null && optimized.fullPolyline.isNotEmpty)
          ? optimized.fullPolyline.first
          : points.first.latLng;

      emit(
        state.copyWith(
          status: optimized != null
              ? RoutePlannerStatus.optimizedSuccess
              : RoutePlannerStatus.pointsUpdated,
          points: points,
          optimizedRoute: optimized,
          stopFractions: optimized != null ? _fractionsFor(optimized) : null,
          displaySegment: _segmentFromName(draft.displaySegment),
          cameraTarget: target,
          draftRestored: true,
        ),
      );
    } catch (e, st) {
      developer.log('restoreDraft failed', error: e, stackTrace: st);
    }
  }

  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(PlannerConfig.persistDebounce, _persistNow);
  }

  void _persistNow() {
    try {
      final draft = PlannerDraftModel.fromState(
        points: state.points,
        optimizedRoute: state.optimizedRoute,
        displaySegment: state.displaySegment.name,
        routingMode: RoutingConfig.defaultRoutingMode,
      );
      unawaited(_draft.write(draft));
    } catch (e, st) {
      developer.log('persistDraft failed', error: e, stackTrace: st);
    }
  }

  RouteSegment _segmentFromName(String name) {
    switch (name) {
      case 'go':
        return RouteSegment.go;
      case 'returnLeg':
        return RouteSegment.returnLeg;
      default:
        return RouteSegment.full;
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

  /// Forward-geocode [query] into a pick-one list of matches. Backs the
  /// single-address search in the "add a point" chooser.
  Future<List<GeoSearchResult>> searchAddresses(String query) =>
      _geocoding.searchAddresses(query);

  /// Adds a point at [position]. When [address] is supplied (e.g. the label
  /// the user picked from address search) it is shown immediately and the
  /// background reverse-geocode is skipped — otherwise the address is resolved
  /// from the coordinate.
  Future<void> addPoint(
    LatLng position, {
    bool optional = false,
    String? address,
  }) async {
    DebugLog.add(
      'addPoint() ENTER pos=${position.latitude.toStringAsFixed(6)},'
      '${position.longitude.toStringAsFixed(6)} optional=$optional '
      'pointsBefore=${state.points.length}',
    );
    // Guard 1: swallow a jittered double-tap within the debounce window.
    final now = DateTime.now();
    if (_lastTapAt != null &&
        now.difference(_lastTapAt!) < PlannerConfig.addPointDebounce) {
      final gapMs = now.difference(_lastTapAt!).inMilliseconds;
      final dedupRadius =
          PlannerConfig.minSeparationMeters * PlannerConfig.debounceDedupFactor;
      if (_lastTapPos != null &&
          DistanceUtils.haversineKm(_lastTapPos!, position) * 1000 <
              dedupRadius) {
        DebugLog.add(
          'addPoint() ✋ REJECTED debounce — gap=${gapMs}ms '
          '(< ${PlannerConfig.addPointDebounce.inMilliseconds}ms) near previous tap',
        );
        return;
      }
      DebugLog.add(
        'addPoint() debounce window (gap=${gapMs}ms) but far from last tap '
        '— allowed',
      );
    }
    _lastTapAt = now;
    _lastTapPos = position;

    // Guard 2: don't stack a new point on top of an existing one.
    for (final p in state.points) {
      final meters = DistanceUtils.haversineKm(p.latLng, position) * 1000;
      if (meters < PlannerConfig.minSeparationMeters) {
        DebugLog.add(
          'addPoint() ✋ REJECTED separation — ${meters.toStringAsFixed(1)}m '
          '(< ${PlannerConfig.minSeparationMeters}m) from "${p.label}"',
        );
        return;
      }
    }

    _cancelSimTimer();
    _cancelNavigationStream();

    final isFirst = state.points.isEmpty;
    // The depot is never optional — the trip has to start somewhere.
    final asOptional = optional && !isFirst;
    final id = 'p_${now.microsecondsSinceEpoch}';

    final label = isFirst
        ? AppStrings.departure
        : asOptional
        ? AppStrings.optionalStopLabel(_optionalCount() + 1)
        : AppStrings.stopLabel(_mandatoryStopCount() + 1);

    final providedAddress = address?.trim();
    final tentative = RoutePoint(
      id: id,
      latitude: position.latitude,
      longitude: position.longitude,
      label: label,
      address: (providedAddress != null && providedAddress.isNotEmpty)
          ? providedAddress
          : null,
      weight: RoutingConfig.defaultStopWeight,
      kind: isFirst ? RoutePointKind.depot : RoutePointKind.stop,
      optional: asOptional,
    );

    DebugLog.add(
      'addPoint() ✅ ACCEPTED "$label" '
      '(${isFirst ? 'depot' : asOptional ? 'optional' : 'stop'}) id=$id '
      '→ total=${state.points.length + 1}',
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
        // The pin has been placed — leave the empty-state manual flow.
        manualPlacement: false,
      ),
    );

    // A point added via address search already carries its label — only
    // coordinates (manual pin / WhatsApp) need a reverse lookup.
    if (tentative.address == null) {
      _resolveAddress(tentative)
          .then((withAddr) {
            if (withAddr == null) return;
            final idx = state.points.indexWhere((p) => p.id == withAddr.id);
            if (idx < 0) return;
            final updated = [...state.points]..[idx] = withAddr;
            emit(state.copyWith(points: updated));
          })
          .catchError((_) {});
    }
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
    _resolveAddress(updated)
        .then((withAddr) {
          if (withAddr == null) return;
          final i = state.points.indexWhere((p) => p.id == withAddr.id);
          if (i < 0) return;
          final list = [...state.points]..[i] = withAddr;
          emit(state.copyWith(points: list));
        })
        .catchError((_) {});
  }

  // ── Move a point on the map (#9) ──────────────────────────

  /// Enter "move" mode for [id]: the planner collapses to a full-screen
  /// map with a reticle, centred on the point, so the user can drop it at
  /// a new spot. No-op if the point doesn't exist.
  void beginMovePoint(String id) {
    final idx = state.points.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    _cancelSimTimer();
    _cancelNavigationStream();
    emit(
      state.copyWith(
        movingPointId: id,
        cameraTarget: state.points[idx].latLng,
        clearError: true,
        simulationActive: false,
        simulationPlaying: false,
        navigationActive: false,
      ),
    );
  }

  /// Commit the in-progress move to [newPosition] and leave move mode.
  void commitMovePoint(LatLng newPosition) {
    final id = state.movingPointId;
    if (id == null) return;
    // Leave move mode first so the marker reappears at its new home.
    emit(state.copyWith(clearMovingPoint: true));
    updatePointPosition(id, newPosition);
  }

  void cancelMovePoint() {
    if (state.movingPointId == null) return;
    emit(state.copyWith(clearMovingPoint: true));
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

  // ── Include / skip a stop ─────────────────────────────────
  //
  // One simple toggle per non-depot stop: it's either in the route or
  // skipped. A skipped stop stays on the map (dimmed) but is left out of
  // the optimize request. Changing it invalidates any optimized result.

  /// Include or skip the stop [id]. Skipping excludes it from routing (it
  /// stays on the map, dimmed); including makes it a routed stop again. The
  /// depot can never be skipped.
  void setPointIncluded(String id, bool included) {
    final idx = state.points.indexWhere((p) => p.id == id);
    if (idx < 0) return;
    final p = state.points[idx];
    if (p.isDepot || p.isRoutable == included) return;

    final updated = included
        ? p.copyWith(optional: false, active: true)
        : p.copyWith(optional: true, active: false);
    final list = [...state.points]..[idx] = updated;
    _emitPointsEdit(_relabel(list));
  }

  /// Re-include the skipped stop [id] and immediately re-run optimization to
  /// fold it into the route. Called after the user confirms the "add this
  /// stop back" dialog (see [showActivateStopDialog]).
  Future<void> activateAndReoptimize(String id) async {
    setPointIncluded(id, true);
    await optimize();
  }

  /// Shared emit for an in-place edit of the working point list:
  /// invalidates the route and stops any running playback.
  void _emitPointsEdit(List<RoutePoint> list) {
    _cancelSimTimer();
    _cancelNavigationStream();
    emit(
      state.copyWith(
        points: list,
        status: RoutePlannerStatus.pointsUpdated,
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
  }

  void clearAll() {
    _cancelSimTimer();
    _cancelNavigationStream();
    // Explicit, user-initiated clear: also wipe the saved draft so it
    // doesn't get restored on the next launch. (Data is only ever
    // deleted when the user asks for it.)
    _persistDebounce?.cancel();
    unawaited(_draft.clear());
    emit(
      state.copyWith(
        points: const [],
        status: RoutePlannerStatus.pointsUpdated,
        clearOptimizedRoute: true,
        clearError: true,
        displaySegment: RouteSegment.full,
        draftRestored: false,
        manualPlacement: false,
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

  /// Empty-state "drop a pin manually" flow: reveals the centre crosshair so
  /// the user can aim the map before confirming the first point.
  void beginManualPlacement() {
    if (!state.manualPlacement) {
      emit(state.copyWith(manualPlacement: true));
    }
  }

  /// Leaves the manual-placement flow (e.g. the user backed out of it),
  /// hiding the crosshair again while the route is still empty.
  void cancelManualPlacement() {
    if (state.manualPlacement) {
      emit(state.copyWith(manualPlacement: false));
    }
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
        final parsed = await MapLinkResolver.parseMapLine(line);
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

    // Only routable points (mandatory + active optional) go to the
    // optimizer. Deactivated optional points sit out this run but are
    // preserved so the user can switch them back on later.
    final routable = state.points.where((p) => p.isRoutable).toList();
    final deactivated = state.points.where((p) => p.isDeactivated).toList();

    if (routable.length < 2) {
      // Distinguish "not enough points at all" from "you switched your
      // only stops off" so the message is actionable.
      final hasInactiveStops = deactivated.isNotEmpty;
      emit(
        state.copyWith(
          status: RoutePlannerStatus.optimizedFailure,
          errorMessage: hasInactiveStops
              ? AppStrings.errNoActiveStops
              : AppStrings.errMinTwoPoints,
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

    final result = await _optimize(points: routable);

    result.when(
      success: (route) {
        emit(
          state.copyWith(
            status: RoutePlannerStatus.optimizedSuccess,
            optimizedRoute: route,
            stopFractions: _fractionsFor(route),
            // Keep deactivated optional points around (dimmed on the map,
            // not part of the route) so deactivation stays reversible.
            points: [
              ..._stripReturnDuplicate(route.orderedPoints),
              ...deactivated,
            ],
            displaySegment: RouteSegment.full,
            isOffline: false,
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
            // A network failure flips the offline banner on; the draft is
            // already saved locally so nothing is lost.
            isOffline: f is NetworkFailure ? true : state.isOffline,
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
    DebugLog.nav('startNavigation() ENTER');
    final route = state.optimizedRoute;
    if (route == null) {
      DebugLog.nav('startNavigation() ✋ no optimizedRoute → abort');
      return;
    }

    _cancelSimTimer();
    _cancelNavigationStream();

    try {
      DebugLog.nav('startNavigation() requesting current GPS fix…');
      final loc = await LocationUtils.getCurrentLatLng();
      // Only trust GPS for the starting progress when the fix is actually on
      // the route. Off-route (Simulator, or before reaching the start) we
      // begin at 0 instead of snapping near the end of the polyline.
      final initialProgress = _onRouteProgress(route.fullPolyline, loc) ?? 0.0;
      DebugLog.nav(
        'startNavigation() got fix=${loc.latitude.toStringAsFixed(6)},'
        '${loc.longitude.toStringAsFixed(6)} '
        'initialProgress=${initialProgress.toStringAsFixed(4)} '
        '(onRoute=${_onRouteProgress(route.fullPolyline, loc) != null}) '
        'polylineLen=${route.fullPolyline.length}',
      );
      // Keep the first stop as a fallback target for non-live surfaces; the
      // live map camera itself derives its forward view from navigationProgress.
      final firstStop = route.orderedPoints.length > 1
          ? route.orderedPoints[1].latLng
          : loc;
      _lastNavProgress = initialProgress;
      emit(
        state.copyWith(
          userLocation: loc,
          cameraTarget: firstStop,
          navigationActive: true,
          navigationProgress: initialProgress,
          navigationStopIndex: 1,
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
        distanceFilter: NavigationConfig.distanceFilterMeters,
      );
      _navSub = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(_onNavigationPosition, onError: _onNavigationError);
      DebugLog.nav(
        'startNavigation() ✅ subscribed to position stream '
        '(accuracy=high, distanceFilter=5m). Waiting for GPS ticks…',
      );
    } on LocationException catch (e) {
      DebugLog.nav('startNavigation() ✋ LocationException: ${e.message}');
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
      DebugLog.nav('startNavigation() ✋ error: $e');
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
        navigationStopIndex: 1,
        clearNavigationHeading: true,
        clearNavigationSpeed: true,
      ),
    );
  }

  /// Driver taps "Arrived" — mark the current target stop as done and
  /// advance to the next one. When the last stop (return depot) is marked
  /// done the trip ends automatically.
  void markCurrentStopDone() {
    final route = state.optimizedRoute;
    if (route == null || !state.navigationActive) return;
    final next = state.navigationStopIndex + 1;
    if (next >= route.orderedPoints.length) {
      HapticFeedback.heavyImpact();
      stopNavigation();
      return;
    }
    HapticFeedback.mediumImpact();
    emit(state.copyWith(navigationStopIndex: next));
  }

  /// Advances the debug driver forward along the planned polyline.
  /// DEBUG ONLY — no-op in release builds; remove before publishing.
  void debugStepForward() {
    if (!kDebugMode) return;
    final route = state.optimizedRoute;
    if (route == null || !state.navigationActive) return;

    final totalKm = DistanceUtils.pathLengthKm(route.fullPolyline);
    if (totalKm <= 0) return;

    final newProgress =
        (state.navigationProgress + NavigationConfig.debugStepKm / totalKm)
            .clamp(0.0, 1.0);
    final sample = PolylineUtils.sampleAt(route.fullPolyline, newProgress);
    if (sample == null) return;
    final loc = sample.point;
    _lastNavProgress = newProgress;

    // Auto-advance the target stop as the synthetic driver steps past it,
    // ending the trip once the final stop is reached.
    var stopIndex = state.navigationStopIndex;
    while (stopIndex < state.stopFractions.length &&
        newProgress >= state.stopFractions[stopIndex]) {
      if (stopIndex + 1 >= route.orderedPoints.length) {
        HapticFeedback.heavyImpact();
        stopNavigation();
        return;
      }
      stopIndex++;
    }

    emit(
      state.copyWith(
        userLocation: loc,
        cameraTarget: loc,
        navigationProgress: newProgress,
        navigationStopIndex: stopIndex,
      ),
    );
  }

  void _onNavigationPosition(Position position) {
    // Raw GPS payload — the single most useful line for sim-vs-device:
    // the Simulator typically reports heading=-1 and speed=0, so the
    // heading-up camera below never rotates the way it does on a phone.
    DebugLog.nav(
      'GPS tick lat=${position.latitude.toStringAsFixed(6)} '
      'lon=${position.longitude.toStringAsFixed(6)} '
      'heading=${position.heading.toStringAsFixed(1)} '
      'speed=${position.speed.toStringAsFixed(2)}m/s '
      'acc=${position.accuracy.toStringAsFixed(1)}m',
    );
    if (!state.navigationActive) {
      DebugLog.nav('GPS tick ignored — navigation not active');
      return;
    }
    final route = state.optimizedRoute;
    if (route == null) {
      DebugLog.nav('GPS tick → no route, stopping navigation');
      stopNavigation();
      return;
    }

    // The iOS Simulator delivers a *mocked* fix parked far off the planned
    // route. Feeding it to the projection jumped progress to ~1.0 and fired
    // bogus arrivals, and it overrode the debug step button. Ignore mocked
    // fixes during a drive — the debug step button is the driver there.
    if (position.isMocked) {
      DebugLog.nav(
        'mocked GPS ignored during drive — use the debug step button '
        '[Simulator]',
      );
      return;
    }

    final loc = LatLng(position.latitude, position.longitude);
    final rawHeading = position.heading.isFinite && position.heading >= 0
        ? position.heading
        : null;
    final speed = position.speed.isFinite && position.speed >= 0
        ? position.speed
        : null;

    // Heading is meaningless when barely moving — keep the last good one
    // instead of letting the camera spin in place.
    if (rawHeading != null &&
        (speed == null || speed > NavigationConfig.minSpeedForHeadingMps)) {
      _smoothedHeading = _blendHeading(_smoothedHeading, rawHeading);
    } else {
      DebugLog.nav(
        'heading FROZEN (rawHeading=$rawHeading, speed=$speed ≤ '
        '${NavigationConfig.minSpeedForHeadingMps}) '
        '→ camera keeps ${_smoothedHeading?.toStringAsFixed(1)} '
        '[on Simulator this is why drive mode never turns]',
      );
    }

    // Only let GPS drive progress / arrival when the fix is genuinely on the
    // route. Off-route fixes would otherwise snap progress to the nearest
    // polyline point (often near the end) and fire bogus arrivals; when
    // off-route we freeze both and keep whatever the last good value was.
    final onRouteProg = _onRouteProgress(route.fullPolyline, loc);
    var progress = state.navigationProgress;
    var stopIndex = state.navigationStopIndex;

    if (onRouteProg != null) {
      // Monotonic progress: GPS noise can briefly regress the fraction;
      // never go backwards — you can't un-drive a road.
      progress = onRouteProg < _lastNavProgress ? _lastNavProgress : onRouteProg;
      _lastNavProgress = progress;

      // ── Auto-arrival: advance when within the arrival radius of the
      // current target stop, or once progress passes its fraction. ──
      if (stopIndex < route.orderedPoints.length) {
        final targetStop = route.orderedPoints[stopIndex];
        final distToStop =
            DistanceUtils.haversineKm(loc, targetStop.latLng) * 1000;
        final stopIdx = stopIndex;
        final stopPassed = stopIdx < state.stopFractions.length &&
            progress >= state.stopFractions[stopIdx];
        final withinRadius =
            distToStop <= NavigationConfig.arrivalRadiusMeters;

        if (withinRadius || stopPassed) {
          final next = stopIndex + 1;
          if (next >= route.orderedPoints.length) {
            // Last stop (return depot) reached — end the trip.
            HapticFeedback.heavyImpact();
            stopNavigation();
            return;
          }
          HapticFeedback.mediumImpact();
          stopIndex = next;
          DebugLog.nav(
            'auto-arrived at stop $stopIdx via '
            '${withinRadius ? 'radius (${distToStop.toStringAsFixed(0)}m)' : 'progress (${progress.toStringAsFixed(4)})'} '
            '→ advancing to stopIndex=$stopIndex',
          );
        }
      }
    } else {
      DebugLog.nav(
        'off route — progress & arrival frozen at '
        '${progress.toStringAsFixed(4)} [off-route fix]',
      );
    }

    DebugLog.nav(
      '→ emit progress=${progress.toStringAsFixed(4)} '
      'smoothedHeading=${_smoothedHeading?.toStringAsFixed(1)} '
      'speed=${speed?.toStringAsFixed(2)} stopIndex=$stopIndex',
    );

    emit(
      state.copyWith(
        userLocation: loc,
        cameraTarget: loc,
        navigationProgress: progress,
        navigationStopIndex: stopIndex,
        // Null keeps the previous heading (copyWith semantics), so the
        // camera never snaps back to north on a dropped bearing.
        navigationHeading: _smoothedHeading,
        navigationSpeedMps: speed,
      ),
    );
  }

  /// Exponential smoother for [next] toward [prev] along the shortest arc
  /// (handles the 0°/360° wrap).
  double _blendHeading(double? prev, double next) {
    if (prev == null) return next;
    final delta = ((next - prev + 540) % 360) - 180;
    return (prev + delta * NavigationConfig.headingSmoothingFactor + 360) % 360;
  }

  void _onNavigationError(Object error) {
    DebugLog.nav('⚠️ position STREAM ERROR: $error');
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
    _smoothedHeading = null;
    _lastNavProgress = 0.0;
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
      routingMode: RoutingConfig.defaultRoutingMode,
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
    final route = saved.toOptimizedRoute();
    emit(
      state.copyWith(
        status: RoutePlannerStatus.optimizedSuccess,
        points: _stripReturnDuplicate(saved.orderedPoints),
        optimizedRoute: route,
        stopFractions: _fractionsFor(route),
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
    if (state.optimizedRoute == null) {
      DebugLog.sim('startSimulation() ✋ no optimizedRoute → abort');
      return;
    }
    DebugLog.sim(
      'startSimulation() ENTER — base playback '
      '${SimulationConfig.baseDuration.inSeconds}s, '
      'tick every ${SimulationConfig.tickInterval.inMilliseconds}ms',
    );
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
        // The preview always opens panoramic — the whole route in frame —
        // so the user sees every stop before drilling into follow/chase.
        simulationCameraMode: SimulationCameraMode.overview,
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

  /// Scrub to an arbitrary point in the trip (video-style). Pauses playback so
  /// the playhead stays where the user dropped it; they hit play to run from
  /// there (handy for replaying a stretch of the route).
  void seekSimulation(double progress) {
    if (!state.simulationActive) return;
    _cancelSimTimer();
    emit(
      state.copyWith(
        simulationProgress: progress.clamp(0.0, 1.0),
        simulationPlaying: false,
      ),
    );
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
    _simTimer = Timer.periodic(
      SimulationConfig.tickInterval,
      (_) => _onSimTick(),
    );
  }

  void _cancelSimTimer() {
    _simTimer?.cancel();
    _simTimer = null;
  }

  void _onSimTick() {
    if (!state.simulationActive || !state.simulationPlaying) return;

    final totalMs =
        SimulationConfig.baseDuration.inMilliseconds /
        state.simulationSpeed.clamp(
          SimulationConfig.minSpeed,
          SimulationConfig.maxSpeed,
        );
    final step = SimulationConfig.tickInterval.inMilliseconds / totalMs;
    final next = (state.simulationProgress + step).clamp(0.0, 1.0);

    if (next >= 1.0) {
      _cancelSimTimer();
      emit(state.copyWith(simulationProgress: 1.0, simulationPlaying: false));
      return;
    }
    emit(state.copyWith(simulationProgress: next));
  }

  // ── Internals ──────────────────────────────────────────────

  /// Projected progress (0..1) of [point] along [path] — but only when the
  /// fix is genuinely on the route (within
  /// [NavigationConfig.onRouteThresholdMeters]). Returns null when the fix
  /// is too far off the route to trust (Simulator, or the driver hasn't
  /// reached the start), so callers leave progress where it is instead of
  /// snapping to the nearest polyline point.
  double? _onRouteProgress(List<LatLng> path, LatLng point) {
    if (path.length < 2) return null;
    final projected = _progressAlongPath(path, point);
    final nearest = PolylineUtils.sampleAt(path, projected)?.point;
    if (nearest == null) return null;
    final offRouteMeters = DistanceUtils.haversineKm(nearest, point) * 1000;
    if (offRouteMeters > NavigationConfig.onRouteThresholdMeters) return null;
    return projected;
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
    // Promoting a stop to depot must also clear any optional/inactive
    // flags — the depot is always mandatory and active.
    return [
      points.first.copyWith(
        kind: RoutePointKind.depot,
        optional: false,
        active: true,
      ),
      ...points.skip(1).map((p) => p.copyWith(kind: RoutePointKind.stop)),
    ];
  }

  /// Canonical labels: depot first, then mandatory stops numbered
  /// separately from optional ones ("Stop 1, 2…" vs "Optional 1, 2…").
  List<RoutePoint> _relabel(List<RoutePoint> points) {
    var stopCounter = 1;
    var optionalCounter = 1;
    return points.map((p) {
      if (p.isDepot) return p.copyWith(label: AppStrings.departure);
      if (p.optional) {
        return p.copyWith(
          label: AppStrings.optionalStopLabel(optionalCounter++),
        );
      }
      return p.copyWith(label: AppStrings.stopLabel(stopCounter++));
    }).toList();
  }

  int _mandatoryStopCount() =>
      state.points.where((p) => !p.isDepot && !p.optional).length;

  int _optionalCount() => state.points.where((p) => p.optional).length;

  /// True arc-length fraction of each ordered stop along the route, so
  /// playback "visited" state flips exactly as the vehicle passes (stops
  /// aren't evenly spaced). Computed once per route.
  List<double> _fractionsFor(OptimizedRoute route) {
    if (route.fullPolyline.length < 2) return const [];
    return PolylineUtils.stopFractions(
      route.fullPolyline,
      route.orderedPoints.map((p) => p.latLng).toList(),
    );
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
    // Flush any pending draft write so work isn't lost if the app is
    // being torn down mid-debounce.
    if (_persistDebounce?.isActive ?? false) {
      _persistDebounce!.cancel();
      _persistNow();
    }
    return super.close();
  }
}
