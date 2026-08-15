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
import '../../data/datasources/osrm_routing_datasource.dart';
import '../../data/datasources/planner_draft_local_datasource.dart';
import '../../data/models/planner_draft_model.dart';
import '../../domain/entities/optimized_route.dart';
import '../../domain/entities/route_point.dart';
import '../../domain/entities/stop_time_window.dart';
import '../../domain/usecases/optimize_route_usecase.dart';
import '../widgets/map_geometry.dart';
import 'route_planner_state.dart';

class RoutePlannerCubit extends Cubit<RoutePlannerState> {
  final OptimizeRouteUseCase _optimize;
  final SavedRoutesRepository _savedRoutes;
  final OsmGeocodingDataSource _geocoding;
  final PlannerDraftLocalDataSource _draft;
  final NetworkInfo _network;
  final OsrmRoutingDataSource _routing;

  /// Drives the simulation marker forward; cancelled on stop / reset / close.
  Timer? _simTimer;
  StreamSubscription<Position>? _navSub;

  /// Smoothed compass heading so the drive camera glides on noisy bearings.
  double? _smoothedHeading;

  /// Smoothed GPS speed (m/s) — drives the adaptive zoom without the
  /// camera "breathing" on every noisy speed sample.
  double? _smoothedSpeed;

  /// Last emitted navigation progress — used to prevent GPS noise from
  /// regressing the trail (you can't un-drive a segment).
  double _lastNavProgress = 0.0;

  /// Service-point state machine: true once the driver has entered the
  /// service radius of the *current* target stop. Armed → leaving beyond
  /// [NavigationConfig.autoServeExitMeters] auto-completes the point.
  bool _enteredServiceRadius = false;

  // ── Deviation → automatic reroute state ──
  /// Consecutive deviating fixes (spaced by real movement) seen so far.
  int _offRouteFixCount = 0;

  /// The last fix the deviation counter accepted, enforcing
  /// [NavigationConfig.rerouteFixSpacingMeters] between counted fixes.
  LatLng? _lastOffRouteCounted;

  /// True while a reroute fetch is in flight — only ever one at a time.
  bool _rerouting = false;

  /// No reroute may start before this instant (cooldown between attempts
  /// and backoff after a failed fetch).
  DateTime? _rerouteBackoffUntil;

  RoutePlannerCubit(
    this._optimize,
    this._savedRoutes,
    this._geocoding,
    this._draft,
    this._network,
    this._routing,
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
          maneuverFractions: optimized != null
              ? _maneuverFractionsFor(optimized)
              : null,
          displaySegment: _segmentFromName(draft.displaySegment),
          cameraTarget: target,
          draftRestored: true,
          // A departure that's already in the past belongs to yesterday's
          // plan — fall back to "now" rather than resurrecting a stale clock.
          departureAt:
              draft.departureAt != null &&
                  draft.departureAt!.isAfter(DateTime.now())
              ? draft.departureAt
              : null,
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
        departureAt: state.departureAt,
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
    final hasLoc = state.userLocation != null;
    // Departure is always the user's current location: the first dropped pin is
    // a destination, and we inject a current-location depot ahead of it. Only
    // when no location is available does the first pin act as the depot.
    final firstAsDepot = isFirst && !hasLoc;
    final asOptional = optional && !firstAsDepot;
    final id = 'p_${now.microsecondsSinceEpoch}';

    final label = firstAsDepot
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
      kind: firstAsDepot ? RoutePointKind.depot : RoutePointKind.stop,
      optional: asOptional,
    );

    DebugLog.add(
      'addPoint() ✅ ACCEPTED "$label" '
      '(${firstAsDepot ? 'depot' : asOptional ? 'optional' : 'stop'}) id=$id '
      '→ total=${state.points.length + 1}',
    );

    final newPoints = <RoutePoint>[
      if (isFirst && hasLoc) _currentLocationDepot(),
      ...state.points,
      tentative,
    ];

    emit(
      state.copyWith(
        status: RoutePlannerStatus.pointsUpdated,
        points: newPoints,
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
    // If only the auto-departure is left (no destinations), reset to the empty
    // state so the user is back at "add a destination".
    final hasDestinations = updated.any((p) => !p.isDepot);
    final next = hasDestinations
        ? _relabel(_ensureSingleDepot(updated))
        : const <RoutePoint>[];

    emit(
      state.copyWith(
        points: next,
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

  // ── Arrival time windows ──────────────────────────────────
  //
  // A stop can carry a clock window ("be there between 14:00 and 15:30").
  // It's sent to the solver as minutes after departure, so changing either
  // a window or the departure time invalidates the current route.

  /// Pin an arrival window to the stop [id]. The depot is the trip's start,
  /// not a delivery, so it can't have one.
  void setPointTimeWindow(String id, StopTimeWindow window) {
    final idx = state.points.indexWhere((p) => p.id == id);
    if (idx < 0 || state.points[idx].isDepot) return;

    final list = [...state.points]..[idx] = state.points[idx].copyWith(
      timeWindow: window,
      // A freshly chosen window hasn't been checked against a route yet.
      timeWindowMissed: false,
      clearEta: true,
    );
    _emitPointsEdit(list);
  }

  /// Drop the arrival window from stop [id] — it becomes a stop the
  /// optimizer may schedule whenever it likes.
  void clearPointTimeWindow(String id) {
    final idx = state.points.indexWhere((p) => p.id == id);
    if (idx < 0 || state.points[idx].timeWindow == null) return;

    final list = [...state.points]..[idx] = state.points[idx].copyWith(
      clearTimeWindow: true,
      clearEta: true,
    );
    _emitPointsEdit(list);
  }

  /// Push every missed deadline out by exactly the amount it was missed by
  /// (plus a small buffer), then re-solve.
  ///
  /// The one-tap answer to "I can't make it": the stops stay, the times
  /// become achievable, and the user sees the new clock rather than having
  /// to guess a workable deadline themselves.
  Future<void> relaxMissedTimeWindows() async {
    final list = state.points.map((p) {
      final window = p.timeWindow;
      final lateBy = p.latenessMinutes;
      if (!p.timeWindowMissed || window == null || lateBy == null) return p;
      return p.copyWith(
        timeWindow: window.copyWith(
          endMinuteOfDay:
              (window.endMinuteOfDay + lateBy + _lateWindowBufferMinutes) %
              StopTimeWindow.minutesPerDay,
        ),
        timeWindowMissed: false,
        clearLateness: true,
      );
    }).toList();

    if (list == state.points) return;
    _emitPointsEdit(list);
    await optimize();
  }

  /// Leave earlier by the worst overshoot (plus a buffer) so every deadline
  /// comes back within reach, then re-solve.
  ///
  /// Only meaningful when the trip departs in the future — you can't set off
  /// before now. [canDepartEarlier] gates the UI on exactly that.
  Future<void> departEarlierToMakeWindows() async {
    final shift = requiredEarlierDepartureMinutes;
    if (shift == null) return;
    final departure = state.departureAt;
    if (departure == null) return;

    setDepartureAt(departure.subtract(Duration(minutes: shift)));
    await optimize();
  }

  /// Minutes the departure would have to move earlier for every missed
  /// deadline to fit, or null when nothing is running late.
  int? get requiredEarlierDepartureMinutes {
    var worst = 0;
    for (final p in state.points) {
      final lateBy = p.latenessMinutes;
      if (p.timeWindowMissed && lateBy != null && lateBy > worst) {
        worst = lateBy;
      }
    }
    return worst == 0 ? null : worst + _lateWindowBufferMinutes;
  }

  /// True when setting off earlier is actually possible: the trip has an
  /// explicit future departure, and the shift wouldn't push it into the past.
  bool get canDepartEarlier {
    final shift = requiredEarlierDepartureMinutes;
    final departure = state.departureAt;
    if (shift == null || departure == null) return false;
    return departure
        .subtract(Duration(minutes: shift))
        .isAfter(DateTime.now());
  }

  /// Slack added when repairing a missed window, so a route that only just
  /// fit doesn't come back late again on the next solve.
  static const int _lateWindowBufferMinutes = 10;

  /// Set the wall-clock moment the trip starts, which every window is
  /// measured from. Passing null goes back to "leaving now".
  void setDepartureAt(DateTime? departure) {
    if (state.departureAt == departure) return;
    _cancelSimTimer();
    _cancelNavigationStream();
    emit(
      state.copyWith(
        departureAt: departure,
        clearDepartureAt: departure == null,
        status: RoutePlannerStatus.pointsUpdated,
        // Windows are relative to departure, so the solved order no longer
        // holds once it moves.
        clearOptimizedRoute: true,
        clearError: true,
        simulationActive: false,
        simulationPlaying: false,
        simulationProgress: 0.0,
        navigationActive: false,
        navigationProgress: 0.0,
      ),
    );
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

    // Departure tracks the user's live location: refresh the auto-depot to the
    // latest fix so the route always starts from where they are now.
    final basePoints = state.userLocation == null
        ? state.points
        : [
            for (final p in state.points)
              p.id == 'depot_current'
                  ? p.copyWith(
                      latitude: state.userLocation!.latitude,
                      longitude: state.userLocation!.longitude,
                    )
                  : p,
          ];

    // Only routable points (mandatory + active optional) go to the
    // optimizer. Deactivated optional points sit out this run but are
    // preserved so the user can switch them back on later.
    final routable = basePoints.where((p) => p.isRoutable).toList();
    final deactivated = basePoints.where((p) => p.isDeactivated).toList();

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

    final result = await _optimize(
      points: routable,
      departureAt: state.departureAt,
    );

    result.when(
      success: (route) {
        emit(
          state.copyWith(
            status: RoutePlannerStatus.optimizedSuccess,
            optimizedRoute: route,
            stopFractions: _fractionsFor(route),
            maneuverFractions: _maneuverFractionsFor(route),
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
      _enteredServiceRadius = false;
      emit(
        state.copyWith(
          userLocation: loc,
          cameraTarget: firstStop,
          navigationActive: true,
          navigationProgress: initialProgress,
          navigationStopIndex: 1,
          navigationArrived: false,
          clearNavigationHeading: true,
          clearNavigationSpeed: true,
          clearNavigationStopDistance: true,
          // Fractions may be missing for routes restored from older
          // drafts/saved records — recompute so turn guidance works.
          stopFractions: state.stopFractions.length ==
                  route.orderedPoints.length
              ? state.stopFractions
              : _fractionsFor(route),
          maneuverFractions:
              state.maneuverFractions.length == route.maneuvers.length
              ? state.maneuverFractions
              : _maneuverFractionsFor(route),
          simulationActive: false,
          simulationPlaying: false,
          simulationProgress: 0.0,
          displaySegment: RouteSegment.full,
          clearError: true,
        ),
      );

      _navSub = Geolocator.getPositionStream(
        locationSettings: _navLocationSettings(),
      ).listen(_onNavigationPosition, onError: _onNavigationError);
      DebugLog.nav(
        'startNavigation() ✅ subscribed to position stream '
        '(navigation accuracy, distanceFilter='
        '${NavigationConfig.distanceFilterMeters}m). Waiting for GPS ticks…',
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

  /// Navigation-grade stream settings per platform. The zero distance
  /// filter keeps fixes coming (~1 Hz) even while slowing to a stop — the
  /// map's render interpolator depends on that steady cadence.
  LocationSettings _navLocationSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: NavigationConfig.distanceFilterMeters,
        intervalDuration: NavigationConfig.androidUpdateInterval,
      );
    }
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: NavigationConfig.distanceFilterMeters,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: NavigationConfig.distanceFilterMeters,
    );
  }

  void stopNavigation() {
    _cancelNavigationStream();
    emit(
      state.copyWith(
        navigationActive: false,
        navigationProgress: 0.0,
        navigationStopIndex: 1,
        navigationArrived: false,
        isRerouting: false,
        clearNavigationHeading: true,
        clearNavigationSpeed: true,
        clearNavigationStopDistance: true,
      ),
    );
  }

  /// Driver taps "Point Served" — manual completion, always wins over the
  /// automatic fallback. Marks the current target stop as done and
  /// activates the next one; serving the last point ends the trip.
  void servePoint() {
    if (state.optimizedRoute == null || !state.navigationActive) return;
    HapticFeedback.mediumImpact();
    _advanceServicePoint();
  }

  /// Back-compat alias for [servePoint].
  void markCurrentStopDone() => servePoint();

  /// Mid-trip re-plan: the trip went sideways (wrong turns, traffic, a
  /// manual detour) — re-run the optimizer for the *unserved* stops from
  /// the driver's current position, then jump straight back into the
  /// drive. Served stops stay served (they're dropped from the new plan);
  /// deactivated optional points survive on the map; a simulated debug
  /// drive restarts simulated so desk testing keeps working.
  Future<void> reoptimizeRemaining() async {
    final route = state.optimizedRoute;
    if (route == null || !state.navigationActive || state.isOptimizing) {
      return;
    }

    final from = state.userLocation ?? route.orderedPoints.first.latLng;
    final idx = state.navigationStopIndex.clamp(
      0,
      route.orderedPoints.length - 1,
    );
    // Everything still ahead of the driver, minus depot entries — the new
    // plan gets its own departure (and return) at the current position,
    // matching the app's "routes anchor to where you are now" model.
    final unserved = route.orderedPoints
        .sublist(idx)
        .where((p) => !p.isDepot)
        .toList();
    if (unserved.isEmpty) return; // only the return leg left — nothing to plan
    final deactivated = state.points.where((p) => p.isDeactivated).toList();
    final wasSim = kDebugMode && debugDriveSimActive;

    DebugLog.nav(
      'reoptimizeRemaining() from='
      '${from.latitude.toStringAsFixed(6)},${from.longitude.toStringAsFixed(6)} '
      'unserved=${unserved.length} wasSim=$wasSim',
    );
    _cancelNavigationStream();
    emit(
      state.copyWith(
        status: RoutePlannerStatus.pointsUpdated,
        userLocation: from,
        points: [
          RoutePoint(
            id: 'depot_current',
            latitude: from.latitude,
            longitude: from.longitude,
            label: AppStrings.departure,
            weight: RoutingConfig.defaultStopWeight,
            kind: RoutePointKind.depot,
          ),
          ...unserved,
          ...deactivated,
        ],
        navigationActive: false,
        navigationProgress: 0.0,
        navigationStopIndex: 1,
        navigationArrived: false,
        isRerouting: false,
        clearNavigationHeading: true,
        clearNavigationSpeed: true,
        clearNavigationStopDistance: true,
      ),
    );

    await optimize();
    if (isClosed) return;
    if (state.status != RoutePlannerStatus.optimizedSuccess ||
        state.optimizedRoute == null) {
      // optimize() already surfaced its error; the user lands in planning
      // with all unserved stops intact and can retry from there.
      return;
    }
    if (wasSim) {
      debugStartDriveSim();
    } else {
      await startNavigation();
    }
  }

  /// Shared completion path for manual + automatic serving. Advances to
  /// the next service point (ending the trip after the final one) and,
  /// when [autoServedLabel] is set, bumps the one-shot auto-serve notice
  /// the HUD listens for.
  void _advanceServicePoint({String? autoServedLabel}) {
    final route = state.optimizedRoute;
    if (route == null || !state.navigationActive) return;
    _enteredServiceRadius = false;
    final next = state.navigationStopIndex + 1;
    if (next >= route.orderedPoints.length) {
      HapticFeedback.heavyImpact();
      stopNavigation();
      return;
    }
    emit(
      state.copyWith(
        navigationStopIndex: next,
        navigationArrived: false,
        clearNavigationStopDistance: true,
        autoServeCount: autoServedLabel != null
            ? state.autoServeCount + 1
            : state.autoServeCount,
        autoServedStopLabel: autoServedLabel,
      ),
    );
  }

  // ── DEBUG: synthetic drive simulator ───────────────────────
  //
  // A desk-testable driver: synthetic fixes are pushed through the exact
  // same pipeline as real GPS (_onNavigationPosition), so the accuracy
  // gate, deviation detection, automatic rerouting, the service-point
  // machine and the marker interpolation all run for real. The driver
  // follows the *current* route polyline at a configurable speed and can
  // be shifted laterally off the road to provoke a reroute.
  // All of it is compiled out of release builds via [kDebugMode].

  Timer? _driveSimTimer;
  LatLng? _driveSimPos;
  double _driveSimSpeedKmh = 40;

  /// GTA mode: non-null = the driver left the road and is going straight
  /// along this bearing (degrees). Null = auto-following the route.
  double? _driveSimHeading;

  /// True once the free driver has clearly left the road, arming the
  /// rejoin — otherwise the car would "rejoin" the road it's still on the
  /// instant after turning.
  bool _driveSimLeftRoad = false;

  static const Duration _driveSimTick = Duration(milliseconds: 500);

  /// Free driver hops back onto the route once it passes this close —
  /// which is exactly what happens when a reroute lands under the car.
  static const double _driveSimRejoinMeters = 20.0;

  bool get debugDriveSimActive => _driveSimTimer != null;
  double get debugDriveSimSpeedKmh => _driveSimSpeedKmh;

  /// True while the driver is off in GTA mode (not following the route).
  bool get debugDriveSimFreeDriving => _driveSimHeading != null;

  /// DEBUG ONLY. Loads a reproducible 3-stop Beirut demo (departure at
  /// Martyrs' Square → Hamra → Sassine → Verdun) and optimizes it, no
  /// matter where the device really is — the playground for the drive
  /// simulator.
  Future<void> debugLoadBeirutDemo() async {
    if (!kDebugMode) return;
    _cancelSimTimer();
    _cancelNavigationStream();
    const depot = LatLng(33.8938, 35.5018); // ساحة الشهداء
    const stops = <(double, double, String)>[
      (33.8965, 35.4780, 'الحمرا'),
      (33.8869, 35.5131, 'ساسين — الأشرفية'),
      (33.8791, 35.4884, 'فردان'),
    ];
    emit(
      state.copyWith(
        status: RoutePlannerStatus.pointsUpdated,
        userLocation: depot,
        cameraTarget: depot,
        points: [
          RoutePoint(
            id: 'depot_current',
            latitude: depot.latitude,
            longitude: depot.longitude,
            label: AppStrings.departure,
            weight: RoutingConfig.defaultStopWeight,
            kind: RoutePointKind.depot,
          ),
          for (var i = 0; i < stops.length; i++)
            RoutePoint(
              id: 'demo_beirut_$i',
              latitude: stops[i].$1,
              longitude: stops[i].$2,
              label: stops[i].$3,
              weight: RoutingConfig.defaultStopWeight,
              kind: RoutePointKind.stop,
            ),
        ],
        clearOptimizedRoute: true,
        clearError: true,
        simulationActive: false,
        simulationPlaying: false,
        simulationProgress: 0.0,
        navigationActive: false,
        navigationProgress: 0.0,
        clearNavigationHeading: true,
        clearNavigationSpeed: true,
        manualPlacement: false,
      ),
    );
    await optimize();
  }

  /// DEBUG ONLY. Starts (or restarts) the synthetic drive along the
  /// current optimized route: real GPS is switched off and the fake
  /// driver takes over from the route start.
  void debugStartDriveSim() {
    if (!kDebugMode) return;
    final route = state.optimizedRoute;
    if (route == null || route.fullPolyline.length < 2) return;

    _cancelSimTimer();
    _cancelNavigationStream(); // also kills any previous sim + real GPS
    final start = route.fullPolyline.first;
    _driveSimPos = start;
    _driveSimHeading = null;
    _driveSimLeftRoad = false;
    _lastNavProgress = 0.0;
    _enteredServiceRadius = false;
    DebugLog.nav(
      'driveSim ▶ start speed=${_driveSimSpeedKmh.toStringAsFixed(0)}km/h '
      '(synthetic fixes every ${_driveSimTick.inMilliseconds}ms)',
    );
    emit(
      state.copyWith(
        userLocation: start,
        cameraTarget: start,
        navigationActive: true,
        navigationProgress: 0.0,
        navigationStopIndex: 1,
        navigationArrived: false,
        clearNavigationHeading: true,
        clearNavigationSpeed: true,
        clearNavigationStopDistance: true,
        stopFractions: state.stopFractions.length == route.orderedPoints.length
            ? state.stopFractions
            : _fractionsFor(route),
        maneuverFractions:
            state.maneuverFractions.length == route.maneuvers.length
            ? state.maneuverFractions
            : _maneuverFractionsFor(route),
        simulationActive: false,
        simulationPlaying: false,
        simulationProgress: 0.0,
        displaySegment: RouteSegment.full,
        clearError: true,
      ),
    );
    _driveSimTimer = Timer.periodic(_driveSimTick, (_) => _onDriveSimTick());
  }

  /// DEBUG ONLY. Cruise speed of the synthetic driver. 0 = standing still
  /// (the sim keeps emitting fixes, like a car waiting at a light).
  void debugSetDriveSimSpeed(double kmh) {
    if (!kDebugMode) return;
    _driveSimSpeedKmh = kmh.clamp(0, 130).toDouble();
  }

  /// DEBUG ONLY. GTA-style steering: rotate the driver by [degrees]
  /// (+90 = right, −90 = left) and drive straight in that direction. The
  /// driver leaves the road, the deviation watcher fires a reroute, and
  /// the moment the recalculated road passes under the car it snaps onto
  /// it and resumes following automatically.
  void debugTurnDriveSim(double degrees) {
    if (!kDebugMode || _driveSimTimer == null) return;
    final route = state.optimizedRoute;
    final pos = _driveSimPos;
    double base;
    final wasFollowing = _driveSimHeading == null;
    if (!wasFollowing) {
      base = _driveSimHeading!;
    } else if (route != null && route.fullPolyline.length >= 2 && pos != null) {
      base = PolylineUtils.lookAheadBearing(
        route.fullPolyline,
        _progressAlongPath(route.fullPolyline, pos),
        15,
      );
    } else {
      base = 0;
    }
    _driveSimHeading = (base + degrees) % 360;
    // Arm-reset only when leaving the road for the first time: while the
    // car is still on it, the rejoin must not fire instantly. Once already
    // free (e.g. a quick U-turn), stay armed so re-crossing a road grabs it.
    if (wasFollowing) _driveSimLeftRoad = false;
    DebugLog.nav(
      'driveSim ⤳ turn ${degrees > 0 ? 'right' : 'left'} → heading '
      '${_driveSimHeading!.toStringAsFixed(0)}°',
    );
  }

  void _onDriveSimTick() {
    if (!state.navigationActive) {
      _cancelDriveSim();
      return;
    }
    final route = state.optimizedRoute;
    final pos0 = _driveSimPos;
    if (route == null || route.fullPolyline.length < 2 || pos0 == null) {
      _cancelDriveSim();
      return;
    }
    final poly = route.fullPolyline;
    final stepMeters =
        _driveSimSpeedKmh / 3.6 * (_driveSimTick.inMilliseconds / 1000.0);

    LatLng pos;
    double heading;
    final free = _driveSimHeading;
    if (free != null) {
      // ── GTA mode: straight along the chosen heading ──
      pos = stepMeters > 0
          ? MapGeometry.destinationPoint(pos0, free, stepMeters)
          : pos0;
      heading = free;
      // Rejoin the road once it passes under the car — armed only after
      // the car has clearly left it, so turning doesn't instantly cancel.
      final t = _progressAlongPath(poly, pos);
      final nearest = PolylineUtils.sampleAt(poly, t)?.point;
      if (nearest != null) {
        final distM = DistanceUtils.haversineKm(nearest, pos) * 1000;
        if (distM > _driveSimRejoinMeters * 2) _driveSimLeftRoad = true;
        if (_driveSimLeftRoad && distM <= _driveSimRejoinMeters) {
          pos = nearest;
          heading = PolylineUtils.lookAheadBearing(poly, t, 15);
          _driveSimHeading = null;
          _driveSimLeftRoad = false;
          DebugLog.nav('driveSim ⇤ rejoined the road — following again');
        }
      }
    } else {
      // ── Auto-follow the current route ──
      // Re-project onto the *current* polyline every tick, so the driver
      // hops onto fresh geometry the instant a reroute lands.
      final totalKm = DistanceUtils.pathLengthKm(poly);
      if (totalKm <= 0) return;
      final t0 = _progressAlongPath(poly, pos0);
      final t = (t0 + stepMeters / 1000.0 / totalKm).clamp(0.0, 1.0);
      pos = PolylineUtils.interpolateByLength(poly, t) ?? pos0;
      heading = PolylineUtils.lookAheadBearing(poly, t, 15);
    }
    _driveSimPos = pos;

    _onNavigationPosition(
      Position(
        latitude: pos.latitude,
        longitude: pos.longitude,
        timestamp: DateTime.now(),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 5,
        heading: heading,
        headingAccuracy: 5,
        speed: _driveSimSpeedKmh / 3.6,
        speedAccuracy: 1,
      ),
    );
  }

  void _cancelDriveSim() {
    _driveSimTimer?.cancel();
    _driveSimTimer = null;
    _driveSimPos = null;
    _driveSimHeading = null;
    _driveSimLeftRoad = false;
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

    // Mirror the live service-point fields so the debug drive exercises
    // the same HUD (Point Served button, distances) as a real trip.
    double? distToStop;
    var arrived = false;
    if (stopIndex < route.orderedPoints.length) {
      distToStop =
          DistanceUtils.haversineKm(
            loc,
            route.orderedPoints[stopIndex].latLng,
          ) *
          1000;
      arrived =
          distToStop <=
          NavigationConfig.serviceRadiusMeters +
              NavigationConfig.serviceRadiusAccuracySlack;
    }

    emit(
      state.copyWith(
        userLocation: loc,
        cameraTarget: loc,
        navigationProgress: newProgress,
        navigationStopIndex: stopIndex,
        navigationArrived: arrived,
        navigationStopDistanceMeters: distToStop,
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

    // Accuracy gate: a fix that could be tens of metres off can teleport
    // the car and mis-trigger the 10 m service radius — drop it and wait
    // for the next one.
    if (position.accuracy.isFinite &&
        position.accuracy > NavigationConfig.maxAccuracyMeters) {
      DebugLog.nav(
        'GPS tick REJECTED — accuracy ${position.accuracy.toStringAsFixed(0)}m '
        '> ${NavigationConfig.maxAccuracyMeters}m',
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
    if (speed != null) {
      _smoothedSpeed = _smoothedSpeed == null
          ? speed
          : _smoothedSpeed! +
                (speed - _smoothedSpeed!) *
                    NavigationConfig.speedSmoothingFactor;
    }

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

    // Only let GPS drive progress when the fix is genuinely on the route.
    // Off-route fixes would otherwise snap progress to the nearest polyline
    // point (often near the end); when off-route we freeze it and keep
    // whatever the last good value was.
    final projection = _routeProjection(route.fullPolyline, loc);
    final onRouteProg =
        (projection != null &&
            projection.offRouteMeters <=
                NavigationConfig.onRouteThresholdMeters)
        ? projection.progress
        : null;
    var progress = state.navigationProgress;
    if (onRouteProg != null) {
      // Monotonic progress: GPS noise can briefly regress the fraction;
      // never go backwards — you can't un-drive a road.
      progress = onRouteProg < _lastNavProgress ? _lastNavProgress : onRouteProg;
      _lastNavProgress = progress;
    } else {
      DebugLog.nav(
        'off route — progress frozen at '
        '${progress.toStringAsFixed(4)} [off-route fix]',
      );
    }

    // ── Service-point state machine ──
    // Upcoming → Arrived (inside the service radius; Point Served button
    // shows) → Served, either manually (button) or automatically once the
    // driver leaves the area and is >autoServeExitMeters away.
    final stopIndex = state.navigationStopIndex;
    var arrived = state.navigationArrived;
    double? distToStop;
    if (stopIndex < route.orderedPoints.length) {
      final targetStop = route.orderedPoints[stopIndex];
      distToStop = DistanceUtils.haversineKm(loc, targetStop.latLng) * 1000;

      // The nominal radius grows with the fix's reported accuracy (capped)
      // so a phone that never reports better than ~20 m can still arrive.
      final slack = position.accuracy.isFinite && position.accuracy > 0
          ? math.min(
              position.accuracy,
              NavigationConfig.serviceRadiusAccuracySlack,
            )
          : 0.0;
      final radius = NavigationConfig.serviceRadiusMeters + slack;

      if (distToStop <= radius) {
        if (!_enteredServiceRadius) {
          DebugLog.nav(
            'ARRIVED at stop $stopIndex (${distToStop.toStringAsFixed(1)}m '
            '≤ ${radius.toStringAsFixed(1)}m) — Point Served button shown',
          );
          HapticFeedback.lightImpact();
        }
        _enteredServiceRadius = true;
        arrived = true;
      } else {
        arrived = false;
        final passedStop =
            onRouteProg != null &&
            stopIndex < state.stopFractions.length &&
            progress >= state.stopFractions[stopIndex];
        if ((_enteredServiceRadius || passedStop) &&
            distToStop > NavigationConfig.autoServeExitMeters) {
          // Entered-then-left (or drove straight past on-route): the point
          // has been served — complete it without any dialog and continue
          // to the next one.
          DebugLog.nav(
            'AUTO-SERVED stop $stopIndex '
            '(${_enteredServiceRadius ? 'entered-then-left' : 'passed on route'}, '
            'now ${distToStop.toStringAsFixed(0)}m away)',
          );
          HapticFeedback.mediumImpact();
          emit(
            state.copyWith(
              userLocation: loc,
              cameraTarget: loc,
              navigationProgress: progress,
              navigationHeading: _smoothedHeading,
              navigationSpeedMps: _smoothedSpeed,
            ),
          );
          _advanceServicePoint(autoServedLabel: targetStop.label);
          return;
        }
      }
    }

    // Deviation watch: enough sustained, clearly-off-route movement kicks
    // off a background recalculation toward the current service point.
    _watchForDeviation(
      offRouteMeters: projection?.offRouteMeters,
      loc: loc,
      accuracy: position.accuracy,
      arrived: arrived,
    );

    DebugLog.nav(
      '→ emit progress=${progress.toStringAsFixed(4)} '
      'smoothedHeading=${_smoothedHeading?.toStringAsFixed(1)} '
      'speed=${_smoothedSpeed?.toStringAsFixed(2)} stopIndex=$stopIndex '
      'distToStop=${distToStop?.toStringAsFixed(1)}m arrived=$arrived',
    );

    emit(
      state.copyWith(
        userLocation: loc,
        cameraTarget: loc,
        navigationProgress: progress,
        navigationStopIndex: stopIndex,
        navigationArrived: arrived,
        navigationStopDistanceMeters: distToStop,
        // Null keeps the previous heading (copyWith semantics), so the
        // camera never snaps back to north on a dropped bearing.
        navigationHeading: _smoothedHeading,
        navigationSpeedMps: _smoothedSpeed,
      ),
    );
  }

  // ── Automatic rerouting ────────────────────────────────────
  //
  // A single stray fix is GPS noise; several clearly-off-route fixes in a
  // row, spaced by real movement, is a driver who left the planned road.
  // When that happens we fetch fresh geometry from the current position
  // through every remaining stop (the active service point first) and
  // splice it onto the already-driven part of the old route, so the trail,
  // progress and all navigation state carry over seamlessly.

  /// Counts deviating fixes and fires [_reroute] once the pattern is
  /// unmistakably a real deviation rather than drift or a lane change.
  void _watchForDeviation({
    required double? offRouteMeters,
    required LatLng loc,
    required double accuracy,
    required bool arrived,
  }) {
    if (offRouteMeters == null) return;

    // The threshold widens on poor fixes: 40 m off-route means nothing
    // when the fix itself is only good to ±30 m.
    final threshold = math.max(
      NavigationConfig.rerouteDeviationMeters,
      accuracy.isFinite && accuracy > 0
          ? accuracy * NavigationConfig.rerouteAccuracyFactor
          : 0.0,
    );
    if (offRouteMeters <= threshold) {
      _offRouteFixCount = 0;
      _lastOffRouteCounted = null;
      return;
    }

    // Fixes now stream continuously (~1 Hz) even when parked — require
    // real movement between counted fixes so a car idling off-route
    // (or serving a stop) can't tick the counter up.
    final last = _lastOffRouteCounted;
    if (last != null &&
        DistanceUtils.haversineKm(last, loc) * 1000 <
            NavigationConfig.rerouteFixSpacingMeters) {
      return;
    }
    _lastOffRouteCounted = loc;
    _offRouteFixCount++;
    DebugLog.nav(
      'deviation fix #$_offRouteFixCount — '
      '${offRouteMeters.toStringAsFixed(0)}m from route '
      '(threshold ${threshold.toStringAsFixed(0)}m)',
    );

    if (_offRouteFixCount < NavigationConfig.rerouteMinConsecutiveFixes) {
      return;
    }
    if (_rerouting) return;
    final backoff = _rerouteBackoffUntil;
    if (backoff != null && DateTime.now().isBefore(backoff)) return;
    // At the stop itself, being off the road is the point (driveways,
    // parking) — never reroute around the service radius.
    if (arrived || _enteredServiceRadius) return;

    unawaited(_reroute(loc));
  }

  /// Recalculates the route from [from] through every remaining stop and
  /// swaps it in without touching the rest of the navigation state.
  Future<void> _reroute(LatLng from) async {
    final route = state.optimizedRoute;
    if (route == null || !state.navigationActive || _rerouting) return;
    final stopIdx = state.navigationStopIndex.clamp(
      0,
      route.orderedPoints.length - 1,
    );
    final remaining = route.orderedPoints.sublist(stopIdx);
    if (remaining.isEmpty) return;

    _rerouting = true;
    emit(state.copyWith(isRerouting: true));
    DebugLog.nav(
      'REROUTE start from=${from.latitude.toStringAsFixed(6)},'
      '${from.longitude.toStringAsFixed(6)} '
      'remainingStops=${remaining.length}',
    );

    try {
      final fresh = await _routing.fetchRoute(
        origin: from,
        destination: remaining.last.latLng,
        waypoints: [
          for (final p in remaining.take(remaining.length - 1)) p.latLng,
        ],
        includeSteps: true,
      );

      // The world may have moved on during the fetch: trip ended, a stop
      // was served and re-triggered, or the route was replaced outright.
      if (isClosed ||
          !state.navigationActive ||
          !identical(state.optimizedRoute, route)) {
        return;
      }
      if (fresh.isEmpty || fresh.polyline.length < 2) {
        DebugLog.nav('REROUTE ✋ router returned no geometry — backing off');
        _rerouteBackoffUntil = DateTime.now().add(
          NavigationConfig.rerouteCooldown,
        );
        emit(state.copyWith(isRerouting: false));
        return;
      }

      // Keep the driven geometry so the trail and the fractions of served
      // stops stay truthful, and append the fresh road. The short seam
      // between the frozen on-route point and the router's snapped origin
      // is the driver's actual departure from the plan.
      final driven = MapGeometry.subPath(
        route.fullPolyline,
        0.0,
        _lastNavProgress,
      );
      final newFull = <LatLng>[...driven, ...fresh.polyline];
      final drivenKm = DistanceUtils.pathLengthKm(driven);
      final totalKm = DistanceUtils.pathLengthKm(newFull);
      if (totalKm <= 0) {
        _rerouteBackoffUntil = DateTime.now().add(
          NavigationConfig.rerouteCooldown,
        );
        emit(state.copyWith(isRerouting: false));
        return;
      }
      final newProgress = (drivenKm / totalKm).clamp(0.0, 1.0);

      // Maneuver fractions are measured on the fresh segment alone and
      // offset by the driven arc length. Matching against the merged
      // polyline instead could snap a maneuver into the driven prefix when
      // the new route re-traverses old roads (a U-turn reroute — the most
      // common kind), silently hiding its instruction.
      final newKm = DistanceUtils.pathLengthKm(fresh.polyline);
      final maneuverFractions = newKm > 0
          ? [
              for (final f in PolylineUtils.orderedFractionsAlong(
                fresh.polyline,
                [for (final m in fresh.maneuvers) m.latLng],
              ))
                ((drivenKm + f * newKm) / totalKm).clamp(0.0, 1.0),
            ]
          : const <double>[];

      // The router just measured the *remaining* duration; express it as a
      // whole-trip estimate so the HUD's `est × (1 − progress)` readouts
      // keep meaning "what's left".
      final remainFrac = (1 - newProgress).clamp(0.01, 1.0);
      final metrics = route.metrics.copyWith(
        totalDistanceKm: totalKm,
        estimatedDurationMinutes: fresh.durationSeconds / 60.0 / remainFrac,
      );

      final newRoute = OptimizedRoute(
        orderedPoints: route.orderedPoints,
        fullPolyline: newFull,
        goPolyline: route.goPolyline,
        returnPolyline: route.returnPolyline,
        metrics: metrics,
        hasRoadGeometry: true,
        maneuvers: fresh.maneuvers,
      );

      _lastNavProgress = newProgress;
      _offRouteFixCount = 0;
      _lastOffRouteCounted = null;
      _rerouteBackoffUntil = DateTime.now().add(
        NavigationConfig.rerouteCooldown,
      );
      DebugLog.nav(
        'REROUTE ✅ newTotal=${totalKm.toStringAsFixed(2)}km '
        'progress=${newProgress.toStringAsFixed(4)} '
        'maneuvers=${fresh.maneuvers.length}',
      );
      emit(
        state.copyWith(
          optimizedRoute: newRoute,
          stopFractions: _fractionsFor(newRoute),
          maneuverFractions: maneuverFractions,
          navigationProgress: newProgress,
          isRerouting: false,
        ),
      );
    } catch (e) {
      DebugLog.nav('REROUTE ✋ error: $e');
      _rerouteBackoffUntil = DateTime.now().add(
        NavigationConfig.rerouteCooldown,
      );
      if (!isClosed) emit(state.copyWith(isRerouting: false));
    } finally {
      _rerouting = false;
    }
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
        isRerouting: false,
        clearNavigationHeading: true,
        clearNavigationSpeed: true,
      ),
    );
  }

  void _cancelNavigationStream() {
    _cancelDriveSim();
    _navSub?.cancel();
    _navSub = null;
    _smoothedHeading = null;
    _smoothedSpeed = null;
    _lastNavProgress = 0.0;
    _enteredServiceRadius = false;
    _offRouteFixCount = 0;
    _lastOffRouteCounted = null;
    _rerouteBackoffUntil = null;
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
      maneuvers: route.maneuvers,
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
        maneuverFractions: _maneuverFractionsFor(route),
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

  /// Projects [point] onto [path]: the arc-length progress (0..1) of the
  /// nearest on-route point plus how far off the route the fix sits.
  /// Progress drives the trail only while the fix is on-route (see
  /// [_onRouteProgress]); the off-route distance feeds deviation detection.
  ({double progress, double offRouteMeters})? _routeProjection(
    List<LatLng> path,
    LatLng point,
  ) {
    if (path.length < 2) return null;
    final projected = _progressAlongPath(path, point);
    final nearest = PolylineUtils.sampleAt(path, projected)?.point;
    if (nearest == null) return null;
    final offRouteMeters = DistanceUtils.haversineKm(nearest, point) * 1000;
    return (progress: projected, offRouteMeters: offRouteMeters);
  }

  /// Projected progress (0..1) of [point] along [path] — but only when the
  /// fix is genuinely on the route (within
  /// [NavigationConfig.onRouteThresholdMeters]). Returns null when the fix
  /// is too far off the route to trust (Simulator, or the driver hasn't
  /// reached the start), so callers leave progress where it is instead of
  /// snapping to the nearest polyline point.
  double? _onRouteProgress(List<LatLng> path, LatLng point) {
    final projection = _routeProjection(path, point);
    if (projection == null) return null;
    if (projection.offRouteMeters > NavigationConfig.onRouteThresholdMeters) {
      return null;
    }
    return projection.progress;
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

  /// The implicit departure: a depot pinned to the user's current location.
  /// Injected ahead of the first destination so every route starts from where
  /// the user is, without them placing a departure pin.
  RoutePoint _currentLocationDepot() {
    final loc = state.userLocation!;
    return RoutePoint(
      id: 'depot_current',
      latitude: loc.latitude,
      longitude: loc.longitude,
      label: AppStrings.departure,
      weight: RoutingConfig.defaultStopWeight,
      kind: RoutePointKind.depot,
    );
  }

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

  /// Arc-length fraction of each turn maneuver along the route — the basis
  /// of "turn right in 350 m". Maneuvers are already route-ordered, so a
  /// single monotonic sweep suffices. Computed once per route.
  List<double> _maneuverFractionsFor(OptimizedRoute route) {
    if (route.fullPolyline.length < 2 || route.maneuvers.isEmpty) {
      return const [];
    }
    return PolylineUtils.orderedFractionsAlong(
      route.fullPolyline,
      route.maneuvers.map((m) => m.latLng).toList(),
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
