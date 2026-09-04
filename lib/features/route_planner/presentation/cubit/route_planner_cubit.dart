import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/services/auto_map_cache.dart';
import '../../../../core/services/location_gate.dart';
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
import '../../data/repositories/place_search_repository.dart';
import '../../data/models/planner_draft_model.dart';
import '../utils/route_csv_utils.dart';
import '../../domain/entities/optimized_route.dart';
import '../../domain/entities/place_suggestion.dart';
import '../../data/models/laffa_file.dart';
import '../../domain/entities/route_finish.dart';
import '../../domain/entities/route_point.dart';
import '../../domain/entities/stop_time_window.dart';
import '../../domain/usecases/optimize_route_usecase.dart';
import '../widgets/map_geometry.dart';
import 'route_planner_state.dart';

class RoutePlannerCubit extends Cubit<RoutePlannerState> {
  final OptimizeRouteUseCase _optimize;
  final SavedRoutesRepository _savedRoutes;
  final OsmGeocodingDataSource _geocoding;
  final PlaceSearchRepository _places;
  final PlannerDraftLocalDataSource _draft;
  final NetworkInfo _network;
  final OsrmRoutingDataSource _routing;

  /// Drives the simulation marker forward; cancelled on stop / reset / close.
  Timer? _simTimer;
  StreamSubscription<Position>? _navSub;

  /// Keeps the blue dot on the driver while they are *not* driving a route.
  ///
  /// Without it the dot is wherever the last explicit fix put it, which on
  /// a map that has to work with no signal is the difference between "here
  /// I am" and a marker of where the app last had a reason to look. Stands
  /// down while [_navSub] is live — drive mode's stream supersedes it.
  StreamSubscription<Position>? _liveSub;

  /// Whether the dot *should* be following, independent of whether it is
  /// subscribed right now. Distinguishes a stream parked on purpose (app
  /// backgrounded, drive mode running) from one that never had permission
  /// to run, so returning to the app resumes only the former.
  bool _liveWanted = false;

  /// Smoothed compass heading so the drive camera glides on noisy bearings.
  double? _smoothedHeading;

  /// Smoothed GPS speed (m/s) — drives the adaptive zoom without the
  /// camera "breathing" on every noisy speed sample.
  double? _smoothedSpeed;

  /// Last emitted navigation progress — used to prevent GPS noise from
  /// regressing the trail (you can't un-drive a segment).
  double _lastNavProgress = 0.0;

  /// Service-point state machine: true once the driver has reached the
  /// *current* target stop — entered its service radius, or driven past it
  /// on the planned route. Armed, it keeps the serve button on screen
  /// until the driver presses it; only serving clears it.
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
    this._places,
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

    // 2) Probe connectivity and location access in the background
    //    (non-blocking — neither gates the map appearing).
    unawaited(_refreshConnectivity());
    unawaited(refreshLocationAccess());

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
      // Permission is granted and a fix landed, so the dot can start
      // following the driver instead of freezing here.
      _startLiveLocation();
      _keepOfflineMapAround(loc);
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
      // Covers the driver who denied location at launch and granted it
      // later from the error banner: the first successful fix is also when
      // the dot earns the right to start following.
      _startLiveLocation();
      return true;
    } on LocationException catch (e) {
      developer.log('recenterOnUser: location unavailable: ${e.message}');
      // When we already panned to a cached fix, a failed refine stays silent.
      if (surfaceError) {
        emit(state.copyWith(errorMessage: _mapLocationError(e)));
      }
      return false;
    } catch (e) {
      developer.log('recenterOnUser() failed', error: e);
      if (surfaceError) {
        emit(state.copyWith(errorMessage: AppStrings.errLocationUnavailable));
      }
      return false;
    }
  }

  // ── Live location (planning mode) ─────────────────────────
  //
  // Drive mode runs its own navigation-grade stream. This is the quiet one
  // that keeps the dot honest the rest of the time — idle map, planning, a
  // driver walking back to the van — which is what makes the app usable as
  // a plain "where am I" map with no trip and no signal.

  /// Subscribes the planning-mode position stream.
  ///
  /// Idempotent, and refuses to start while drive mode or the simulation
  /// owns the dot, so it can be called from anywhere a fix or a mode change
  /// suggests the dot should be following again.
  ///
  /// [asOf] is the state to judge by. It matters when called from
  /// [onChange], which runs *before* the new state is installed — reading
  /// the getter there would still see the drive that just ended and refuse
  /// to bring the dot back.
  void _startLiveLocation({RoutePlannerState? asOf}) {
    final s = asOf ?? state;
    _liveWanted = true;
    if (_liveSub != null) return;
    if (s.navigationActive || s.simulationActive) return;

    _liveSub = Geolocator.getPositionStream(
      locationSettings: _liveLocationSettings(),
    ).listen(_onLivePosition, onError: _onLiveError);
    DebugLog.loc(
      'liveLocation ▶ subscribed (distanceFilter='
      '${MapConfig.liveLocationDistanceFilterMeters}m)',
    );
  }

  void _stopLiveLocation() {
    if (_liveSub == null) return;
    _liveSub!.cancel();
    _liveSub = null;
    DebugLog.loc('liveLocation ⏹ cancelled');
  }

  /// Moves the dot, and deliberately nothing else.
  ///
  /// `cameraTarget` is left alone: a map that pans itself while the driver
  /// is reading it is worse than one that sits still. Recentring stays the
  /// "my location" button's job — same division of labour as every map app.
  void _onLivePosition(Position position) {
    if (isClosed) return;
    // Drive mode may have taken the wheel between two fixes.
    if (state.navigationActive || state.simulationActive) {
      _stopLiveLocation();
      return;
    }
    final loc = LatLng(position.latitude, position.longitude);
    emit(state.copyWith(userLocation: loc));
    _keepOfflineMapAround(loc);
  }

  /// Keeps a square of map stored around the driver, without saying so.
  ///
  /// Fire-and-forget by design: nothing in the planner waits on it, and a
  /// failure to store map has no bearing on anything the driver is doing
  /// right now. [AutoMapCache] carries its own gates, so this can sit on a
  /// position stream without turning every fix into work.
  void _keepOfflineMapAround(LatLng where) =>
      unawaited(AutoMapCache.ensureAround(where));

  /// A background stream that dies is not worth a banner: the dot simply
  /// stops moving, exactly as it behaved before this stream existed. The
  /// explicit "my location" action still reports failures properly, which
  /// is where the user is actually asking a question of the GPS.
  void _onLiveError(Object error) {
    DebugLog.loc('liveLocation ⚠️ stream error: $error');
    developer.log('live location stream error', error: error);
    // Whatever broke the stream (permission revoked mid-session, services
    // switched off) will break it again on the next resume, so stay down
    // until something with a real answer — the my-location button, or the
    // end of a drive — asks for it again.
    _liveWanted = false;
    _stopLiveLocation();
  }

  /// Suspends the dot while the app is off-screen and brings it back on
  /// return.
  ///
  /// Drive mode is deliberately excluded: a driver who switches apps
  /// mid-trip still expects to be navigated. The planning dot has nothing
  /// to update while no map is on screen, so it stands down instead.
  void setAppForeground(bool foreground) {
    if (state.navigationActive || state.simulationActive) return;
    if (foreground) {
      if (_liveWanted) _startLiveLocation();
    } else {
      _stopLiveLocation();
    }
  }

  /// Battery-conscious counterpart to [_navLocationSettings]: a real
  /// distance filter and no navigation activity type, because a dot on a
  /// map being *read* needs to be right to within metres, not centimetres,
  /// and this stream may run for as long as the app is open.
  LocationSettings _liveLocationSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: MapConfig.liveLocationDistanceFilterMeters,
        intervalDuration: MapConfig.liveLocationInterval,
      );
    }
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.otherNavigation,
        distanceFilter: MapConfig.liveLocationDistanceFilterMeters,
        // Both flags stay off deliberately. iOS's automatic pausing is not
        // reliably self-reversing — a paused stream can leave the dot
        // frozen exactly when the driver looks at it — and this stream
        // exists for a map on screen, so it has no business running once
        // the app is in the background.
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: false,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: MapConfig.liveLocationDistanceFilterMeters,
    );
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

    // The planning-mode dot follows the driver whenever drive mode and the
    // simulation are both idle. Reconciling it here rather than at each
    // call site is what keeps it correct: a dozen paths enter and leave
    // those modes (stop, clear, load a saved route, reroute, error), and
    // every one of them ends in exactly this transition.
    if (a.navigationActive != b.navigationActive ||
        a.simulationActive != b.simulationActive) {
      if (b.navigationActive || b.simulationActive) {
        _stopLiveLocation();
      } else {
        _startLiveLocation(asOf: b);
      }
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
    // Whether or not it worked — and it returns false having merely *opened*
    // the settings — the chip needs to reflect where things now stand.
    await refreshLocationAccess();
  }

  /// Re-reads location access for the map's "enable location" chip. Status
  /// only: no prompt and no fix, so it is cheap enough to run on every
  /// resume, which is how a permission granted out in the system settings
  /// makes the chip disappear on its own.
  Future<void> refreshLocationAccess() async {
    try {
      final access = await LocationGate.status();
      if (isClosed || access == state.locationAccess) return;
      emit(state.copyWith(locationAccess: access));
    } catch (e) {
      developer.log('refreshLocationAccess() failed', error: e);
    }
  }

  // ── Point management ──────────────────────────────────────

  /// Where a search should consider "here" to be.
  ///
  /// The GPS fix when there is one, and otherwise whatever the map is
  /// looking at — a dispatcher who panned to another city is asking about
  /// that city, and a planner with location off is still asking about
  /// somewhere. Only a search with no anchor at all falls back to the
  /// unbiased behaviour that put an Istanbul pharmacy at the top of a
  /// Damascus driver's list.
  LatLng? get searchAnchor => state.userLocation ?? state.cameraTarget;

  /// Search for a place, biased to [searchAnchor].
  ///
  /// A stream, not a future: the fast provider answers in a few hundred
  /// milliseconds and the list appears, then the slower sources fold in.
  /// The alternative — waiting for every source before showing anything —
  /// is how a search box comes to feel broken on a phone in a truck.
  Stream<List<PlaceSuggestion>> searchPlaces(String query) => _places.search(
    query,
    near: searchAnchor,
    routePoints: _routePointSuggestions(),
  );

  /// Places picked before, newest first — what the sheet shows before the
  /// driver has typed anything.
  List<PlaceSuggestion> recentPlaces() =>
      _places.recentPlaces(near: searchAnchor);

  /// Records a pick so it leads the list next time. Called on selection,
  /// never on mere display.
  Future<void> rememberPlace(PlaceSuggestion place) => _places.remember(place);

  /// The stops already on this route, offered to the search as candidates.
  /// "Back to the depot" is a real destination, and finding it should not
  /// require asking a server about a place the app already knows.
  List<PlaceSuggestion> _routePointSuggestions() {
    return state.points
        .where(
          (p) =>
              p.label.trim().isNotEmpty || (p.address ?? '').trim().isNotEmpty,
        )
        .map((p) {
          final label = p.label.trim();
          final address = p.address?.trim();
          return PlaceSuggestion(
            id: 'route:${p.id}',
            name: label.isNotEmpty ? label : address!,
            context: (address != null && address != label) ? address : null,
            latLng: p.latLng,
            kind: PlaceKind.poi,
            source: PlaceSource.routePoint,
          );
        })
        .toList();
  }

  /// Adds a point at [position]. When [address] is supplied (e.g. the label
  /// the user picked from address search) it is shown immediately and the
  /// background reverse-geocode is skipped — otherwise the address is resolved
  /// from the coordinate.
  /// Adds a point at [position]. Returns the point that landed, or null when
  /// one of the guards below swallowed the add (a debounced double-tap, or a
  /// pin dropped on top of an existing one) — callers use that to decide
  /// whether to recentre the map and confirm to the driver.
  ///
  /// [label] and [phone] come from an import that already knows them (a CSV
  /// row); left null, the label is generated and the stop has no contact.
  Future<RoutePoint?> addPoint(
    LatLng position, {
    bool optional = false,
    String? address,
    String? label,
    String? phone,
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
        return null;
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
        return null;
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

    // An imported name wins over the generated one — a CSV that says
    // "مخبز الشام" should not come back as "نقطة 3".
    final importedLabel = label?.trim();
    // Counting starts at two: while this is the only place the driver is
    // going, it is "the destination", not "stop 1". It picks up a number if
    // and when a second one arrives (see [_renumberIfNoLongerSole]).
    final soleDestination =
        !firstAsDepot && !asOptional && _mandatoryStopCount() == 0;
    final resolvedLabel = (importedLabel != null && importedLabel.isNotEmpty)
        ? importedLabel
        : firstAsDepot
        ? AppStrings.departure
        : asOptional
        ? AppStrings.optionalStopLabel(_optionalCount() + 1)
        : soleDestination
        ? AppStrings.destinationTitle
        : AppStrings.stopLabel(_mandatoryStopCount() + 1);

    final providedAddress = address?.trim();
    final tentative = RoutePoint(
      id: id,
      latitude: position.latitude,
      longitude: position.longitude,
      label: resolvedLabel,
      address: (providedAddress != null && providedAddress.isNotEmpty)
          ? providedAddress
          : null,
      phone: (phone?.trim().isNotEmpty ?? false) ? phone!.trim() : null,
      weight: RoutingConfig.defaultStopWeight,
      kind: firstAsDepot ? RoutePointKind.depot : RoutePointKind.stop,
      optional: asOptional,
    );

    DebugLog.add(
      'addPoint() ✅ ACCEPTED "$resolvedLabel" '
      '(${firstAsDepot
          ? 'depot'
          : asOptional
          ? 'optional'
          : 'stop'}) id=$id '
      '→ total=${state.points.length + 1}',
    );

    final newPoints = _renumberIfNoLongerSole(<RoutePoint>[
      if (isFirst && hasLoc) _currentLocationDepot(),
      ...state.points,
      tentative,
    ]);

    emit(
      state.copyWith(
        status: RoutePlannerStatus.pointsUpdated,
        points: newPoints,
        // Put the map on the stop that just landed. With the optimized route
        // cleared above, RouteMapView's camera sync follows `cameraTarget`,
        // so the driver sees where the point actually went instead of having
        // to hunt for it — this is the whole "centre on the new point" rule.
        cameraTarget: position,
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
      // The route replaces `points` wholesale, so it has to come *after* the
      // reverse lookup lands — racing it would drop the address the driver is
      // about to read on the card.
      _resolveAddress(tentative)
          .then((withAddr) {
            if (withAddr == null) return;
            final idx = state.points.indexWhere((p) => p.id == withAddr.id);
            if (idx < 0) return;
            final updated = [...state.points]..[idx] = withAddr;
            emit(state.copyWith(points: updated));
          })
          .catchError((_) {})
          .whenComplete(_routeLoneDestination);
    } else {
      _routeLoneDestination();
    }

    return tentative;
  }

  /// A single destination is a navigation request, not a plan: there is
  /// nothing to order and nothing to decide, so route it immediately and let
  /// the card show a real time and distance without the driver pressing
  /// anything. The repository skips the solver for one stop and asks the
  /// router directly, so this costs one cheap call.
  ///
  /// The cost of being wrong is that same one call, wasted, when the driver
  /// goes on to add a second destination — worth it for a first screen that
  /// behaves like the navigator they expected.
  void _routeLoneDestination() {
    if (isClosed) return;
    if (!state.isSingleDestination) return;
    if (state.hasOptimizedRoute || state.quietRouting) return;
    unawaited(optimize(quiet: true));
  }

  /// The navigator shape's one action: make sure a route exists, then drive.
  ///
  /// Usually the route is already there (it was fetched the moment the
  /// destination landed) and this is a straight hand-off to drive mode. When
  /// the quiet attempt failed — no signal at the time — this is the loud
  /// retry, and a second failure surfaces properly, because now the driver
  /// did ask.
  Future<void> driveToDestination() async {
    if (!state.hasOptimizedRoute) {
      await optimize();
      if (isClosed || !state.hasOptimizedRoute) return;
    }
    await startNavigation();
  }

  /// Drops the lone destination and returns to the empty "where to?" screen.
  /// The implicit departure goes with it — it only exists to anchor a
  /// destination, and leaving it behind would strand the empty state with a
  /// pin on the map.
  void clearDestination() {
    if (!state.hasPoints) return;
    clearAll();
  }

  // ── Departure ─────────────────────────────────────────────
  //
  // The trip starts where the driver is, until they say otherwise. That
  // default is right almost every time and worth nobody's tap — but "almost"
  // is not "always": a dispatcher planning tomorrow's round, a driver whose
  // shift starts at the depot rather than at home, someone sitting in a café
  // working out a route from the warehouse. So the assumption is visible on
  // the card, and it is one tap to replace.

  /// Starts the trip from [position] instead of the driver's live location.
  ///
  /// The chosen departure carries [kCustomDepotId], so optimizing no longer
  /// drags it to the latest GPS fix the way it does the automatic one.
  Future<void> setDeparture(LatLng position, {String? address}) async {
    final chosen = RoutePoint(
      id: kCustomDepotId,
      latitude: position.latitude,
      longitude: position.longitude,
      label: AppStrings.departure,
      address: (address?.trim().isNotEmpty ?? false) ? address!.trim() : null,
      weight: RoutingConfig.defaultStopWeight,
      kind: RoutePointKind.depot,
    );
    _applyDeparture(chosen, recentreOn: position);

    // Same order as adding a stop: the reverse lookup first, then the route,
    // because routing replaces `points` and would drop the address.
    if (chosen.address == null) {
      try {
        final withAddr = await _resolveAddress(chosen);
        if (!isClosed && withAddr != null) {
          final list = [
            for (final p in state.points)
              if (p.id == withAddr.id) withAddr else p,
          ];
          emit(state.copyWith(points: list));
        }
      } catch (_) {
        // An address is a nicety; the coordinates are what routes.
      }
    }
    _routeLoneDestination();
  }

  /// Hands the departure back to the driver's live location — the default.
  ///
  /// Uses the last known fix rather than asking the GPS for a fresh one:
  /// [optimize] re-pins the automatic departure to the latest fix on every
  /// run anyway, so waiting here would buy nothing but a delay.
  void useCurrentLocationAsDeparture() {
    final loc = state.userLocation;
    if (loc == null) {
      emit(state.copyWith(errorMessage: AppStrings.errLocationUnavailable));
      return;
    }
    if (state.departureIsCurrentLocation) return;
    _applyDeparture(_currentLocationDepot(), recentreOn: loc);
    _routeLoneDestination();
  }

  /// Swaps the depot in [points] for [departure] and invalidates the route
  /// the old one produced.
  ///
  /// Only a depot *this app* invented is thrown away: the automatic
  /// current-location one, or a departure the driver set earlier. With no
  /// location fix, [_ensureSingleDepot] promotes the driver's own first pin
  /// to depot instead — a real place they asked to be taken to. Setting a
  /// departure used to delete it along with the depot role; it is now demoted
  /// back to a stop and keeps its place in the trip.
  void _applyDeparture(RoutePoint departure, {required LatLng recentreOn}) {
    final rest = _relabelGenerated([
      for (final p in state.points)
        if (!p.isDepot)
          p
        else if (p.id != kCurrentLocationDepotId && p.id != kCustomDepotId)
          _demoteToStop(p),
    ]);
    _cancelSimTimer();
    _cancelNavigationStream();
    emit(
      state.copyWith(
        status: RoutePlannerStatus.pointsUpdated,
        points: [departure, ...rest],
        cameraTarget: recentreOn,
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
        placementTarget: PlacementTarget.stop,
      ),
    );
    _schedulePersist();
  }

  // ── Trip shape ────────────────────────────────────────────

  /// Declares up front that this is a multi-stop trip, so the planner is on
  /// screen from the first point rather than after the second.
  ///
  /// The single-destination shape exists so a newcomer is not handed a
  /// planner they did not ask for. A driver who came to build a round
  /// already knows; making them add a stop, watch the navigator card, and
  /// only then find "add another stop" is teaching someone what they came in
  /// knowing.
  void beginMultiStopTrip() {
    if (state.multiStopIntent) return;
    emit(state.copyWith(multiStopIntent: true));
  }

  /// Takes the declaration back — the driver said "several stops", then
  /// changed their mind before adding a second one.
  ///
  /// Only reaches the shape while the trip is still short enough for it to
  /// matter: with two destinations already on the map the planner is on
  /// screen because the trip *is* multi-stop, not because of this flag.
  /// True while the next place to arrive from *outside* the app — a pasted
  /// Google Maps link, a location shared from WhatsApp — should become the
  /// trip's departure instead of another stop.
  ///
  /// One-shot, and deliberately in memory only: it is armed when the driver
  /// picks one of those ways from the "start from" sheet, and spent by the
  /// very next import. If the app was killed while they were away in the
  /// other app, the flag goes with it and the place lands as a stop — which
  /// they can still hand to the departure in one tap. Guessing after a
  /// restart would be worse than that.
  bool _importAsDeparture = false;

  /// Arms [_importAsDeparture]. Called when the departure picker sends the
  /// driver out to another app.
  void expectDepartureImport() => _importAsDeparture = true;

  /// Same idea for the trip's end: armed when the finish picker hands off to
  /// Google Maps or WhatsApp, so the place that comes back becomes where the
  /// day ends rather than another stop to visit.
  bool _importAsFinish = false;

  void expectFinishImport() => _importAsFinish = true;

  void cancelFinishImport() => _importAsFinish = false;

  /// Disarms it — the driver backed out of that flow.
  void cancelDepartureImport() => _importAsDeparture = false;

  void endMultiStopTrip() {
    if (!state.multiStopIntent) return;
    emit(state.copyWith(multiStopIntent: false));
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

  /// Sets (or, with a blank [phone], clears) the stop's contact number.
  void setPointPhone(String id, String? phone) {
    final trimmed = phone?.trim();
    final clear = trimmed == null || trimmed.isEmpty;
    RoutePoint apply(RoutePoint p) => p.id != id
        ? p
        : clear
        ? p.copyWith(clearPhone: true)
        : p.copyWith(phone: trimmed);

    final list = state.points.map(apply).toList();

    // The solved route keeps its own copies of the stops, so a number added
    // after optimizing — or added *mid-drive*, from the HUD, which is where
    // it is most likely to happen — would otherwise be invisible to every
    // screen that reads the route rather than the plan. The route's own
    // return leg carries a suffixed id and simply never matches, which is
    // correct: it is the depot.
    final route = state.optimizedRoute;
    emit(
      state.copyWith(
        points: list,
        optimizedRoute: route?.withPoints(
          route.orderedPoints.map(apply).toList(),
        ),
        status: RoutePlannerStatus.pointsUpdated,
      ),
    );
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

    final list = [...state.points]
      ..[idx] = state.points[idx].copyWith(
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

    final list = [...state.points]
      ..[idx] = state.points[idx].copyWith(
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
    return departure.subtract(Duration(minutes: shift)).isAfter(DateTime.now());
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
        // The intent belonged to the trip that just ended, not to the app.
        multiStopIntent: false,
        // So does where that day was going to end, and when it set off. Both
        // used to survive a clear, so the next trip started already carrying
        // yesterday's finish point and departure time without saying so.
        finish: const RouteFinish.depot(),
        clearDepartureAt: true,
        placementTarget: PlacementTarget.stop,
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
  /// [target] says what the crosshair is aiming at — the next stop by
  /// default, or the trip's starting point.
  void beginManualPlacement({PlacementTarget target = PlacementTarget.stop}) {
    if (!state.manualPlacement || state.placementTarget != target) {
      emit(state.copyWith(manualPlacement: true, placementTarget: target));
    }
  }

  /// Leaves the manual-placement flow (e.g. the user backed out of it),
  /// hiding the crosshair again while the route is still empty.
  void cancelManualPlacement() {
    if (state.manualPlacement) {
      emit(
        state.copyWith(
          manualPlacement: false,
          placementTarget: PlacementTarget.stop,
        ),
      );
    }
  }

  // ── Bulk add from text ─────────────────────────────────────

  /// Parse multi-line text (one address per line), forward-geocode each,
  /// and add matching points to the map. Returns the count of points added.
  /// Adds every line of shared / pasted [text] as a stop. Each line is a map
  /// link, a `lat,lng` pair, or an address — nothing else is known about it.
  Future<int> addPointsFromText(String text) {
    final lines = text
        .split(RegExp(r'[\n\r]+'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) => ImportedStop(locator: l))
        .toList();
    return addImportedStops(lines);
  }

  /// Adds stops that arrived from a structured import (a CSV), so the name and
  /// phone the office typed survive instead of being regenerated.
  ///
  /// Resolving is deliberately serial: each [addPoint] measures separation
  /// against the points already placed, and geocoding a whole sheet at once
  /// would hammer the geocoder besides.
  Future<int> addImportedStops(List<ImportedStop> stops) async {
    if (stops.isEmpty) return 0;

    int added = 0;
    for (final stop in stops) {
      try {
        // 1- Try to parse as a map URL (Google Maps, Apple Maps, …)
        final parsed = await MapLinkResolver.parseMapLine(stop.locator);
        LatLng? latLng;
        if (parsed != null) {
          latLng = parsed;
        } else {
          // 2- Try raw lat,lng pair (e.g. "33.5131, 36.2767")
          latLng = LinkParser.parseLatLngPair(stop.locator);
        }
        // 3- Fall back to forward-geocoding
        // Biased to where the round is: an imported "شارع بغداد" means the
        // one in this city, not the best-known one on the continent.
        latLng ??= await _places.resolveOne(stop.locator, near: searchAnchor);
        if (latLng == null) continue;
        // Armed from the "start from" sheet: the first place that lands is
        // where the trip begins, and everything after it is a stop again.
        if (_importAsDeparture) {
          _importAsDeparture = false;
          await setDeparture(latLng, address: stop.label);
          added++;
          continue;
        }
        if (_importAsFinish) {
          _importAsFinish = false;
          await setRouteFinish(RouteFinish.at(latLng, label: stop.label));
          added++;
          continue;
        }
        final point = await addPoint(
          latLng,
          label: stop.label,
          phone: stop.phone,
        );
        if (point != null) added++;
      } catch (_) {
        continue;
      }
    }
    return added;
  }

  // ── Optimize ──────────────────────────────────────────────

  /// Solves the trip and shows the result.
  ///
  /// [quiet] is the navigator shape's version of the same call: no
  /// full-screen planning animation, and a failure that says nothing. It is
  /// used for the automatic single-destination route, which the driver never
  /// asked for out loud — if it doesn't land, the card simply keeps its "Go"
  /// button and tries again, loudly, when they press it.
  /// Load a round from a `.laffa` file the driver was emailed.
  ///
  /// Replaces the current plan outright rather than merging: the file is a
  /// dispatcher's finished round, and quietly mixing it into whatever was
  /// half-built on the phone would produce a trip neither of them asked for.
  /// The existing draft is overwritten, so this is only reached from an
  /// explicit "open" of a file.
  ///
  /// Returns null on success, or a message to show the driver.
  Future<String?> importLaffaFile(String path) async {
    _cancelSimTimer();
    _cancelNavigationStream();

    final String raw;
    try {
      raw = await File(path).readAsString();
    } catch (_) {
      return AppStrings.errLaffaUnreadable;
    }

    final LaffaFile round;
    try {
      round = LaffaFile.parse(raw);
    } on LaffaFormatException catch (e) {
      return e.message;
    } catch (_) {
      return AppStrings.errLaffaUnreadable;
    }

    emit(
      state.copyWith(
        points: _relabelGenerated(_ensureSingleDepot(round.points)),
        finish: round.finish,
        status: RoutePlannerStatus.pointsUpdated,
        multiStopIntent: true,
        clearOptimizedRoute: true,
        clearError: true,
        draftRestored: false,
        manualPlacement: false,
        placementTarget: PlacementTarget.stop,
        simulationActive: false,
        simulationPlaying: false,
        simulationProgress: 0.0,
        navigationActive: false,
        navigationProgress: 0.0,
        clearNavigationHeading: true,
        clearNavigationSpeed: true,
        cameraTarget: round.points.first.latLng,
      ),
    );
    _schedulePersist();
    return null;
  }

  /// Change where the day ends and replan, because the answer depends on it.
  ///
  /// Nothing happens when the choice is unchanged, so tapping the current
  /// option in the sheet does not throw away a perfectly good route.
  Future<void> setRouteFinish(RouteFinish finish) async {
    if (finish == state.finish) return;
    // Recentre on a custom finish. Picking it on the map already leaves the
    // camera there, but an address search, a Google link or a WhatsApp pin
    // can land it well off screen — and a marker the driver cannot find is
    // no better than the missing one it replaced.
    emit(
      state.copyWith(
        finish: finish,
        cameraTarget: finish.effectiveMode == RouteEndMode.custom
            ? finish.location
            : null,
      ),
    );
    if (state.optimizedRoute != null) await optimize();
  }

  Future<void> optimize({bool quiet = false}) async {
    _cancelNavigationStream();

    // Departure tracks the user's live location: refresh the auto-depot to the
    // latest fix so the route always starts from where they are now.
    final basePoints = state.userLocation == null
        ? state.points
        : [
            for (final p in state.points)
              p.id == kCurrentLocationDepotId
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
      if (quiet) {
        emit(state.copyWith(quietRouting: false));
        return;
      }
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
        // The quiet route leaves `status` alone on purpose — `isOptimizing`
        // is what raises the planning overlay.
        status: quiet ? null : RoutePlannerStatus.optimizing,
        quietRouting: quiet,
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
      finish: state.finish,
    );

    result.when(
      success: (route) {
        emit(
          state.copyWith(
            status: RoutePlannerStatus.optimizedSuccess,
            quietRouting: false,
            optimizedRoute: route,
            stopFractions: _fractionsFor(route),
            maneuverFractions: _maneuverFractionsFor(route),
            // Keep deactivated optional points around (dimmed on the map,
            // not part of the route) so deactivation stays reversible.
            points: [
              ..._stripTerminal(route.orderedPoints),
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
        if (quiet) {
          // Silent by design: nothing on screen promised a route yet.
          emit(
            state.copyWith(
              quietRouting: false,
              isOffline: f is NetworkFailure ? true : state.isOffline,
            ),
          );
          return;
        }
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
          stopFractions:
              state.stopFractions.length == route.orderedPoints.length
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

  /// Driver taps the serve button — the only way a point is completed.
  /// Marks the current target stop as done and activates the next one;
  /// serving the last point ends the trip.
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
            id: kCurrentLocationDepotId,
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

  /// Closes the current leg: advances to the next service point, or ends
  /// the trip after the final one. Only [servePoint] reaches it — nothing
  /// completes a point on the driver's behalf.
  void _advanceServicePoint() {
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
        navigationStopRouteDistanceMeters: _routeDistanceToStop(
          route: route,
          stopIndex: stopIndex,
          progress: newProgress,
        ),
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
    // A drive is exactly when losing the map hurts most, and exactly when
    // the driver is in no position to do anything about it.
    _keepOfflineMapAround(loc);
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
      progress = onRouteProg < _lastNavProgress
          ? _lastNavProgress
          : onRouteProg;
      _lastNavProgress = progress;
    } else {
      DebugLog.nav(
        'off route — progress frozen at '
        '${progress.toStringAsFixed(4)} [off-route fix]',
      );
    }

    // ── Service-point state machine ──
    // Upcoming → Arrived (the driver has reached the stop) → Served, and
    // only the driver serves it. The app used to complete a point by
    // itself as soon as the vehicle left the area, on the theory that
    // driving away is what "done" looks like. From the seat it looked
    // like the trip skipping a stop nobody had finished: a delivery still
    // in the boot, a customer not yet at the door, a wrong turn out of a
    // car park. So arriving now only *offers* the button, and it keeps
    // offering it until the driver presses it.
    final stopIndex = state.navigationStopIndex;
    var arrived = state.navigationArrived;
    double? distToStop;
    // Whether the vehicle is inside the radius *right now* — as opposed to
    // [_enteredServiceRadius], which stays armed once reached. Being off
    // the road is normal at a stop (driveways, yards, car parks), so this
    // is what the deviation watch has to read; the sticky flag would mute
    // rerouting for the rest of a trip the driver never confirmed.
    var atStop = false;
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
      atStop = distToStop <= radius;

      if (atStop && !_enteredServiceRadius) {
        DebugLog.nav(
          'ARRIVED at stop $stopIndex (${distToStop.toStringAsFixed(1)}m '
          '≤ ${radius.toStringAsFixed(1)}m) — serve button shown',
        );
        HapticFeedback.lightImpact();
        _enteredServiceRadius = true;
      } else if (!atStop && !_enteredServiceRadius) {
        // Driven straight past it, on the planned route. A 10 m radius is
        // easy for a fix in a street canyon to miss entirely, and a stop
        // the driver has demonstrably reached must still be closeable
        // without hunting for the long-press escape hatch.
        final passedStop =
            onRouteProg != null &&
            stopIndex < state.stopFractions.length &&
            progress >= state.stopFractions[stopIndex];
        if (passedStop) {
          DebugLog.nav(
            'PASSED stop $stopIndex on route '
            '(${distToStop.toStringAsFixed(0)}m away) — serve button shown',
          );
          HapticFeedback.lightImpact();
          _enteredServiceRadius = true;
        }
      }
      // Sticky: reached is reached. Drifting back out of a 10 m circle
      // while parked must not take the button away mid-press.
      arrived = _enteredServiceRadius;
    }

    // How far there still is to *drive* — arc length along the planned
    // polyline from here to the stop, so a U-turn, a one-way loop or a
    // motorway detour all count. Only meaningful with a trustworthy
    // on-route projection; off-route we hand the HUD nothing and it falls
    // back to the straight line until the reroute lands.
    final routeDistToStop = _routeDistanceToStop(
      route: route,
      stopIndex: stopIndex,
      progress: onRouteProg != null ? progress : null,
    );

    // Deviation watch: enough sustained, clearly-off-route movement kicks
    // off a background recalculation toward the current service point.
    _watchForDeviation(
      offRouteMeters: projection?.offRouteMeters,
      loc: loc,
      accuracy: position.accuracy,
      atStop: atStop,
    );

    DebugLog.nav(
      '→ emit progress=${progress.toStringAsFixed(4)} '
      'smoothedHeading=${_smoothedHeading?.toStringAsFixed(1)} '
      'speed=${_smoothedSpeed?.toStringAsFixed(2)} stopIndex=$stopIndex '
      'distToStop=${distToStop?.toStringAsFixed(1)}m '
      'routeDistToStop=${routeDistToStop?.toStringAsFixed(1)}m '
      'arrived=$arrived',
    );

    emit(
      state.copyWith(
        userLocation: loc,
        cameraTarget: loc,
        navigationProgress: progress,
        navigationStopIndex: stopIndex,
        navigationArrived: arrived,
        navigationStopDistanceMeters: distToStop,
        navigationStopRouteDistanceMeters: routeDistToStop,
        clearNavigationStopRouteDistance: routeDistToStop == null,
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
    required bool atStop,
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
    if (atStop) return;

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
        // The routing datasource turns a dead network into an empty route,
        // so an empty result is the shape "no signal" arrives in. Without
        // this check a driver out of coverage silently retries every few
        // seconds for the rest of the trip; instead they get the offline
        // banner, and the retry slows to something the radio can afford.
        // The saved geometry keeps drive mode running the whole time.
        await _refreshConnectivity();
        if (isClosed) return;
        final offline = state.isOffline;
        DebugLog.nav('REROUTE ✋ no geometry — backing off (offline=$offline)');
        _rerouteBackoffUntil = DateTime.now().add(
          offline
              ? NavigationConfig.rerouteOfflineCooldown
              : NavigationConfig.rerouteCooldown,
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
        points: _stripTerminal(saved.orderedPoints),
        finish: _finishFromOrdered(saved.orderedPoints),
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

  /// Remaining **drive** distance (metres) from [progress] along the route
  /// to the stop at [stopIndex] — the arc length of the polyline between
  /// the two, so every U-turn, one-way detour and roundabout on the way is
  /// counted. Straight-line distance flatters the driver badly here: a stop
  /// across a divided road is 30 m away and a 600 m drive.
  ///
  /// Null when there is nothing trustworthy to measure from — an off-route
  /// fix ([progress] null), a route with no geometry, or stop fractions
  /// that don't match the route.
  double? _routeDistanceToStop({
    required OptimizedRoute route,
    required int stopIndex,
    required double? progress,
  }) {
    if (progress == null) return null;
    if (stopIndex < 0 || stopIndex >= state.stopFractions.length) return null;
    if (route.fullPolyline.length < 2) return null;
    final totalKm = DistanceUtils.pathLengthKm(route.fullPolyline);
    if (totalKm <= 0) return null;
    final remaining = (state.stopFractions[stopIndex] - progress) * totalKm;
    // Past the stop's fraction but not served yet (drove by, or the
    // projection snapped ahead): "0 m" would be a lie, so hand the HUD
    // nothing and let it show the straight line instead.
    return remaining <= 0 ? null : remaining * 1000;
  }

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
      id: kCurrentLocationDepotId,
      latitude: loc.latitude,
      longitude: loc.longitude,
      label: AppStrings.departure,
      weight: RoutingConfig.defaultStopWeight,
      kind: RoutePointKind.depot,
    );
  }

  /// The inverse of the promotion in [_ensureSingleDepot]: a pin standing in
  /// as the depot becomes an ordinary stop again. Its name is left to
  /// [_relabelGenerated], which sees the whole list and can number it without
  /// colliding with the stops already there.
  RoutePoint _demoteToStop(RoutePoint depot) => depot.copyWith(
    kind: RoutePointKind.stop,
    optional: false,
    active: true,
  );

  /// True when [label] is one this app generated rather than one that came
  /// from the driver, a CSV row or a search result. [span] bounds the numbers
  /// worth testing — no list can hold more labels than it has points.
  bool _isGeneratedLabel(String label, int span) {
    if (label == AppStrings.departure) return true;
    if (label == AppStrings.destinationTitle) return true;
    for (var i = 1; i <= span; i++) {
      if (label == AppStrings.stopLabel(i)) return true;
      if (label == AppStrings.optionalStopLabel(i)) return true;
    }
    return false;
  }

  /// [_relabel], except that a stop carrying a name of its own keeps it —
  /// the same courtesy [_renumberIfNoLongerSole] extends. Numbering still
  /// counts those stops, so the generated names around them stay in order
  /// instead of repeating one the user can already see.
  List<RoutePoint> _relabelGenerated(List<RoutePoint> points) {
    final span = points.length;
    final sole = points.where((p) => !p.isDepot && !p.optional).length == 1;
    var stopCounter = 0;
    var optionalCounter = 0;
    final out = <RoutePoint>[];
    for (final p in points) {
      if (p.isDepot) {
        out.add(p.copyWith(label: AppStrings.departure));
        continue;
      }
      final n = p.optional ? ++optionalCounter : ++stopCounter;
      if (!_isGeneratedLabel(p.label, span)) {
        out.add(p);
        continue;
      }
      out.add(
        p.copyWith(
          label: p.optional
              ? AppStrings.optionalStopLabel(n)
              : sole
              ? AppStrings.destinationTitle
              : AppStrings.stopLabel(n),
        ),
      );
    }
    return out;
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
  /// separately from optional ones ("Stop 1, 2…" vs "Optional 1, 2…") —
  /// except a lone destination, which is named rather than numbered.
  List<RoutePoint> _relabel(List<RoutePoint> points) {
    final sole = points.where((p) => !p.isDepot && !p.optional).length == 1;
    var stopCounter = 1;
    var optionalCounter = 1;
    return points.map((p) {
      if (p.isDepot) return p.copyWith(label: AppStrings.departure);
      if (p.optional) {
        return p.copyWith(
          label: AppStrings.optionalStopLabel(optionalCounter++),
        );
      }
      if (sole) return p.copyWith(label: AppStrings.destinationTitle);
      return p.copyWith(label: AppStrings.stopLabel(stopCounter++));
    }).toList();
  }

  /// Gives the former lone destination its number back once a second one
  /// joins it — the mirror of the naming in [addPoint].
  ///
  /// Only the name this app generated is rewritten. A stop that arrived with
  /// its own name (a CSV row, an address search result) keeps it: that name
  /// is the driver's, and no amount of reshaping the trip makes it ours.
  List<RoutePoint> _renumberIfNoLongerSole(List<RoutePoint> points) {
    final stops = points.where((p) => !p.isDepot && !p.optional).toList();
    if (stops.length < 2) return points;
    var n = 0;
    return [
      for (final p in points)
        if (p.isDepot || p.optional)
          p
        else if (++n == 1 && p.label == AppStrings.destinationTitle)
          p.copyWith(label: AppStrings.stopLabel(1))
        else
          p,
    ];
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

  /// Drops the terminal an optimised route ends on before the sequence goes
  /// back into [points]. There are two of them and neither belongs to the
  /// plan: the return leg of a round trip, and the driver's chosen finish.
  ///
  /// Both are built as depot-kind points, so leaving one in gives [points]
  /// a second depot — and [OptimizeRouteUseCase] rejects that outright, so
  /// every later solve failed its validation before reaching the network,
  /// silently, while the finish came back as a numbered delivery.
  List<RoutePoint> _stripTerminal(List<RoutePoint> ordered) {
    if (ordered.length < 2) return ordered;
    final last = ordered.last;
    final isReturnLeg =
        last.latitude == ordered.first.latitude &&
        last.longitude == ordered.first.longitude;
    if (isReturnLeg || last.id.endsWith(kFinishPointIdSuffix)) {
      return ordered.sublist(0, ordered.length - 1);
    }
    return ordered;
  }

  /// Reads back the end-of-day choice an optimised sequence was built with —
  /// the inverse of the terminal that [_stripTerminal] takes off.
  ///
  /// Loading a saved route has to reset this, not inherit it. The finish
  /// belongs to a trip, and a route saved as a round trip that comes back
  /// wearing the previous trip's "finish at home" is lying about itself on
  /// the To row and would replan to somewhere the driver never chose.
  RouteFinish _finishFromOrdered(List<RoutePoint> ordered) {
    if (ordered.length < 2) return const RouteFinish.depot();
    final last = ordered.last;
    if (last.id.endsWith(kFinishPointIdSuffix)) {
      return RouteFinish.at(last.latLng, label: last.label);
    }
    final isReturnLeg =
        last.latitude == ordered.first.latitude &&
        last.longitude == ordered.first.longitude;
    return isReturnLeg ? const RouteFinish.depot() : const RouteFinish.open();
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
    _stopLiveLocation();
    // Flush any pending draft write so work isn't lost if the app is
    // being torn down mid-debounce.
    if (_persistDebounce?.isActive ?? false) {
      _persistDebounce!.cancel();
      _persistNow();
    }
    return super.close();
  }
}
