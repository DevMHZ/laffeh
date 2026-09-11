import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/config/driving_camera.dart';
import '../../../../core/config/env_config.dart';
import '../../../../core/config/map_config.dart';
import '../../../../core/config/navigation_config.dart';
import '../../../../core/config/simulation_config.dart';
import '../../../../core/config/vehicle_marker_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/vehicle_kind.dart';
import '../../../../core/theme/vehicle_nav_sheet.dart';
import '../../../../core/theme/vehicle_prefs.dart';
import '../../../../core/theme/vehicle_sprites.dart';
import '../../../../core/utils/debug_log.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../../../core/utils/marker_factory.dart';
import '../../../../core/utils/polyline_utils.dart';
import '../../data/datasources/map_label_reader.dart';
import '../../domain/entities/optimized_route.dart';
import '../../domain/entities/place_suggestion.dart';
import '../../domain/entities/route_finish.dart';
import '../../domain/entities/route_point.dart';
import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';
import 'map_action_button.dart';
import '../utils/sim_visit_states.dart';
import '../utils/route_motion_frame.dart';
import 'sheet_extent.dart';
import 'map_compass.dart';
import 'map_geometry.dart';
import 'map_marker_renderer.dart';
import 'map_place_sheet.dart';
import 'point_actions_sheet.dart';
import 'route_map_overlays.dart';

/// A dropped point lands at the camera's geographic `target` (read live, so
/// it's DPR-agnostic and never stale). The crosshair is a *Flutter overlay*,
/// though, and on Android the native map surface's centre doesn't line up
/// with the Flutter widget's centre — so the target renders a few logical
/// pixels off the geometric centre, pushing every native point (the blue
/// dot, a dropped marker) off the crosshair. We measure that gap live
/// ([RouteMapViewState.aimOffset]) and shift the crosshair onto it, instead
/// of the old hard-coded guess. See [RouteMapViewState._calibrateAim].

/// Describes one symbol to be rendered on the map.
class _SymbolSpec {
  final String key;
  final String imageId;
  final ll.LatLng position;
  final String? pointId;

  const _SymbolSpec({
    required this.key,
    required this.imageId,
    required this.position,
    this.pointId,
  });
}

/// OpenFreeMap-backed map surface using MapLibre GL vector tiles. Renders
/// user-picked points, the optimised polyline, and an animated vehicle marker
/// during playback.
///
/// Markers are rendered as MapLibre GL native symbols (canvas-drawn PNGs
/// registered with [MapLibreMapController.addImage]) so they stay perfectly
/// anchored to their geographic positions regardless of map movement — no
/// Flutter widget overlay lag.
/// Where the map chrome (compass, 2D/3D) sits above whatever is on the
/// bottom edge — a sheet, the preview scrubber, or a destination card.
///
/// Every one of those now reports its own height, so this is not a guess
/// about their sizes; the clamp only bounds the result.
///
/// The floor matches the sheet's bottom snap, so the chrome follows the sheet
/// all the way down when the driver parks it to look at the map, and stops
/// where the sheet stops. The ceiling keeps the buttons out of the top bar
/// when the sheet is dragged fully open — past it the sheet covers the map
/// anyway, and chrome floating over a sheet nobody can see through is worse
/// than chrome tucked behind it.
const double _mapChromeFloor = 0.10;
const double _mapChromeCeiling = 0.70;
const double _mapChromeGap = 14;

class RouteMapView extends StatefulWidget {
  final ValueChanged<OptimizedRoute?>? onRouteReady;
  const RouteMapView({super.key, this.onRouteReady});

  @override
  State<RouteMapView> createState() => RouteMapViewState();
}

class RouteMapViewState extends State<RouteMapView>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  MapLibreMapController? _controller;
  bool _styleLoaded = false;

  /// Compass bearing (degrees clockwise from north). Updated on every camera
  /// move so the compass widget can counter-rotate the needle in real time.
  final ValueNotifier<double> _bearing = ValueNotifier(0);

  /// Camera tilt in degrees, 0 flat. Feeds the same control the bearing
  /// does: once the map can be tilted by hand, "put it back" has to cover
  /// the angle as well as the heading, or the driver is left looking at a
  /// 3D map with no way out of it.
  final ValueNotifier<double> _tilt = ValueNotifier(0);

  /// Tilt the map was at when an aiming flow began, so the 3D view can be
  /// handed back afterwards. Null when the map was already flat.
  double? _tiltBeforeAiming;

  /// Drives the on-map "return to my location" control: flips to true once
  /// the user pans the planning map noticeably away from their current
  /// position, and back to false when they're roughly centred on it again.
  final ValueNotifier<bool> _showRecenter = ValueNotifier(false);

  /// Logical-pixel vector from the map widget's geometric centre to where
  /// the camera *target* (= the drop point) actually renders on this device.
  ///
  /// ~`Offset.zero` on iOS/web (the plugin projects in logical points that
  /// match Flutter). On a real Android phone it's non-zero: the plugin
  /// projects in PHYSICAL pixels and the native map view's centre doesn't
  /// align with the Flutter widget's centre, so a marker dropped at the
  /// camera target sits off the crosshair. The crosshair overlays shift by
  /// this so they stay exactly on the true drop point. Measured live in
  /// [_calibrateAim] — never a hard-coded constant, since it depends on
  /// device DPR + system-inset geometry.
  final ValueNotifier<Offset> aimOffset = ValueNotifier<Offset>(Offset.zero);
  bool _calibrating = false;

  /// Plugin projection unit factor: physical px on Android, logical
  /// everywhere else. `toScreenLocation`/`toLatLng` results are divided by
  /// this to land in Flutter's logical-pixel space.
  double get _aimScale =>
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ? _dpr : 1.0;

  /// The LatLng beneath the aim reticle = the camera's geographic target
  /// (the reticle sits at the exact viewport centre). Read live from the
  /// controller at access time so a point always drops where the crosshair
  /// is, with no staleness and no DPR-sensitive pixel projection.
  ll.LatLng _mapCenter = const ll.LatLng(
    MapConfig.fallbackLat,
    MapConfig.fallbackLon,
  );
  ll.LatLng get mapCenter {
    final cam = _controller?.cameraPosition;
    final t = cam?.target;
    if (t != null) {
      _mapCenter = ll.LatLng(t.latitude, t.longitude);
      DebugLog.add(
        'mapCenter read live target=${t.latitude.toStringAsFixed(6)},'
        '${t.longitude.toStringAsFixed(6)} zoom=${cam?.zoom.toStringAsFixed(2)} '
        'dpr=$_dpr styleLoaded=$_styleLoaded',
      );
    } else {
      // If the controller can't report a camera target (seen on some real
      // devices before the first idle) we fall back to the cached centre —
      // which may be stale, dropping the point in the wrong place.
      DebugLog.add(
        'mapCenter ⚠️ controller/target NULL (controller=${_controller != null}) '
        '→ using cached ${_mapCenter.latitude.toStringAsFixed(6)},'
        '${_mapCenter.longitude.toStringAsFixed(6)}',
      );
    }
    return _mapCenter;
  }

  /// Recomputes and returns the LatLng under the aim reticle right now.
  /// Used when committing a point move so we never act on a stale centre.
  Future<ll.LatLng> resolveCenter() async {
    _updateMapCenter();
    DebugLog.add(
      'resolveCenter (move) → ${_mapCenter.latitude.toStringAsFixed(6)},'
      '${_mapCenter.longitude.toStringAsFixed(6)}',
    );
    return _mapCenter;
  }

  /// Pans the camera to the user's current location for the on-map "return
  /// to my location" control. Always animates — even when the coordinate
  /// matches the last programmatic move (e.g. a fixed-GPS emulator) — so it
  /// never feels dead. Reads the freshly-fetched location from cubit state,
  /// so call it right after [RoutePlannerCubit.recenterOnUser]. Keeps the
  /// current zoom unless we're zoomed out past [MapConfig.focusedZoom].
  ///
  /// Deliberately does NOT touch [_lastFocusedTarget]: that field tracks the
  /// cubit's `cameraTarget` (which a plain recenter doesn't change), and
  /// desyncing the two made the next `addPoint` snap the camera back here.
  Future<void> recenterOnUser() async {
    if (!mounted) return;
    final loc = context.read<RoutePlannerCubit>().state.userLocation;
    if (loc == null) return;
    final current = _controller?.cameraPosition?.zoom ?? MapConfig.focusedZoom;
    final zoom = current < MapConfig.focusedZoom
        ? MapConfig.focusedZoom
        : current;
    await _animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _ml(loc), zoom: zoom),
      ),
    );
  }

  /// Tap handler for the on-map "return to my location" control: refreshes
  /// the GPS fix (and the blue dot), then animates back to it. On failure
  /// the cubit surfaces the usual location error and we don't move.
  Future<void> _returnToUser() async {
    if (!mounted) return;
    final cubit = context.read<RoutePlannerCubit>();

    // 1) Respond instantly: pan to the last-known fix we already have, so the
    //    button never feels dead while a precise GPS lock is acquired (that
    //    cold fix can take several seconds on a weak signal).
    final cached = await cubit.recenterOnUserCached();
    if (!mounted) return;
    if (cached != null) await recenterOnUser();

    // 2) Refine: once a precise fix lands, nudge to it — but only if it
    //    actually moved, to avoid a pointless re-animation to the same spot.
    //    Suppress its error banner when we already recentred via the cache.
    if (await cubit.recenterOnUser(surfaceError: cached == null)) {
      if (!mounted) return;
      final fresh = context.read<RoutePlannerCubit>().state.userLocation;
      if (cached == null ||
          (fresh != null &&
              DistanceUtils.haversineKm(cached, fresh) * 1000 > 12)) {
        await recenterOnUser();
      }
    }
  }

  // ── Camera tracking ────────────────────────────────────────────────────────
  bool _hasFitOptimizedBounds = false;
  bool _hasFitOverviewBounds = false;
  ll.LatLng? _lastFocusedTarget;
  SimulationCameraMode? _lastSimCameraMode;
  bool _wasNavigationActive = false;
  bool _simCameraAnchored = false;
  bool _northLock = false;
  // Point id we've already framed for the current "move" session.
  String? _centeredMoveId;

  // ── Frame coalescing ────────────────────────────────────────────────────────
  // Playback emits faster than the native map can repaint. We apply the
  // *latest* state and drop intermediate frames, so camera/markers never
  // lag behind on a backlog of stale platform-channel calls.
  RoutePlannerState? _pendingApply;
  bool _applying = false;

  // ── Native symbol overlay ──────────────────────────────────────────────────
  // Keyed by _SymbolSpec.key; tracks live symbols for add/update/remove.
  final Map<String, Symbol> _symbols = {};
  // Last spec we actually pushed per key, so we can skip no-op updates.
  final Map<String, _SymbolSpec> _appliedSpecs = {};
  // Image IDs already registered with the map style via controller.addImage.
  final Set<String> _registeredImages = {};

  /// Smoothed direction of travel for the preview chase camera.
  double? _travelBearing;

  // Both preview and drive render a geographic vehicle and the joining
  // route lines in one native GeoJSON source, never a screen-fixed overlay.
  Ticker? _vehicleTicker;
  bool _simRunning = false;
  double _renderProgress = 0;
  double _targetProgress = 0;
  OptimizedRoute? _simRoute;
  SimulationCameraMode _simMode = SimulationCameraMode.follow;
  double? _previewTiltOverride;
  double _dpr = 1;
  Duration _lastSimTick = Duration.zero;
  RoutePlannerState? _motionState;
  bool _motionVisible = false;
  String? _motionImage;
  double _motionImageScale = 1;
  bool _loadingMotionImage = false;
  String? _motionImageKind;
  int? _motionHeadingFrame;
  DateTime _lastMotionFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  double? _lastMotionProgress;
  double? _lastMotionBearing;
  OptimizedRoute? _lastMotionRoute;
  int? _lastMotionStop;
  ll.LatLng? _lastMotionAnchor;
  String? _lastMotionImage;
  final _mapPointers = <int>{};
  late final _motionWriter = LatestFrameWriter<Map<String, dynamic>>(
    (frame) async {
      if (_disposed || !_styleLoaded) return;
      await _controller?.setGeoJsonSource(_srcTrail, frame);
    },
    onError: (error, _) {
      _lastMotionProgress = null;
      DebugLog.map('motion frame failed: $error');
    },
  );

  // ── Pseudo-3D vehicle frames ────────────────────────────────────────────────
  // The decoded nav sheet for the picked vehicle (48 headings × 4 phases,
  // see [VehicleNavSheet]): the native symbol modes pick the frame nearest
  // the vehicle-minus-camera bearing each tick and rotate only the ±3.75°
  // residual, so the car shows real 3D perspective while turning stays
  // smooth. Null while decoding — and permanently for painter-drawn kinds
  // (arrow) or a missing bake — which keeps the legacy flat-sprite path.
  // Native heading frames share this decoded sheet.
  ui.Image? _navSheet;
  VehicleKind? _navSheetKind;
  bool _navSheetLoading = false;

  // Frames are cached by vehicle, heading and size. Native symbols hold
  // phase zero; changing the bitmap per wheel phase causes symbol pulsing.
  final Set<String> _pendingFrameImages = {};
  // ── Overview (panoramic) framing ────────────────────────────────────────────
  // The camera/zoom we framed the whole route at. If the user pinch-zooms
  // or pans away from it, [_overviewAdjusted] flips so we can offer a
  // "reset view" button that re-frames the full panorama.
  ll.LatLng? _overviewCam;
  double _overviewZoom = 0.0;
  bool _overviewAdjusted = false;

  // ── GeoJSON source / layer IDs ─────────────────────────────────────────────
  static const _srcBg = 'poly-bg';
  static const _srcFg = 'poly-fg';
  static const _srcTrail = 'poly-trail';
  static const _srcManeuver = 'poly-maneuver';
  static const _lyrBg = 'lyr-bg';
  static const _lyrFg = 'lyr-fg';
  static const _lyrTrail = 'lyr-trail';
  static const _lyrManeuver = 'lyr-maneuver';

  /// Smoothed bearing used by the locked live navigation camera.
  double? _navBearing;

  /// Ease zoom, tilt and forward distance together, using elapsed time
  /// rather than the number of GPS callbacks.
  final _drivingCamera = DrivingCameraSmoother();
  final _cameraClock = Stopwatch()..start();

  /// False until the drive camera's first frame, which snaps into place;
  /// every later update glides via animateCamera.
  bool _navCamSnapped = false;

  /// True while the driver is freely panning/zooming the map mid-drive:
  /// the follow camera pauses (navigation itself continues) and a
  /// "Re-center" pill is shown. Auto-resumes after
  /// [NavigationConfig.exploreResumeDelay] without touches.
  final ValueNotifier<bool> _navExploring = ValueNotifier(false);
  Timer? _exploreResumeTimer;

  // ── Nav vehicle render loop (vsync) ─────────────────────────────────────────
  // GPS fixes land ~once a second; drawing the car straight off them makes
  // it teleport fix-to-fix while the camera glides. This ticker renders the
  // car every display frame instead: the fix is dead-reckoned forward at
  // the vehicle's speed and the rendered arc-length progress chases it with
  // an exponential smoother — continuous, forward-only motion.
  Ticker? _navTicker;
  Duration _navTickerLast = Duration.zero;
  double _navRenderProgress = 0.0;
  double _navTargetProgress = 0.0;
  DateTime _navTargetAt = DateTime.fromMillisecondsSinceEpoch(0);
  double _navProgressRatePerSec = 0.0;
  OptimizedRoute? _navRoute;
  double _navRouteTotalKm = 0.0;

  /// Whether the maneuver-highlight layer currently holds geometry, so
  /// non-drive modes can clear it exactly once instead of every frame.
  bool _maneuverHlVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Orientation / window-size change: the drive camera's look-ahead is
  /// viewport-dependent, and GPS only ticks after ~5 m of movement — so a
  /// rotation while stopped would leave the car mis-framed until the next
  /// fix. Re-aim as soon as the new layout settles.
  @override
  void didChangeMetrics() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<RoutePlannerCubit>().state;
      if (state.navigationActive && state.optimizedRoute != null) {
        unawaited(_syncNavigationCamera(state));
      }
    });
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _vehicleTicker
      ?..stop()
      ..dispose();
    _navTicker
      ?..stop()
      ..dispose();
    _motionWriter.dispose();
    _exploreResumeTimer?.cancel();
    _navExploring.dispose();
    _controller?.onSymbolTapped.remove(_onSymbolTapped);
    _controller = null;
    _styleLoaded = false;
    _bearing.dispose();
    _tilt.dispose();
    _showRecenter.dispose();
    aimOffset.dispose();
    super.dispose();
  }

  // ── Map lifecycle ───────────────────────────────────────────────────────────

  void _onMapCreated(MapLibreMapController controller) {
    DebugLog.map('onMapCreated — controller attached');
    _controller = controller;
    controller.onSymbolTapped.add(_onSymbolTapped);
  }

  Future<void> _onStyleLoaded() async {
    _styleLoaded = false;
    widget.onRouteReady?.call(null);
    _dpr =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    // DPR drives icon sizing + the historical drop-accuracy bug. It differs
    // between the Simulator and a physical phone, so log it explicitly.
    DebugLog.map('onStyleLoaded ✅ — devicePixelRatio=$_dpr');
    await _initPolylineLayers();
    if (!mounted) return;
    _styleLoaded = true;
    _lastMotionProgress = null;

    // Allow symbols to overlap each other and map text so all markers show.
    await _controller?.setSymbolIconAllowOverlap(true);
    await _controller?.setSymbolIconIgnorePlacement(true);

    await _cacheLabelLayers();

    if (!mounted) return;
    _scheduleApply(context.read<RoutePlannerCubit>().state);

    // Measure the crosshair↔native-map alignment once the surface has a
    // stable size. onCameraIdle refreshes it after pans/rotations.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => unawaited(_calibrateAim()),
    );
  }

  void _onCameraMove(CameraPosition position) {
    _bearing.value = position.bearing;
    _tilt.value = position.tilt;
    // Keep the drop point (= camera centre) continuously fresh, so adding
    // a point is accurate even if onCameraIdle is unreliable on a device.
    _mapCenter = ll.LatLng(position.target.latitude, position.target.longitude);

    // Rotation may change while paused. Reorient the native avatar at its
    // existing route position; camera movement never changes its coordinates.
    if (_motionState?.navigationActive == true) {
      _publishMotionFrame(navigation: true);
    } else if (_simRunning) {
      _publishMotionFrame(navigation: false);
    }

    // Toggle the "return to my location" control as the user pans away from
    // their current position. The threshold scales with zoom so it triggers
    // at a similar on-screen drift at any scale. Visibility is further gated
    // to planning mode in the button's own builder.
    if (mounted) {
      final loc = context.read<RoutePlannerCubit>().state.userLocation;
      var away = false;
      if (loc != null) {
        final metersPerPixel =
            78271.5 *
            math.cos(position.target.latitude * math.pi / 180) /
            math.pow(2, position.zoom);
        final drift =
            DistanceUtils.haversineKm(
              ll.LatLng(position.target.latitude, position.target.longitude),
              loc,
            ) *
            1000;
        away = drift > metersPerPixel * MapConfig.recenterDriftPx;
      }
      if (_showRecenter.value != away) _showRecenter.value = away;
    }

    // Panoramic mode: if the user zooms or pans away from the framed
    // route, offer a "reset view" button to re-fit the whole panorama.
    if (_simRunning &&
        _simMode == SimulationCameraMode.overview &&
        _hasFitOverviewBounds &&
        !_overviewAdjusted &&
        _overviewCam != null) {
      final zoomDelta = (position.zoom - _overviewZoom).abs();
      final moved =
          DistanceUtils.haversineKm(
            ll.LatLng(position.target.latitude, position.target.longitude),
            _overviewCam!,
          ) *
          1000;
      if (zoomDelta > MapConfig.overviewResetZoomDelta ||
          moved > MapConfig.overviewResetMoveMeters) {
        setState(() => _overviewAdjusted = true);
      }
    }
  }

  void _onCameraIdle() {
    _updateMapCenter();
    // Settle the heading/angle from the camera itself rather than trusting
    // the last `onCameraMove`. An animated move stops reporting a frame or
    // two before it finishes, which leaves a hair of tilt on the notifier —
    // enough to strand the "put the map back" control on screen after it has
    // already put the map back.
    final cam = _controller?.cameraPosition;
    if (cam != null) {
      _bearing.value = cam.bearing;
      _tilt.value = cam.tilt;
    }
    unawaited(_calibrateAim());
  }

  /// Measures [aimOffset]: how far (in logical pixels) the camera target —
  /// the point where a dropped marker actually renders — sits from the map
  /// widget's geometric centre, where the crosshair is otherwise drawn.
  ///
  /// On iOS/web the plugin projects in logical points, so this comes out
  /// ~zero. On Android it projects in PHYSICAL pixels and the native view's
  /// centre is offset from the Flutter widget's, so the target lands a few
  /// logical pixels off-centre; we shift the crosshair onto it so what the
  /// user aims at is what gets dropped. Also logs a metres-apart figure so
  /// the on-device error is greppable (`🐛 ... [MAP] aimCalib`).
  Future<void> _calibrateAim() async {
    if (_calibrating || !mounted) return;
    final c = _controller;
    if (c == null || !_styleLoaded) return;
    final cam = c.cameraPosition;
    final t = cam?.target;
    final box = context.findRenderObject() as RenderBox?;
    if (t == null || box == null || !box.hasSize) return;
    // aimOffset is the *top-down* crosshair↔native-centre offset. Under the
    // drive/preview tilt (or any rotation) the target projects off-centre by
    // design, so calibrating then would overwrite the good planning value
    // with a tilted one — skip unless we're flat and north-up.
    final bearing = (cam!.bearing % 360 + 360) % 360;
    if (cam.tilt.abs() > 1.0 || (bearing > 1.0 && bearing < 359.0)) return;

    _calibrating = true;
    try {
      final size = box.size; // logical px
      // Android's projection speaks physical px; iOS/web speak logical px.
      final scale = _aimScale;
      final center = Offset(size.width / 2, size.height / 2);

      final sp = await c.toScreenLocation(LatLng(t.latitude, t.longitude));
      if (!mounted) return;
      final projected = Offset(sp.x / scale, sp.y / scale);
      final offset = projected - center;

      // Reject garbage from a mid-layout projection (offset can't exceed the
      // viewport); keep the last good value instead.
      if (offset.dx.abs() > size.width || offset.dy.abs() > size.height) return;
      if ((offset - aimOffset.value).distance > 0.5) aimOffset.value = offset;

      // Diagnostics only (skipped in release): a second round-trip to report
      // the LatLng under the centred crosshair and how far that is, in metres,
      // from where we currently drop (the camera target).
      if (!DebugLog.enabled) return;
      final under = await c.toLatLng(
        math.Point<num>(center.dx * scale, center.dy * scale),
      );
      final metres =
          DistanceUtils.haversineKm(
            ll.LatLng(t.latitude, t.longitude),
            ll.LatLng(under.latitude, under.longitude),
          ) *
          1000;
      DebugLog.map(
        'aimCalib dpr=$_dpr scale=$scale '
        'size=${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)} '
        'targetPx=${sp.x.toStringAsFixed(1)},${sp.y.toStringAsFixed(1)} '
        'proj=${projected.dx.toStringAsFixed(1)},${projected.dy.toStringAsFixed(1)} '
        'centre=${center.dx.toStringAsFixed(1)},${center.dy.toStringAsFixed(1)} '
        '→ aimOffset=${offset.dx.toStringAsFixed(1)},${offset.dy.toStringAsFixed(1)}px '
        '(crosshair vs drop ≈ ${metres.toStringAsFixed(1)}m)',
      );
    } catch (_) {
      // Projection can throw before the first render; ignore and retry on
      // the next idle.
    } finally {
      _calibrating = false;
    }
  }

  /// The point under the reticle = the camera's geographic target.
  ///
  /// We deliberately do NOT project a screen pixel via `toLatLng`: that
  /// call is device-pixel-ratio sensitive and, on real devices (DPR 2–3),
  /// returned a coordinate far from the reticle — so dropped points landed
  /// somewhere else entirely. The camera target is exact and DPR-agnostic.
  void _updateMapCenter() {
    final t = _controller?.cameraPosition?.target;
    if (t != null) _mapCenter = ll.LatLng(t.latitude, t.longitude);
  }

  // ── Programmatic camera wrappers ────────────────────────────────────────────

  Future<void> _moveCamera(CameraUpdate update) async {
    final c = _controller;
    if (c == null || !_styleLoaded) return;
    await c.moveCamera(update);
  }

  Future<void> _animateCamera(CameraUpdate update) async {
    final c = _controller;
    if (c == null || !_styleLoaded) return;
    await c.animateCamera(update);
    await Future.delayed(MapConfig.animateSettle);
  }

  // ── Polyline layer management ───────────────────────────────────────────────

  Future<void> _initPolylineLayers() async {
    final c = _controller;
    if (c == null) return;

    await c.addGeoJsonSource(_srcBg, MapGeometry.emptyGeoJson);
    await c.addLineLayer(
      _srcBg,
      _lyrBg,
      const LineLayerProperties(
        lineColor: '#87978C',
        lineWidth: MapConfig.planBgWidth,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );

    await c.addGeoJsonSource(_srcFg, MapGeometry.emptyGeoJson);
    await c.addLineLayer(
      _srcFg,
      _lyrFg,
      const LineLayerProperties(
        lineColor: '#3E9148',
        lineWidth: MapConfig.planFgWidth,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );

    await c.addGeoJsonSource(_srcTrail, MapGeometry.emptyGeoJson);
    await c.addLineLayer(
      _srcTrail,
      'lyr-motion-done',
      LineLayerProperties(
        lineColor: MapGeometry.hex(AppColors.driveDone),
        lineWidth: MapConfig.driveDoneWidth,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      filter: [
        '==',
        ['get', 'role'],
        'done',
      ],
    );
    await c.addLineLayer(
      _srcTrail,
      _lyrTrail,
      const LineLayerProperties(
        lineColor: '#63B956',
        lineWidth: MapConfig.simTrailWidth,
        lineCap: 'round',
        lineJoin: 'round',
      ),
      filter: [
        '==',
        ['get', 'role'],
        'trail',
      ],
    );

    // Drive-mode turn guidance: a bright white segment drawn over the
    // route at the upcoming maneuver, so the correct branch is obvious.
    // Added last = renders on top of every other route line.
    await c.addGeoJsonSource(_srcManeuver, MapGeometry.emptyGeoJson);
    await c.addLineLayer(
      _srcManeuver,
      _lyrManeuver,
      const LineLayerProperties(
        lineColor: '#FFFFFF',
        lineWidth: MapConfig.driveManeuverWidth,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );
    await c.addSymbolLayer(
      _srcTrail,
      'lyr-motion-vehicle',
      const SymbolLayerProperties(
        iconImage: ['get', 'image'],
        iconSize: ['get', 'scale'],
        iconRotate: ['get', 'rotation'],
        iconAnchor: 'center',
        iconRotationAlignment: 'viewport',
        iconPitchAlignment: 'viewport',
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ),
      filter: [
        '==',
        ['get', 'role'],
        'vehicle',
      ],
      enableInteraction: false,
    );
  }

  /// Tracks the active line-style so we only re-apply layer paint when
  /// the *mode* changes (planning ↔ sim ↔ drive), not on every 60 ms
  /// playback tick. Geometry (the GeoJSON sources) still updates every
  /// frame, so colours switch the instant a state flips — no lag, no
  /// stuck-orange segment (#1).
  String? _lineStyleKey;

  Future<void> _syncPolylines(RoutePlannerState state) async {
    if (_disposed) return;
    final c = _controller;
    if (c == null || !_styleLoaded) return;

    final route = state.optimizedRoute;
    if (route == null) {
      await c.setGeoJsonSource(_srcBg, MapGeometry.emptyGeoJson);
      await c.setGeoJsonSource(_srcFg, MapGeometry.emptyGeoJson);
      _clearMotionFrame();
      await _clearManeuverHighlight();
      _lineStyleKey = 'empty';
      return;
    }

    final styleKey = state.navigationActive
        ? 'nav'
        : state.simulationActive
        ? 'sim'
        : 'plan-${state.displaySegment.name}';
    final restyle = styleKey != _lineStyleKey;
    _lineStyleKey = styleKey;

    final full = route.fullPolyline;

    // ── Drive mode (#2): three contiguous, instantly-recoloured legs ──
    //   done (light green) → current leg to next stop (blue) → ahead (green)
    if (state.navigationActive) {
      final p = state.navigationProgress.clamp(0.0, 1.0);
      final nextFrac = MapGeometry.nextStopFraction(
        route,
        state.navigationStopIndex,
        p,
      );

      if (restyle) await c.setGeoJsonSource(_srcBg, MapGeometry.emptyGeoJson);
      await c.setGeoJsonSource(
        _srcFg,
        MapGeometry.lineGeoJson(MapGeometry.subPath(full, nextFrac, 1.0)),
      );
      _publishMotionFrame(navigation: true);
      await _syncManeuverHighlight(state, full, p);
      if (restyle) {
        await _setLine(
          'lyr-motion-done',
          AppColors.driveDone,
          MapConfig.driveDoneWidth,
        );
        await _setLine(_lyrFg, AppColors.driveAhead, MapConfig.driveAheadWidth);
        await _setLine(
          _lyrTrail,
          AppColors.driveCurrent,
          MapConfig.driveCurrentWidth,
        );
      }
      return;
    }

    // Not driving — make sure no stale turn highlight lingers.
    await _clearManeuverHighlight();

    // ── Trip preview / simulation ──
    if (state.simulationActive) {
      _publishMotionFrame(navigation: false);
      if (restyle) {
        await c.setGeoJsonSource(_srcBg, MapGeometry.lineGeoJson(full));
        await c.setGeoJsonSource(_srcFg, MapGeometry.emptyGeoJson);
        await _setLine(
          _lyrBg,
          AppColors.primary.withValues(alpha: 0.22),
          MapConfig.simGhostWidth,
        );
        await _setLine(_lyrTrail, AppColors.accent, MapConfig.simTrailWidth);
      }
      return;
    }

    // ── Planning mode (segment highlight) ──
    final highlighted = switch (state.displaySegment) {
      RouteSegment.go => route.goPolyline,
      RouteSegment.returnLeg => route.returnPolyline,
      RouteSegment.full => full,
    };
    final fgColor = switch (state.displaySegment) {
      RouteSegment.go => AppColors.routeGo,
      RouteSegment.returnLeg => AppColors.routeReturn,
      RouteSegment.full => AppColors.routeFull,
    };
    await c.setGeoJsonSource(_srcBg, MapGeometry.lineGeoJson(full));
    await c.setGeoJsonSource(_srcFg, MapGeometry.lineGeoJson(highlighted));
    _clearMotionFrame();
    if (restyle) {
      // styleKey encodes the chosen segment, so this re-applies whenever
      // the user toggles go / return / full.
      await _setLine(
        _lyrBg,
        AppColors.textMuted.withValues(alpha: 0.55),
        MapConfig.planBgWidth,
      );
      await _setLine(_lyrFg, fgColor, MapConfig.planFgWidth);
    }
  }

  /// Turn guidance (drive mode): once the vehicle is within
  /// [NavigationConfig.maneuverHighlightWithinMeters] of the upcoming
  /// maneuver, paint a short bright-white segment of the route from the
  /// maneuver point forward — the selected branch pops out of the
  /// intersection/roundabout so the driver never hesitates.
  Future<void> _syncManeuverHighlight(
    RoutePlannerState state,
    List<ll.LatLng> full,
    double progress,
  ) async {
    final c = _controller;
    if (c == null) return;

    final route = state.optimizedRoute;
    final fractions = state.maneuverFractions;
    double? highlightFrac;
    if (route != null &&
        fractions.isNotEmpty &&
        fractions.length == route.maneuvers.length &&
        full.length >= 2) {
      final totalKm = DistanceUtils.pathLengthKm(full);
      if (totalKm > 0) {
        for (final f in fractions) {
          if (f <= progress) continue;
          final metersAhead = (f - progress) * totalKm * 1000;
          if (metersAhead <= NavigationConfig.maneuverHighlightWithinMeters) {
            highlightFrac = f;
          }
          break; // only ever the nearest upcoming maneuver
        }
        if (highlightFrac != null) {
          final len =
              NavigationConfig.maneuverHighlightLengthMeters / 1000 / totalKm;
          await c.setGeoJsonSource(
            _srcManeuver,
            MapGeometry.lineGeoJson(
              MapGeometry.subPath(full, highlightFrac, highlightFrac + len),
            ),
          );
          _maneuverHlVisible = true;
          return;
        }
      }
    }
    await _clearManeuverHighlight();
  }

  Future<void> _clearManeuverHighlight() async {
    if (!_maneuverHlVisible) return;
    _maneuverHlVisible = false;
    await _controller?.setGeoJsonSource(_srcManeuver, MapGeometry.emptyGeoJson);
  }

  /// Apply a solid rounded line paint to [layerId].
  Future<void> _setLine(String layerId, Color color, double width) async {
    final c = _controller;
    if (c == null) return;
    await c.setLayerProperties(
      layerId,
      LineLayerProperties(
        lineColor: color.a < 1.0
            ? MapGeometry.rgba(color)
            : MapGeometry.hex(color),
        lineWidth: width,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );
  }

  // ── Symbol management ───────────────────────────────────────────────────────

  /// Reconciles live symbols on the map with the desired state.
  /// Symbols are rendered as canvas PNG images registered with the map style,
  /// so they move perfectly in sync with map tiles — no overlay lag.
  Future<void> _syncSymbols(RoutePlannerState state) async {
    if (_disposed) return;
    final c = _controller;
    if (c == null || !_styleLoaded) return;

    try {
      // iOS loads images via UIImage(data:scale:UIScreen.main.scale), so the
      // logical pt size = pixelSize / dpr. Multiply iconSize by dpr to restore
      // the original logical size (e.g. 34px at 3× → 11pt × 3 = 34pt).
      final dpr = _dpr;

      final specs = await _buildSymbolSpecs(state);
      final specKeys = {for (final s in specs) s.key};

      // Remove symbols that are no longer in the desired set. The vehicle
      // is owned by the vsync ticker, so never reconcile it here.
      for (final key in _symbols.keys.toList()) {
        if (!specKeys.contains(key)) {
          await c.removeSymbol(_symbols.remove(key)!);
          _appliedSpecs.remove(key);
        }
      }

      // Only update changed stop badges. Vehicle motion uses its own
      // coalesced source and never queues behind these static symbols.
      for (final spec in specs) {
        final existing = _symbols[spec.key];
        if (existing != null) {
          if (_sameSpec(_appliedSpecs[spec.key], spec)) continue;
          await c.updateSymbol(existing, _optsFor(spec, dpr));
          _appliedSpecs[spec.key] = spec;
        } else {
          final data = spec.pointId != null ? {'pointId': spec.pointId!} : null;
          final sym = await c.addSymbol(_optsFor(spec, dpr), data);
          _symbols[spec.key] = sym;
          _appliedSpecs[spec.key] = spec;
        }
      }
    } catch (e, st) {
      debugPrint('[RouteMapView] _syncSymbols error: $e\n$st');
    }
  }

  SymbolOptions _optsFor(_SymbolSpec spec, double dpr) => SymbolOptions(
    geometry: LatLng(spec.position.latitude, spec.position.longitude),
    iconImage: spec.imageId,
    // The badge is rasterised oversampled and padded (see
    // MapMarkerRenderer._toPng), so the bitmap is bigger than the badge.
    // Dividing here lands it on screen at exactly the size it always was,
    // just with the pixels the screen actually has and room for its shadow.
    iconSize: dpr / VehicleMarkerConfig.badgeIconDivisor,
    iconAnchor: 'center',
  );

  /// True when [a] and [b] would render identically — lets us skip a
  /// redundant platform-channel `updateSymbol` call.
  bool _sameSpec(_SymbolSpec? a, _SymbolSpec b) {
    if (a == null) return false;
    return a.imageId == b.imageId &&
        a.position.latitude == b.position.latitude &&
        a.position.longitude == b.position.longitude;
  }

  Future<List<_SymbolSpec>> _buildSymbolSpecs(RoutePlannerState state) async {
    final specs = <_SymbolSpec>[];

    // ── User location ──────────────────────────────────────────────────────
    final userLoc = state.userLocation;
    if (userLoc != null && !state.navigationActive) {
      final imgId = await _ensureImage(
        'img-uloc',
        MapMarkerRenderer.userLocation,
      );
      specs.add(_SymbolSpec(key: 'usr-loc', imageId: imgId, position: userLoc));
    }

    // ── Route points (depot + stops) ───────────────────────────────────────
    // Simulation visit state is driven by the vehicle's TRUE arc-length
    // position (state.stopFractions) — not an even split — so a stop turns
    // "visited" the exact instant the car passes it (#1), instead of a beat
    // later. `visiting` is the next stop still ahead.
    final fractions = state.stopFractions;
    final simActive = state.simulationActive && fractions.isNotEmpty;
    final simProgress = state.simulationProgress;
    final simFinished = state.simulationActive && simProgress >= 1.0;

    // Playback visit states, worked out in one place and tested there —
    // see simVisitStates() for why this is an index and not a fraction.
    final simStates = simActive
        ? simVisitStates(
            fractions: fractions,
            // Counted from the route, not from state.points: points has the
            // terminal stripped, and the fraction list is only trustworthy
            // when it has exactly one entry per *ordered* point.
            orderedCount: state.optimizedRoute?.orderedPoints.length ?? 0,
            progress: simProgress,
            finished: simFinished,
            isStop: [
              for (final p in state.points) !p.isDepot && !p.isDeactivated,
            ],
          )
        : const <StopVisitState?>[];

    // Navigation visit state — navigationStopIndex is an index into
    // orderedPoints. Since state.points may differ (deactivated points,
    // stripped return depot), we build an id→orderedIndex map for
    // correct cross-referencing.
    int? orderedIndex(Map<String, int> map, String id) => map[id];
    final orderedIndexById = <String, int>{};
    if (state.navigationActive && state.optimizedRoute != null) {
      for (
        var idx = 0;
        idx < state.optimizedRoute!.orderedPoints.length;
        idx++
      ) {
        orderedIndexById[state.optimizedRoute!.orderedPoints[idx].id] = idx;
      }
    }
    final navTarget = state.navigationActive ? state.navigationStopIndex : null;
    final navFinished =
        state.navigationActive &&
        state.optimizedRoute != null &&
        state.navigationStopIndex >=
            state.optimizedRoute!.orderedPoints.length - 1;

    // A depot and one place to be: the marker is a pin, not the first entry
    // in a sequence the driver never asked for.
    final soleDestination = state.isSingleDestination;

    var stopIndex = 0;
    for (var i = 0; i < state.points.length; i++) {
      final p = state.points[i];

      // While repositioning a point (#9) its marker is hidden — the
      // centre reticle stands in for it.
      if (p.id == state.movingPointId) continue;

      // The auto departure is the user's current location — the live blue dot
      // already marks it, so don't draw a separate depot pin for it.
      if (p.isDepot && p.id.startsWith('depot_current')) continue;

      String imgId;
      if (p.isDepot) {
        imgId = await _ensureImage('img-depot', MapMarkerRenderer.depot);
      } else if (p.isDeactivated) {
        // Deactivated optional point: dimmed, unnumbered, no visit state.
        imgId = await _ensureImage(
          'img-opt-off',
          MapMarkerRenderer.optionalOff,
        );
      } else {
        // Mandatory stop or active optional point — numbered, with the
        // sim/drive visit state.
        StopVisitState? visit;
        if (simActive) {
          visit = i < simStates.length ? simStates[i] : null;
        } else if (navTarget != null) {
          final oi = orderedIndex(orderedIndexById, p.id);
          if (oi != null) {
            visit = navFinished || oi < navTarget
                ? StopVisitState.visited
                : oi == navTarget
                ? StopVisitState.visiting
                : StopVisitState.upcoming;
          }
        }
        final idx = ++stopIndex;
        final v = visit;
        final opt = p.optional;
        imgId = soleDestination && !opt
            ? await _ensureImage(
                'img-dest-${v?.name ?? 'n'}',
                () => MapMarkerRenderer.destination(v),
              )
            : await _ensureImage(
                'img-s$idx-${v?.name ?? 'n'}-${opt ? 'o' : 'm'}',
                () => MapMarkerRenderer.stop(idx, v, optional: opt),
              );
      }

      specs.add(
        _SymbolSpec(
          key: 'pt-${p.id}',
          imageId: imgId,
          position: p.latLng,
          pointId: p.id,
        ),
      );
    }

    // ── Where the day ends ─────────────────────────────────────────────────
    // A custom finish is not in state.points on purpose (it is a terminal,
    // not a delivery — see RouteFinish), so nothing above draws it. Without
    // this the driver picked a place and the map showed no sign of it.
    // Hidden while it is being placed: the centre reticle stands in, exactly
    // as it does for a point being repositioned.
    final finish = state.finish;
    final placingFinish =
        state.manualPlacement &&
        state.placementTarget == PlacementTarget.finish;
    if (finish.effectiveMode == RouteEndMode.custom && !placingFinish) {
      specs.add(
        _SymbolSpec(
          key: 'finish',
          imageId: await _ensureImage('img-finish', MapMarkerRenderer.finish),
          position: finish.location!,
        ),
      );
    }

    return specs;
  }

  /// Eased shortest-arc blend between angles (degrees), handling the
  /// 0°/360° wrap. Used to smooth the vehicle's heading frame to frame.
  double _blendAngle(double? prev, double next) {
    if (prev == null) return next;
    final delta = ((next - prev + 540) % 360) - 180;
    return (prev + delta * MapConfig.angleSmoothingFactor + 360) % 360;
  }

  /// Returns [id] after ensuring the image has been registered with the map.
  /// Cache key for the registered vehicle image, namespaced by the user's
  /// picked [VehicleKind] so switching it re-registers a fresh icon instead
  /// of reusing whatever was cached under a shared id.
  String get _vehicleImageId =>
      'img-vehicle-${VehiclePrefs.current.id}-${VehicleMarkerConfig.previewSize}';

  Future<String> _ensureImage(
    String id,
    Future<Uint8List> Function() render,
  ) async {
    if (!_registeredImages.contains(id)) {
      final c = _controller;
      if (c == null) return id;
      final bytes = await render();
      await c.addImage(id, bytes);
      _registeredImages.add(id);
    }
    return id;
  }

  // ── Pseudo-3D vehicle frames ────────────────────────────────────────────────

  /// Kicks off (or refreshes, after a Settings vehicle switch) the decode
  /// of the picked vehicle's nav sheet into [_navSheet]. Cheap no-op when
  /// already loaded for the current kind, so tick paths may call freely.
  void _ensureNavSheet() {
    final kind = VehiclePrefs.current;
    if (_navSheetKind == kind || _navSheetLoading) return;
    _navSheetLoading = true;
    unawaited(
      VehicleSprites.navOf(kind).then((sheet) {
        _navSheetLoading = false;
        _navSheetKind = kind;
        _navSheet = sheet;
        // The user may have switched again mid-decode.
        if (VehiclePrefs.current != kind) _ensureNavSheet();
      }),
    );
  }

  /// [_navSheet] only when it belongs to the currently picked vehicle —
  /// guards the one-frame window after a Settings switch where the old
  /// kind's sheet is still resident.
  ui.Image? get _currentNavSheet =>
      _navSheetKind == VehiclePrefs.current ? _navSheet : null;

  String _navFrameId(int h, int p, {required bool halo}) =>
      'img-nav3d${halo ? '-halo' : ''}-${VehiclePrefs.current.id}-'
      '${halo ? VehicleMarkerConfig.navigationSize : VehicleMarkerConfig.previewSize}-$h-$p';

  /// The registered image id for frame ([h], [p]) — or null when it isn't
  /// registered yet, in which case rendering + registration is kicked off
  /// fire-and-forget and the caller keeps its current frame this tick.
  /// Never awaits: safe inside the per-frame tick paths.
  String? _readyNavFrameId(int h, int p, {required bool halo}) {
    final id = _navFrameId(h, p, halo: halo);
    if (_registeredImages.contains(id)) return id;
    if (!_pendingFrameImages.contains(id)) {
      _pendingFrameImages.add(id);
      unawaited(
        _ensureImage(id, () => MapMarkerRenderer.navFrame(h, p, halo: halo))
            .catchError((Object error) {
              DebugLog.cam('vehicle heading image: $error');
              return id;
            })
            .whenComplete(() => _pendingFrameImages.remove(id)),
      );
    }
    return null;
  }

  /// Shortest-arc equivalent of [deg] in (−180, 180].
  double _wrap180(double deg) => ((deg + 540) % 360) - 180;

  // ── Symbol event handlers ───────────────────────────────────────────────────

  void _onSymbolTapped(Symbol sym) {
    final pointId = sym.data?['pointId'] as String?;
    if (pointId == null || !mounted) return;
    final state = context.read<RoutePlannerCubit>().state;
    // Stop markers stay visible while exploring mid-drive, but their edit
    // sheet belongs to planning — never open it over the drive HUD.
    if (state.navigationActive) return;
    try {
      final point = state.points.firstWhere((p) => p.id == pointId);
      showPointActions(context, point);
    } catch (_) {}
  }

  /// The style's own label layers, grouped once per style load. Empty
  /// until the style is up, and on any style that has no label layers —
  /// in which case tapping the map simply does nothing, as it did before.
  MapLabelLayers _labelLayers = MapLabelLayers.empty;

  Future<void> _cacheLabelLayers() async {
    final c = _controller;
    if (c == null) return;
    try {
      final ids = (await c.getLayerIds()).whereType<String>().toList();
      _labelLayers = MapLabelReader.groupLayers(ids);
      DebugLog.map(
        'label layers — poi=${_labelLayers.poi.length} '
        'place=${_labelLayers.place.length} other=${_labelLayers.other.length}',
      );
    } catch (e) {
      // A style that will not enumerate its layers costs us tap-to-add and
      // nothing else; everything on this map keeps working.
      DebugLog.map('getLayerIds failed: $e');
      _labelLayers = MapLabelLayers.empty;
    }
  }

  /// Tapping a name printed on the map opens it, the way every map app has
  /// trained every driver to expect.
  ///
  /// The answer comes out of the vector tile already on screen — the map
  /// drew that label, so it knows the name, the category and the exact
  /// coordinate — which makes this the only place lookup in the app that
  /// costs no request and works with no signal.
  ///
  /// [screenPoint] arrives in the same units the query expects on each
  /// platform (physical px on Android, logical on iOS), because both come
  /// from the native projection. Do not "fix" it with a devicePixelRatio —
  /// scaling here is the bug, not the cure. See `_aimScale` for the places
  /// that genuinely need it.
  Future<void> _onMapClick(
    math.Point<double> screenPoint,
    LatLng coordinates,
  ) async {
    if (!mounted) return;
    final c = _controller;
    if (c == null || _labelLayers.isEmpty) return;

    final state = context.read<RoutePlannerCubit>().state;
    // Every mode that has already claimed the tap keeps it: mid-drive the
    // map is for looking at, and while a pin is being aimed or moved the
    // next tap belongs to that flow.
    if (state.navigationActive ||
        state.simulationActive ||
        state.manualPlacement ||
        state.movingPointId != null) {
      return;
    }

    final tap = ll.LatLng(coordinates.latitude, coordinates.longitude);

    // A tap on one of our own stop markers belongs to the marker's sheet,
    // which `onSymbolTapped` is already opening. Both callbacks fire for
    // the same touch, so without this the driver gets two sheets.
    //
    // Measured on screen, not on the ground. Projecting each marker costs
    // a call per stop and is worth it: a metre-based radius means something
    // different at every zoom level, and at street zoom a generous one eats
    // every label within a block of a stop.
    final hitPad = MapConfig.markerTapRadiusPx * _aimScale;
    for (final p in state.points) {
      final marker = await c.toScreenLocation(_ml(p.latLng));
      if ((marker.x - screenPoint.x).abs() < hitPad &&
          (marker.y - screenPoint.y).abs() < hitPad) {
        return;
      }
    }
    if (!mounted) return;

    final place = await _queryLabelAt(screenPoint, tap);
    if (place == null || !mounted) return;

    HapticFeedback.selectionClick();
    await showMapPlaceSheet(context, context.read<RoutePlannerCubit>(), place);
  }

  /// Asks the three label tiers in turn and returns the first named hit.
  ///
  /// In order, because a finger covers a lot of map: a tap can land on a
  /// pharmacy, the street it is on and the city all at once, and the
  /// pharmacy is what was being pointed at.
  Future<PlaceSuggestion?> _queryLabelAt(
    math.Point<double> screenPoint,
    ll.LatLng tap,
  ) async {
    final c = _controller;
    if (c == null) return null;

    final tiers = <(List<String>, PlaceKind)>[
      (_labelLayers.poi, PlaceKind.poi),
      (_labelLayers.place, PlaceKind.city),
      (_labelLayers.other, PlaceKind.poi),
    ];

    // A box, not a point. The label is text a few pixels tall and the
    // touch is a fingertip; a point query only ever hits it by luck. The
    // *point* needs no DPR (see `_onMapClick`), but the box's size does —
    // it is a length in logical px being handed to an API that measures in
    // physical px on Android.
    final pad = MapConfig.labelTapRadiusPx * _aimScale;
    final box = Rect.fromLTRB(
      screenPoint.x - pad,
      screenPoint.y - pad,
      screenPoint.x + pad,
      screenPoint.y + pad,
    );

    for (final (layers, kind) in tiers) {
      if (layers.isEmpty) continue;
      try {
        final features = await c.queryRenderedFeaturesInRect(box, layers, null);
        final place = MapLabelReader.readBest(
          features,
          fallback: tap,
          tierKind: kind,
        );
        if (place != null) return place;
      } catch (e) {
        DebugLog.map('queryRenderedFeatures failed: $e');
        return null;
      }
    }
    return null;
  }

  void _onMapLongClick(math.Point<double> screenPoint, LatLng coordinates) {
    if (!mounted) return;
    final state = context.read<RoutePlannerCubit>().state;
    // Mid-drive the map is pannable (explore mode) — a long press must
    // never pop the remove-point dialog in the driver's face.
    if (state.navigationActive || state.simulationActive) return;
    final tapPos = ll.LatLng(coordinates.latitude, coordinates.longitude);

    RoutePoint? nearest;
    var nearestDist = double.infinity;
    for (final p in state.points) {
      final dist = DistanceUtils.haversineKm(tapPos, p.latLng);
      if (dist < nearestDist) {
        nearestDist = dist;
        nearest = p;
      }
    }
    if (nearest != null && nearestDist < MapConfig.removeTapRadiusKm) {
      HapticFeedback.mediumImpact();
      confirmRemovePoint(context, nearest.id);
    }
  }

  // ── Frame application (coalesced) ───────────────────────────────────────────

  /// Records the latest state and runs a single apply pipeline. If one is
  /// already running, the new state just replaces the pending one — so we
  /// always converge on the newest frame instead of replaying stale ones.
  void _scheduleApply(RoutePlannerState state) {
    final previous = _motionState;
    if (previous?.simulationActive != state.simulationActive ||
        previous?.simulationCameraMode != state.simulationCameraMode ||
        !identical(previous?.optimizedRoute, state.optimizedRoute)) {
      _previewTiltOverride = null;
      if (previous?.simulationActive == true && !state.simulationActive) {
        // Cancel an in-flight follow animation immediately, even if the
        // slower style/symbol apply pipeline is still handling an old tick.
        final camera = _controller?.cameraPosition;
        if (camera != null) {
          unawaited(
            _moveCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(target: camera.target, zoom: camera.zoom),
              ),
            ),
          );
        }
        _stopExploring(resumeCamera: false);
      }
    }
    _handleSimVehicle(state);
    _pendingApply = state;
    if (_applying) return;
    _applying = true;
    unawaited(_drainApply());
  }

  // ── Vehicle render loop ─────────────────────────────────────────────────────

  void _handleSimVehicle(RoutePlannerState state) {
    _motionState = state;
    final route = state.optimizedRoute;
    final shouldRun = state.simulationActive && route != null;
    if (shouldRun) {
      final changedRoute = !identical(_simRoute, route);
      _simRoute = route;
      _targetProgress = state.simulationProgress;
      if (!_simRunning ||
          changedRoute ||
          state.simulationProgress < _renderProgress) {
        _renderProgress = state.simulationProgress;
        _travelBearing = null;
      }
      _simRunning = true;
      _simMode = state.simulationCameraMode;
      final ticker = _vehicleTicker ??= createTicker(_onPreviewTick);
      if (!ticker.isActive) {
        _lastSimTick = Duration.zero;
        ticker.start();
      }
    } else {
      _simRunning = false;
      _vehicleTicker?.stop();
      _simRoute = null;
    }
    if (!state.navigationActive && !shouldRun) _clearMotionFrame();
  }

  void _onPreviewTick(Duration elapsed) {
    if (!_simRunning || _simRoute == null || !_styleLoaded) return;
    if (elapsed - _lastSimTick < SimulationConfig.tickInterval) return;
    _lastSimTick = elapsed;
    // The logical clock is already sampled at 30 Hz. A second easing clock
    // used to leave the car behind the growing line, especially at 8×.
    _renderProgress = _targetProgress;
    _publishMotionFrame(navigation: false);
  }

  void _clearMotionFrame() {
    if (!_motionVisible) return;
    _motionVisible = false;
    _lastMotionProgress = null;
    _motionWriter.submit(MapGeometry.emptyGeoJson);
  }

  /// Preload a visible fallback, then use baked heading frames when ready.
  /// The key includes dimensions so a hot-reloaded size cannot reuse old art.
  void _prepareMotionImage(bool navigation) {
    final key =
        '${VehiclePrefs.current.id}-$navigation-'
        '${navigation ? VehicleMarkerConfig.navigationSize : VehicleMarkerConfig.previewSize}';
    if (_motionImageKind == key || _loadingMotionImage) return;
    _loadingMotionImage = true;
    _ensureNavSheet();
    unawaited(() async {
      try {
        final id = navigation ? _navVehicleImageId : _vehicleImageId;
        await _ensureImage(
          id,
          navigation ? MapMarkerRenderer.navVehicle : MapMarkerRenderer.vehicle,
        );
        if (!mounted) return;
        _motionImageKind = key;
        _motionImage = id;
        _motionImageScale = _dpr / VehicleMarkerConfig.badgeIconDivisor;
        _motionHeadingFrame = null;
        _lastMotionProgress = null;
      } catch (error) {
        DebugLog.cam('vehicle image: $error');
      } finally {
        _loadingMotionImage = false;
      }
    }());
  }

  void _publishMotionFrame({required bool navigation}) {
    final state = _motionState;
    if (!_styleLoaded || state == null || _disposed) return;
    if (navigation ? !state.navigationActive : !_simRunning) return;
    final route = navigation ? _navRoute ?? state.optimizedRoute : _simRoute;
    final path = route?.fullPolyline ?? const <ll.LatLng>[];
    final progress = navigation ? _navRenderProgress : _renderProgress;
    _prepareMotionImage(navigation);
    final expectedKey =
        '${VehiclePrefs.current.id}-$navigation-'
        '${navigation ? VehicleMarkerConfig.navigationSize : VehicleMarkerConfig.previewSize}';
    if (_motionImage == null || _motionImageKind != expectedKey) return;
    final now = DateTime.now();
    if (now.difference(_lastMotionFrameAt).inMilliseconds < 33) return;
    final sample = PolylineUtils.sampleAt(path, progress);
    final anchor = sample?.point ?? (navigation ? state.userLocation : null);
    if (anchor == null) return;
    final tangent = sample?.bearing ?? state.navigationHeading ?? 0;
    // Relative to the actual native camera, not its future animated target.
    final rotation = _wrap180(tangent - _bearing.value);
    var image = _motionImage!;
    var scale = _motionImageScale;
    var iconRotation = rotation;
    if (_currentNavSheet != null) {
      final desired = VehicleNavSheet.headingIndex(rotation);
      if (_readyNavFrameId(desired, 0, halo: navigation) != null) {
        _motionHeadingFrame = desired;
      }
      final frame = _motionHeadingFrame;
      if (frame != null) {
        image = _navFrameId(frame, 0, halo: navigation);
        scale = _dpr / VehicleMarkerConfig.iconOversample;
        iconRotation = _wrap180(
          rotation - frame * VehicleMarkerConfig.headingStepDeg,
        );
      }
    }
    final stop = navigation ? state.navigationStopIndex : null;
    if (_motionVisible &&
        identical(route, _lastMotionRoute) &&
        progress == _lastMotionProgress &&
        rotation == _lastMotionBearing &&
        stop == _lastMotionStop &&
        image == _lastMotionImage &&
        anchor == _lastMotionAnchor) {
      return;
    }
    _lastMotionFrameAt = now;
    _lastMotionProgress = progress;
    _lastMotionBearing = rotation;
    _lastMotionStop = stop;
    _lastMotionRoute = route;
    _lastMotionImage = image;
    _lastMotionAnchor = anchor;
    _motionVisible = true;
    _motionWriter.submit(
      RouteMotionFrame.build(
        path: path,
        progress: progress,
        image: image,
        imageScale: scale,
        rotation: iconRotation,
        fallbackPosition: anchor,
        nextStop: navigation && route != null
            ? MapGeometry.nextStopFraction(
                route,
                state.navigationStopIndex,
                progress,
              )
            : null,
      ),
    );
  }

  Future<void> _drainApply() async {
    if (_disposed) return;
    try {
      while (_pendingApply != null) {
        if (_disposed) return;
        final s = _pendingApply!;
        _pendingApply = null;
        await _syncCamera(s);
        if (!_sameMapMode(s)) continue;
        await _syncPolylines(s);
        if (!_sameMapMode(s)) continue;
        await _syncSymbols(s);
        if (!_disposed &&
            _styleLoaded &&
            _sameMapMode(s) &&
            !s.simulationActive &&
            !s.navigationActive &&
            !s.isOptimizing) {
          widget.onRouteReady?.call(s.optimizedRoute);
        }
      }
    } finally {
      _applying = false;
    }
  }

  bool _sameMapMode(RoutePlannerState state) {
    final latest = _motionState;
    return latest != null &&
        state.simulationActive == latest.simulationActive &&
        state.navigationActive == latest.navigationActive &&
        state.simulationCameraMode == latest.simulationCameraMode &&
        identical(state.optimizedRoute, latest.optimizedRoute);
  }

  // ── Camera sync ─────────────────────────────────────────────────────────────

  Future<void> _syncCamera(RoutePlannerState state) async {
    if (_disposed) return;
    if (!_styleLoaded) return;

    // Aiming is a top-down act. The crosshair↔drop-point calibration is
    // measured flat and north-up (see [_calibrateAim], which refuses to
    // re-measure under an angle), so a tilted map would put the pin
    // somewhere other than where the driver aimed it. Flatten as they enter
    // the aiming flow rather than letting them find out afterwards.
    if (state.manualPlacement || state.movingPointId != null) {
      final tilt = _controller?.cameraPosition?.tilt ?? 0;
      if (tilt.abs() > 1) {
        // Remember it: dropping a pin should not quietly cost the driver the
        // 3D view they chose. Restored once the aiming flow ends.
        _tiltBeforeAiming = tilt;
        await _animateCamera(CameraUpdate.tiltTo(0));
      }
    } else if (_tiltBeforeAiming != null) {
      final restore = _tiltBeforeAiming!;
      _tiltBeforeAiming = null;
      await _animateCamera(CameraUpdate.tiltTo(restore));
    }

    // Moving a point (#9): centre on it once, then let the user pan it
    // under the reticle. Takes priority over the route-fit logic so the
    // post-optimize "move" case frames the point properly.
    if (state.movingPointId != null) {
      if (_centeredMoveId != state.movingPointId &&
          state.cameraTarget != null) {
        _centeredMoveId = state.movingPointId;
        final zoom = _controller?.cameraPosition?.zoom ?? MapConfig.focusedZoom;
        await _moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _ml(state.cameraTarget!),
              zoom: zoom < 15 ? MapConfig.movePointMinZoom : zoom,
            ),
          ),
        );
      }
      return;
    }
    _centeredMoveId = null;

    if (state.navigationActive && state.optimizedRoute != null) {
      if (!_wasNavigationActive) {
        _northLock = false;
        _navBearing = null;
        _drivingCamera.reset();
        _navCamSnapped = false;
        _navRoute = null;
        _navRenderProgress = state.navigationProgress;
        _stopExploring(resumeCamera: false);
      }
      _wasNavigationActive = true;
      await _syncNavigationCamera(state);
      return;
    }

    if (state.simulationActive && state.optimizedRoute != null) {
      await _syncSimulationCamera(state);
      return;
    }

    // Leaving drive / preview: flatten the 3D tilt and reset bearing so
    // planning always starts from a clean top-down north-up view.
    if (_wasNavigationActive) {
      _wasNavigationActive = false;
      _navBearing = null;
      _drivingCamera.reset();
      _navCamSnapped = false;
      _stopExploring(resumeCamera: false);
      _stopNavTicker();
      _navRoute = null;
      _navRouteTotalKm = 0.0;
      _navRenderProgress = 0.0;
      _stopExploring(resumeCamera: false);
      await _moveCamera(CameraUpdate.tiltTo(0));
      await _moveCamera(CameraUpdate.bearingTo(0));
    }
    if (_lastSimCameraMode != null) {
      await _moveCamera(CameraUpdate.tiltTo(0));
      await _moveCamera(CameraUpdate.bearingTo(0));
    }
    _hasFitOverviewBounds = false;
    _lastSimCameraMode = null;
    _northLock = false;
    _overviewAdjusted = false;
    _overviewCam = null;

    final route = state.optimizedRoute;
    if (route != null && route.fullPolyline.isNotEmpty) {
      if (!_hasFitOptimizedBounds) {
        _hasFitOptimizedBounds = true;
        await _fitPoints(
          route.fullPolyline,
          padding: MapConfig.optimizedFitPadding,
          maxZoom: MapConfig.fitMaxZoom,
        );
      }
      return;
    }

    _hasFitOptimizedBounds = false;

    final target = state.cameraTarget;
    if (target != null && target != _lastFocusedTarget) {
      _lastFocusedTarget = target;
      await _moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _ml(target), zoom: MapConfig.focusedZoom),
        ),
      );
    }
  }

  Future<void> _syncSimulationCamera(RoutePlannerState state) async {
    final route = state.optimizedRoute;
    if (route == null || route.fullPolyline.isEmpty || !_sameMapMode(state)) {
      return;
    }

    final mode = state.simulationCameraMode;
    if (_lastSimCameraMode != mode) {
      _hasFitOverviewBounds = false;
      _simCameraAnchored = false;
      _northLock = false;
      _overviewAdjusted = false;
      _lastSimCameraMode = mode;
      _stopExploring(resumeCamera: false);
    }

    if (mode == SimulationCameraMode.overview) {
      if (!_hasFitOverviewBounds) {
        _hasFitOverviewBounds = true;
        // Flatten out of any 3D tilt so the whole route reads cleanly.
        await _moveCamera(CameraUpdate.tiltTo(_previewTiltOverride ?? 0));
        if (!_sameMapMode(state)) return;
        await _moveCamera(CameraUpdate.bearingTo(0));
        if (!_sameMapMode(state)) return;
        // Frame *every* point + the road geometry so nothing sits off
        // screen (#1).
        await _fitPoints(
          _overviewFramePoints(route),
          padding: MapConfig.overviewFitPadding,
          maxZoom: MapConfig.fitMaxZoom,
        );
        if (!_sameMapMode(state)) return;
        // Remember the framed camera so we can tell when the user has
        // zoomed/panned away from the panorama.
        final cam = _controller?.cameraPosition;
        if (cam != null) {
          _overviewCam = ll.LatLng(cam.target.latitude, cam.target.longitude);
          _overviewZoom = cam.zoom;
        }
        _overviewAdjusted = false;
      }
      return;
    }

    if (_navExploring.value) return;

    // ── Follow / chase ──
    // Follow the same geographic progress used by the native motion frame.
    // First frame snaps into place; after that we *animate* toward each
    // 30 fps target so the map glides via native interpolation — no 60 fps
    // moveCamera spam (which janks on real devices).
    final sample = PolylineUtils.sampleAt(route.fullPolyline, _renderProgress);
    if (sample == null) return;

    final isChase = mode == SimulationCameraMode.chase;
    final headingUp = isChase && !_northLock;
    _travelBearing = _blendAngle(_travelBearing, sample.bearing);
    final travel = _travelBearing ?? sample.bearing;

    final firstFrame = !_simCameraAnchored;
    _simCameraAnchored = true;
    final zoom = firstFrame
        ? (isChase ? SimulationConfig.chaseZoom : SimulationConfig.followZoom)
        : (_controller?.cameraPosition?.zoom ??
              (isChase
                  ? SimulationConfig.chaseZoom
                  : SimulationConfig.followZoom));
    final update = CameraUpdate.newCameraPosition(
      CameraPosition(
        target: _ml(sample.point),
        zoom: zoom,
        bearing: headingUp ? travel : 0.0,
        tilt:
            _previewTiltOverride ??
            (headingUp ? SimulationConfig.chaseTilt : 0.0),
      ),
    );
    if (firstFrame) {
      await _moveCamera(update);
    } else {
      // Retarget the native animation at playback cadence. Waiting for its
      // completion creates a stop/start cycle, especially in tilted views.
      // Completion has no follow-up work, so an old animation cannot enqueue
      // a stale target after the user pans, changes mode or exits preview.
      unawaited(_easePreviewCamera(update));
    }
  }

  Future<void> _easePreviewCamera(CameraUpdate update) async {
    try {
      await _controller?.easeCamera(
        update,
        duration: MapConfig.followCamDuration,
        interpolation: CameraAnimationInterpolation.linear,
      );
    } catch (error) {
      DebugLog.cam('preview camera: $error');
    }
  }

  /// Drive-mode camera (#3): a tilted, heading-up 3D view that tracks the
  /// driver. The camera targets a point just ahead of the vehicle, so the
  /// current location sits in the lower-middle of the screen like a real
  /// navigation/chase view instead of being seen from an arbitrary angle.
  ///
  /// The first drive frame snaps into position; every later update *glides*
  /// there via a native camera animation spanning the GPS cadence, so the
  /// view moves continuously instead of jumping fix-to-fix. Zoom adapts to
  /// speed (close when crawling, wide on the highway) with its own easing.
  Future<void> _syncNavigationCamera(RoutePlannerState state) async {
    final loc = state.userLocation;
    if (loc == null) {
      DebugLog.cam('navCamera ✋ userLocation NULL → skip');
      return;
    }

    _hasFitOptimizedBounds = false;
    _hasFitOverviewBounds = false;
    _lastSimCameraMode = null;
    _northLock = false;

    // Retarget the vsync render loop (and absorb a reroute's new geometry
    // without moving the car) before any camera work.
    _syncNavRenderTargets(state);

    final pose = _drivingCamera.update(
      state.navigationSpeedMps,
      _cameraClock.elapsed,
    );
    final polyline = state.optimizedRoute?.fullPolyline ?? const <ll.LatLng>[];
    final tangent = PolylineUtils.sampleAt(
      polyline,
      state.navigationProgress,
    )?.bearing;
    // Orient by the road AHEAD of the car (anticipate the turn) so the
    // upcoming road keeps pointing up, instead of the tangent under the car
    // which only rotates once the car is already mid-bend. Off-route (no
    // geometry) we fall back to the live GPS heading.
    final aheadBearing = polyline.length >= 2
        ? PolylineUtils.lookAheadBearing(
            polyline,
            state.navigationProgress,
            pose.anticipation,
          )
        : null;
    final rawHeading =
        aheadBearing ?? state.navigationHeading ?? tangent ?? 0.0;
    _navBearing = _blendAngle(_navBearing, rawHeading);
    final heading = _navBearing ?? rawHeading;

    // Anchor the car to its position ON the route at the current progress
    // (snap-to-road) rather than the raw GPS fix. When a fix lands off-route
    // the cubit freezes progress, so the car holds its place on the line
    // instead of teleporting to a stray fix (bad GPS / a debug-step driver
    // racing a real GPS stream). Falls back to raw loc only if there's no
    // geometry yet.
    final onRoute = polyline.length >= 2
        ? PolylineUtils.interpolateByLength(polyline, state.navigationProgress)
        : null;
    final anchor = onRoute ?? loc;

    if (!_navTickerActive) {
      _publishMotionFrame(navigation: true);
    }
    if (_navExploring.value) return;

    // Keep zoom, pitch and forward offset in the same eased profile. A
    // fixed road offset at close zoom would push the vehicle off-screen.
    final zoom = pose.zoom;
    final lookahead = pose.lookaheadForViewport(
      MediaQuery.sizeOf(context).height,
    );
    final target = MapGeometry.destinationPoint(anchor, heading, lookahead);
    DebugLog.cam(
      'navCamera anchor=${anchor.latitude.toStringAsFixed(6)},'
      '${anchor.longitude.toStringAsFixed(6)} '
      'tangent=${tangent?.toStringAsFixed(1)} '
      'ahead=${aheadBearing?.toStringAsFixed(1)} '
      'stateHeading=${state.navigationHeading?.toStringAsFixed(1)} '
      '→ appliedHeading=${heading.toStringAsFixed(1)} '
      'prog=${state.navigationProgress.toStringAsFixed(4)} '
      'zoom=${zoom.toStringAsFixed(2)} tilt=${pose.tilt.toStringAsFixed(1)} '
      'lookahead=${lookahead.toStringAsFixed(1)}',
    );
    final update = CameraUpdate.newCameraPosition(
      CameraPosition(
        target: _ml(target),
        zoom: zoom,
        bearing: heading,
        tilt: pose.tilt,
      ),
    );
    if (!_navCamSnapped) {
      _navCamSnapped = true;
      await _moveCamera(update);
    } else {
      // Fire-and-forget: the native side interpolates position, bearing
      // and zoom over the animation window, so the apply pipeline never
      // stalls and motion stays continuous between GPS fixes.
      unawaited(
        _controller?.animateCamera(
              update,
              duration: NavigationConfig.cameraAnimDuration,
            ) ??
            Future<void>.value(),
      );
    }
  }

  // ── Nav vehicle render loop ─────────────────────────────────────────────────

  bool get _navTickerActive => _navTicker?.isActive ?? false;

  /// Feeds the render loop the newest cubit frame: the target progress,
  /// the dead-reckoning rate, and — when a reroute swapped the polyline —
  /// a rendered-progress rescale that keeps the car exactly where it is
  /// (the driven prefix is preserved verbatim, so fractions convert by
  /// arc length).
  void _syncNavRenderTargets(RoutePlannerState state) {
    final route = state.optimizedRoute;
    if (route == null || route.fullPolyline.length < 2) {
      _stopNavTicker();
      _navRoute = null;
      _navRouteTotalKm = 0.0;
      return;
    }
    if (!identical(route, _navRoute)) {
      final newTotalKm = DistanceUtils.pathLengthKm(route.fullPolyline);
      if (_navRoute != null && _navRouteTotalKm > 0 && newTotalKm > 0) {
        _navRenderProgress =
            (_navRenderProgress * _navRouteTotalKm / newTotalKm).clamp(
              0.0,
              1.0,
            );
      } else {
        _navRenderProgress = state.navigationProgress;
      }
      _navRoute = route;
      _navRouteTotalKm = newTotalKm;
    }
    // Compare logical fixes, not the extrapolated render position. A normal
    // GPS fix can trail our prediction without being a deliberate restart.
    if (state.navigationProgress < _navTargetProgress - 1e-6) {
      _navRenderProgress = state.navigationProgress;
    }
    _navTargetProgress = state.navigationProgress;
    _navTargetAt = DateTime.now();
    final routeMeters = _navRouteTotalKm * 1000;
    _navProgressRatePerSec = routeMeters > 0
        ? (state.navigationSpeedMps ?? 0.0) / routeMeters
        : 0.0;
    _startNavTicker();
  }

  void _startNavTicker() {
    final ticker = _navTicker ??= createTicker(_onNavTick);
    if (!ticker.isActive) {
      _navTickerLast = Duration.zero;
      ticker.start();
    }
  }

  void _stopNavTicker() {
    _navTicker?.stop();
    _navTickerLast = Duration.zero;
  }

  /// One display frame of vehicle motion: dead-reckon the last fix forward
  /// at the vehicle's speed, chase it with an exponential smoother
  /// (forward-only), then publish the vehicle and adjoining route lines
  /// together to the native map.
  void _onNavTick(Duration elapsed) {
    final dt = _navTickerLast == Duration.zero
        ? 1 / 60.0
        : ((elapsed - _navTickerLast).inMicroseconds / 1e6).clamp(0.001, 0.1);
    _navTickerLast = elapsed;

    final route = _navRoute;
    if (route == null || route.fullPolyline.length < 2) return;

    final sinceFix =
        (DateTime.now().difference(_navTargetAt).inMicroseconds / 1e6).clamp(
          0.0,
          NavigationConfig.markerMaxExtrapolationSeconds,
        );
    final predicted = math.min(
      _navTargetProgress + _navProgressRatePerSec * sinceFix,
      1.0,
    );

    final diff = predicted - _navRenderProgress;
    if (diff > 0) {
      final k = 1 - math.exp(-dt / NavigationConfig.markerSmoothingTauSeconds);
      _navRenderProgress = math.min(_navRenderProgress + diff * k, predicted);
    }

    _publishMotionFrame(navigation: true);
  }

  // ── Free exploration during drive mode ──────────────────────────────────────

  /// Touch pauses the follow camera, never the geographic vehicle.
  void _onNavPointerDown(int pointer) {
    if (!mounted) return;
    final state = context.read<RoutePlannerCubit>().state;
    if (!state.navigationActive &&
        !(state.simulationActive &&
            state.simulationCameraMode != SimulationCameraMode.overview)) {
      return;
    }
    _mapPointers.add(pointer);
    _exploreResumeTimer?.cancel();
    _navExploring.value = true;
  }

  void _onNavPointerUp(int pointer) {
    _mapPointers.remove(pointer);
    if (_mapPointers.isNotEmpty || !_navExploring.value || !mounted) return;
    // A paused preview stays where the user put it until Re-center.
    if (!context.read<RoutePlannerCubit>().state.navigationActive) return;
    _exploreResumeTimer?.cancel();
    _exploreResumeTimer = Timer(
      NavigationConfig.exploreResumeDelay,
      () => _stopExploring(resumeCamera: true),
    );
  }

  void _stopExploring({required bool resumeCamera}) {
    _exploreResumeTimer?.cancel();
    _exploreResumeTimer = null;
    _mapPointers.clear();
    if (!_navExploring.value) return;
    _navExploring.value = false;
    if (resumeCamera && mounted) {
      unawaited(_syncCamera(context.read<RoutePlannerCubit>().state));
    }
  }

  String get _navVehicleImageId =>
      'img-nav-vehicle-${VehiclePrefs.current.id}-${VehicleMarkerConfig.navigationSize}';

  /// All points worth keeping in frame for the overview: every ordered
  /// stop plus the full road geometry.
  List<ll.LatLng> _overviewFramePoints(OptimizedRoute route) => [
    ...route.orderedPoints.map((p) => p.latLng),
    ...route.fullPolyline,
  ];

  Future<void> _fitPoints(
    List<ll.LatLng> points, {
    required EdgeInsets padding,
    double? maxZoom,
  }) async {
    if (points.isEmpty) return;
    final b = DistanceUtils.boundsOf(points);
    final bounds = LatLngBounds(
      southwest: _ml(b.southWest),
      northeast: _ml(b.northEast),
    );
    await _animateCamera(
      CameraUpdate.newLatLngBounds(
        bounds,
        left: padding.left,
        top: padding.top,
        right: padding.right,
        bottom: padding.bottom,
      ),
    );
    if (maxZoom != null) {
      final zoom = _controller?.cameraPosition?.zoom;
      if (zoom != null && zoom > maxZoom) {
        await _moveCamera(CameraUpdate.zoomTo(maxZoom));
      }
    }
  }

  /// Puts the map back: north-up and flat.
  ///
  /// Both, not just the heading, because both are now things a driver can
  /// change by hand and this is the only control that undoes either. Mid-
  /// drive it means something different — hand the camera back to the
  /// navigation logic, which owns the tilt there.
  /// Tilts the planning map into 3D, or lays it flat again.
  ///
  /// Tilt has always been reachable by dragging two fingers, which nobody
  /// discovers. The style already carries 3D buildings, so this only had to
  /// be given a way in.
  Future<void> _toggleTilt() async {
    final state = context.read<RoutePlannerCubit>().state;
    final current =
        (state.simulationActive ? _previewTiltOverride : null) ??
        _controller?.cameraPosition?.tilt ??
        0;
    final target = current.abs() > 1 ? 0.0 : NavigationConfig.exploreTilt;
    if (state.simulationActive) {
      // Store the intent before animating. Every following playback tick
      // honors it, including a second tap before the first animation ends.
      _previewTiltOverride = target;
    }
    await _animateCamera(CameraUpdate.tiltTo(target));
  }

  void _resetViewAngle() {
    final state = context.read<RoutePlannerCubit>().state;
    if (state.navigationActive) {
      _northLock = false;
      unawaited(_syncNavigationCamera(state));
      return;
    }
    _northLock = true;
    if (state.simulationActive) {
      _previewTiltOverride = 0;
    }
    unawaited(_flattenView());
  }

  /// Animates the planning camera back to flat and north-up.
  ///
  /// Two updates rather than a `newCameraPosition`, so neither the centre
  /// nor the zoom is touched — the driver keeps looking at exactly what
  /// they were looking at, from above.
  Future<void> _flattenView() async {
    await _animateCamera(CameraUpdate.bearingTo(0));
    await _animateCamera(CameraUpdate.tiltTo(0));
  }

  /// Re-frame the whole route in panoramic mode after the user zoomed or
  /// panned away.
  void _resetOverview() {
    setState(() {
      _overviewAdjusted = false;
      _hasFitOverviewBounds = false; // forces _syncSimulationCamera to re-fit
    });
    unawaited(_syncCamera(context.read<RoutePlannerCubit>().state));
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocListener<RoutePlannerCubit, RoutePlannerState>(
      listenWhen: (a, b) =>
          a.previewRequestId != b.previewRequestId ||
          a.cameraTarget != b.cameraTarget ||
          a.optimizedRoute != b.optimizedRoute ||
          a.simulationActive != b.simulationActive ||
          a.simulationProgress != b.simulationProgress ||
          a.simulationCameraMode != b.simulationCameraMode ||
          a.navigationActive != b.navigationActive ||
          a.navigationProgress != b.navigationProgress ||
          a.navigationStopIndex != b.navigationStopIndex ||
          a.navigationHeading != b.navigationHeading ||
          a.navigationSpeedMps != b.navigationSpeedMps ||
          a.userLocation != b.userLocation ||
          a.points != b.points ||
          a.movingPointId != b.movingPointId ||
          // Entering the aim flow flattens the map — see [_syncCamera].
          a.manualPlacement != b.manualPlacement ||
          a.displaySegment != b.displaySegment,
      listener: (_, state) => _scheduleApply(state),
      child: Stack(
        children: [
          Positioned.fill(
            child: BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
              buildWhen: (a, b) =>
                  a.navigationActive != b.navigationActive ||
                  (!b.navigationActive && a.cameraTarget != b.cameraTarget),
              builder: (context, state) => _buildMapLibreMap(context, state),
            ),
          ),
          BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
            buildWhen: (a, b) => a.navigationActive != b.navigationActive,
            builder: (context, state) {
              if (state.navigationActive) return const SizedBox.shrink();
              // Sits just above the bottom sheet rather than halfway up the
              // map: these are map controls, and a driver reaches for them
              // with the same thumb that drags the sheet. The floor keeps
              // them clear of the preview scrubber and the single-destination
              // card, neither of which reports an extent; the ceiling stops
              // them climbing into the top bar when the sheet is dragged
              // fully open.
              final extent = SheetExtent.of(
                context,
              ).clamp(_mapChromeFloor, _mapChromeCeiling);
              return Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 14,
                    bottom:
                        MediaQuery.sizeOf(context).height * extent +
                        _mapChromeGap,
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MapCompass(
                          bearing: _bearing,
                          tilt: _tilt,
                          onTap: _resetViewAngle,
                        ),
                        const SizedBox(height: 10),
                        // Says what tapping will give you, not what you are
                        // looking at: flat map offers "3D", tilted offers "2D".
                        ValueListenableBuilder<double>(
                          valueListenable: _tilt,
                          builder: (context, tilt, _) {
                            final tilted = tilt.abs() > 1;
                            return MapActionButton(
                              label: tilted ? '2D' : '3D',
                              tooltip: tilted
                                  ? AppStrings.viewFlat
                                  : AppStrings.view3d,
                              onPressed: _toggleTilt,
                              iconColor: tilted ? AppColors.primary : null,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // "Return to my location" — appears on the right (mirroring the
          // compass) only while planning, once the user has panned away from
          // their current position. Rides above the sheet on the same rail as
          // the compass, so the pair stays level as the sheet moves.
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: EdgeInsets.only(
                right: 14,
                bottom:
                    MediaQuery.sizeOf(context).height *
                        SheetExtent.of(
                          context,
                        ).clamp(_mapChromeFloor, _mapChromeCeiling) +
                    _mapChromeGap,
              ),
              child: SafeArea(
                child: BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
                  buildWhen: (a, b) =>
                      a.simulationActive != b.simulationActive ||
                      a.navigationActive != b.navigationActive ||
                      a.movingPointId != b.movingPointId ||
                      a.optimizedRoute != b.optimizedRoute ||
                      (a.userLocation == null) != (b.userLocation == null),
                  builder: (context, state) {
                    final eligible =
                        !state.simulationActive &&
                        !state.navigationActive &&
                        state.movingPointId == null &&
                        !state.hasOptimizedRoute &&
                        state.userLocation != null;
                    return ValueListenableBuilder<bool>(
                      valueListenable: _showRecenter,
                      builder: (context, away, __) {
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: ScaleTransition(scale: anim, child: child),
                          ),
                          child: (eligible && away)
                              ? LocateFab(
                                  key: const ValueKey('locate'),
                                  onTap: _returnToUser,
                                )
                              : const SizedBox.shrink(),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
          // Reset-view / recenter control — a FAB tucked at the bottom-right,
          // clear of the top card and the bottom control bar.
          Positioned(
            right: 14,
            bottom: MediaQuery.paddingOf(context).bottom + 112,
            child: BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
              buildWhen: (a, b) =>
                  a.simulationActive != b.simulationActive ||
                  a.simulationCameraMode != b.simulationCameraMode,
              builder: (context, state) {
                // Only the panoramic view offers "reset view"; follow/chase
                // have their own exploration/recenter control below.
                final show =
                    state.simulationActive &&
                    state.simulationCameraMode ==
                        SimulationCameraMode.overview &&
                    _overviewAdjusted;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(scale: anim, child: child),
                  ),
                  child: show
                      ? RecenterButton(
                          key: const ValueKey('reset-view'),
                          icon: Icons.zoom_out_map_rounded,
                          label: AppStrings.resetView,
                          onTap: _resetOverview,
                        )
                      : const SizedBox.shrink(),
                );
              },
            ),
          ),
          // Drive-mode "Re-center": floats above the HUD's bottom panel
          // while the user is exploring the map mid-navigation. One tap
          // (or 3 s hands-off) returns to the follow camera.
          //
          // It rides higher once the driver has reached a stop, because the
          // HUD grows the arrival bar underneath it then. A control that
          // overlaps the button ending the leg is worse than one slightly
          // further from the thumb.
          Positioned.fill(
            child: BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
              buildWhen: (a, b) =>
                  a.navigationActive != b.navigationActive ||
                  a.navigationArrived != b.navigationArrived ||
                  a.simulationActive != b.simulationActive ||
                  a.simulationCameraMode != b.simulationCameraMode,
              builder: (context, state) {
                if (!state.navigationActive &&
                    !(state.simulationActive &&
                        state.simulationCameraMode !=
                            SimulationCameraMode.overview)) {
                  return const SizedBox.shrink();
                }
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: state.simulationActive
                          ? math.max(
                              MediaQuery.paddingOf(context).bottom + 112,
                              MediaQuery.sizeOf(context).height *
                                      SheetExtent.of(context) +
                                  12,
                            )
                          : MediaQuery.paddingOf(context).bottom +
                                (state.navigationArrived
                                    ? MapConfig.navRecenterLiftArrivedPx
                                    : MapConfig.navRecenterLiftPx),
                    ),
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _navExploring,
                      builder: (context, exploring, __) {
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: ScaleTransition(scale: anim, child: child),
                          ),
                          child: exploring
                              ? RecenterButton(
                                  key: const ValueKey('nav-recenter'),
                                  icon: Icons.navigation_rounded,
                                  label: AppStrings.reCenter,
                                  onTap: () =>
                                      _stopExploring(resumeCamera: true),
                                )
                              : const SizedBox.shrink(),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapLibreMap(BuildContext context, RoutePlannerState state) {
    final initialTarget =
        state.cameraTarget ??
        const ll.LatLng(MapConfig.fallbackLat, MapConfig.fallbackLon);
    // Pan/zoom stay live during navigation: touching the map hands the
    // camera to the user (explore mode) without interrupting guidance.
    // The Listener sees the raw pointers the map consumes as gestures.
    return Listener(
      onPointerDown: (event) => _onNavPointerDown(event.pointer),
      onPointerUp: (event) => _onNavPointerUp(event.pointer),
      onPointerCancel: (event) => _onNavPointerUp(event.pointer),
      behavior: HitTestBehavior.translucent,
      child: _buildMap(initialTarget),
    );
  }

  Widget _buildMap(ll.LatLng initialTarget) {
    const gesturesEnabled = true;

    return MapLibreMap(
      styleString: EnvConfig.mapStyleUrl,
      initialCameraPosition: CameraPosition(
        target: _ml(initialTarget),
        zoom: MapConfig.initialZoom,
      ),
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _onStyleLoaded,
      onCameraMove: _onCameraMove,
      onCameraIdle: _onCameraIdle,
      onMapClick: _onMapClick,
      onMapLongClick: _onMapLongClick,
      trackCameraPosition: true,
      compassEnabled: false,
      // Push the OpenStreetMap "i" attribution button off-screen so the map
      // corner stays clean (negative margins move it past the edge).
      attributionButtonMargins: const math.Point(-100, -100),
      rotateGesturesEnabled: false,
      scrollGesturesEnabled: gesturesEnabled,
      zoomGesturesEnabled: gesturesEnabled,
      // Two fingers dragged up or down tilt the planning map into a 3D
      // view, the same one drive mode uses.
      //
      // It was off on the reasoning that the viewing angle belongs to the
      // app camera and a manual angle would leak into the drive. It does
      // not: entering navigation sets its own tilt, and leaving flattens
      // back to zero. What the ban actually cost was a driver's ability to
      // look down a street they are planning around — and it left the
      // compass permanently invisible, since nothing could turn the map
      // off north either.
      //
      // Rotation stays off. Tilt answers "what does this street look like";
      // a map that has also quietly spun 40° answers nothing, and the two
      // ride on gestures close enough that a thumb aiming for one gets both.
      tiltGesturesEnabled: gesturesEnabled,
      myLocationEnabled: false,
      minMaxZoomPreference: const MinMaxZoomPreference(
        MapConfig.minZoom,
        MapConfig.maxZoom,
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static LatLng _ml(ll.LatLng p) => LatLng(p.latitude, p.longitude);
}
