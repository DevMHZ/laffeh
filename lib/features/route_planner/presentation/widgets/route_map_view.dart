import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/config/env_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../../../core/utils/marker_factory.dart';
import '../../../../core/utils/polyline_utils.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../domain/entities/optimized_route.dart';
import '../../domain/entities/route_point.dart';
import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';
import 'map_compass.dart';

/// How far above the viewport's geometric centre the aim reticle sits (logical
/// pixels). Raised so it clears the bottom sheet and sits in the driver's
/// natural line of sight. The crosshair widget and [mapCenter] both use this
/// so the dropped point always lands exactly under the reticle.
const double kMapAimRaise = 88;

/// Describes one symbol to be rendered on the map.
class _SymbolSpec {
  final String key;
  final String imageId;
  final ll.LatLng position;
  final double rotation;
  final String? pointId;

  const _SymbolSpec({
    required this.key,
    required this.imageId,
    required this.position,
    this.rotation = 0.0,
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
class RouteMapView extends StatefulWidget {
  const RouteMapView({super.key});

  @override
  State<RouteMapView> createState() => RouteMapViewState();
}

class RouteMapViewState extends State<RouteMapView> {
  MapLibreMapController? _controller;
  bool _styleLoaded = false;

  /// Compass bearing (degrees clockwise from north). Updated on every camera
  /// move so the compass widget can counter-rotate the needle in real time.
  final ValueNotifier<double> _bearing = ValueNotifier(0);

  /// The LatLng beneath the aim reticle — the viewport centre raised by
  /// [kMapAimRaise] so a dropped point lands exactly where the reticle points.
  ll.LatLng _mapCenter = const ll.LatLng(AppConfig.fallbackLat, AppConfig.fallbackLon);
  ll.LatLng get mapCenter => _mapCenter;

  // ── Camera tracking ────────────────────────────────────────────────────────
  bool _hasFitOptimizedBounds = false;
  bool _hasFitOverviewBounds = false;
  ll.LatLng? _lastFocusedTarget;
  SimulationCameraMode? _lastSimCameraMode;
  bool _wasNavigationActive = false;
  bool _simCameraAnchored = false;
  bool _northLock = false;
  bool _followDetached = false;

  // Set to true right before every programmatic camera move so that
  // _onCameraMove doesn't mistakenly set _followDetached.
  bool _isMovingCamera = false;

  // ── Native symbol overlay ──────────────────────────────────────────────────
  // Keyed by _SymbolSpec.key; tracks live symbols for add/update/remove.
  final Map<String, Symbol> _symbols = {};
  // Image IDs already registered with the map style via controller.addImage.
  final Set<String> _registeredImages = {};

  // ── GeoJSON source / layer IDs ─────────────────────────────────────────────
  static const _srcBg = 'poly-bg';
  static const _srcFg = 'poly-fg';
  static const _srcTrail = 'poly-trail';
  static const _lyrBg = 'lyr-bg';
  static const _lyrFg = 'lyr-fg';
  static const _lyrTrail = 'lyr-trail';

  static const Map<String, dynamic> _emptyGeoJson = {
    'type': 'FeatureCollection',
    'features': <dynamic>[],
  };

  @override
  void dispose() {
    _controller?.onSymbolTapped.remove(_onSymbolTapped);
    _bearing.dispose();
    super.dispose();
  }

  // ── Map lifecycle ───────────────────────────────────────────────────────────

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    controller.onSymbolTapped.add(_onSymbolTapped);
  }

  Future<void> _onStyleLoaded() async {
    _styleLoaded = true;
    await _initPolylineLayers();

    // Allow symbols to overlap each other and map text so all markers show.
    await _controller?.setSymbolIconAllowOverlap(true);
    await _controller?.setSymbolIconIgnorePlacement(true);

    if (!mounted) return;
    final state = context.read<RoutePlannerCubit>().state;
    unawaited(_syncCamera(state));
    unawaited(_syncPolylines(state));
    unawaited(_syncSymbols(state));
  }

  void _onCameraMove(CameraPosition position) {
    _bearing.value = position.bearing;
    if (_lastSimCameraMode != null && !_followDetached && !_isMovingCamera) {
      setState(() => _followDetached = true);
    }
  }

  void _onCameraIdle() {
    _updateMapCenter();
  }

  Future<void> _updateMapCenter() async {
    final c = _controller;
    if (c == null || !_styleLoaded || !mounted) return;
    final size = MediaQuery.sizeOf(context);
    try {
      final mlLatLng = await c.toLatLng(
        math.Point<num>(size.width / 2, size.height / 2 - kMapAimRaise),
      );
      _mapCenter = ll.LatLng(mlLatLng.latitude, mlLatLng.longitude);
    } catch (_) {}
  }

  // ── Programmatic camera wrappers ────────────────────────────────────────────

  Future<void> _moveCamera(CameraUpdate update) async {
    final c = _controller;
    if (c == null || !_styleLoaded) return;
    _isMovingCamera = true;
    try {
      await c.moveCamera(update);
      await Future.microtask(() {});
    } finally {
      _isMovingCamera = false;
    }
  }

  Future<void> _animateCamera(CameraUpdate update) async {
    final c = _controller;
    if (c == null || !_styleLoaded) return;
    _isMovingCamera = true;
    try {
      await c.animateCamera(update);
      await Future.delayed(const Duration(milliseconds: 200));
    } finally {
      _isMovingCamera = false;
    }
  }

  // ── Polyline layer management ───────────────────────────────────────────────

  Future<void> _initPolylineLayers() async {
    final c = _controller;
    if (c == null) return;

    await c.addGeoJsonSource(_srcBg, _emptyGeoJson);
    await c.addLineLayer(
      _srcBg,
      _lyrBg,
      const LineLayerProperties(
        lineColor: '#87978C',
        lineWidth: 4,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );

    await c.addGeoJsonSource(_srcFg, _emptyGeoJson);
    await c.addLineLayer(
      _srcFg,
      _lyrFg,
      const LineLayerProperties(
        lineColor: '#3E9148',
        lineWidth: 7,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );

    await c.addGeoJsonSource(_srcTrail, _emptyGeoJson);
    await c.addLineLayer(
      _srcTrail,
      _lyrTrail,
      const LineLayerProperties(
        lineColor: '#63B956',
        lineWidth: 8,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );
  }

  Future<void> _syncPolylines(RoutePlannerState state) async {
    final c = _controller;
    if (c == null || !_styleLoaded) return;

    final route = state.optimizedRoute;
    if (route == null) {
      await c.setGeoJsonSource(_srcBg, _emptyGeoJson);
      await c.setGeoJsonSource(_srcFg, _emptyGeoJson);
      await c.setGeoJsonSource(_srcTrail, _emptyGeoJson);
      return;
    }

    if (state.navigationActive) {
      final trail = _trailUpTo(route.fullPolyline, state.navigationProgress);
      final remaining = _trailFrom(route.fullPolyline, state.navigationProgress);
      // Full-route ghost so the entire planned path is always visible.
      await c.setGeoJsonSource(_srcBg, _lineGeoJson(route.fullPolyline));
      await c.setLayerProperties(
        _lyrBg,
        LineLayerProperties(
          lineColor: _rgba(AppColors.textMuted.withValues(alpha: 0.28)),
          lineWidth: 5,
          lineCap: 'round',
          lineJoin: 'round',
        ),
      );
      // Ahead: bright green — the route still to drive.
      await c.setGeoJsonSource(_srcFg, _lineGeoJson(remaining));
      await c.setLayerProperties(
        _lyrFg,
        LineLayerProperties(
          lineColor: _hex(AppColors.primary),
          lineWidth: 8,
          lineCap: 'round',
          lineJoin: 'round',
        ),
      );
      // Behind: muted trail drawn on top — the path already driven.
      await c.setGeoJsonSource(_srcTrail, _lineGeoJson(trail));
      await c.setLayerProperties(
        _lyrTrail,
        LineLayerProperties(
          lineColor: _rgba(AppColors.textMuted.withValues(alpha: 0.65)),
          lineWidth: 5,
          lineCap: 'round',
          lineJoin: 'round',
        ),
      );
      return;
    }

    if (state.simulationActive) {
      final trail = _trailUpTo(route.fullPolyline, state.simulationProgress);
      final remaining = _trailFrom(route.fullPolyline, state.simulationProgress);
      // Ghost of the full route — very faint so the active layers pop.
      await c.setGeoJsonSource(_srcBg, _lineGeoJson(route.fullPolyline));
      await c.setLayerProperties(
        _lyrBg,
        LineLayerProperties(
          lineColor: _rgba(AppColors.primary.withValues(alpha: 0.18)),
          lineWidth: 4,
          lineCap: 'round',
          lineJoin: 'round',
        ),
      );
      // Upcoming route — shows where the vehicle is heading.
      await c.setGeoJsonSource(_srcFg, _lineGeoJson(remaining));
      await c.setLayerProperties(
        _lyrFg,
        LineLayerProperties(
          lineColor: _rgba(AppColors.primary.withValues(alpha: 0.55)),
          lineWidth: 6,
          lineCap: 'round',
          lineJoin: 'round',
        ),
      );
      // Traveled trail — brightest, drawn on top.
      await c.setGeoJsonSource(_srcTrail, _lineGeoJson(trail));
      await c.setLayerProperties(
        _lyrTrail,
        LineLayerProperties(
          lineColor: _hex(AppColors.accent),
          lineWidth: 8,
          lineCap: 'round',
          lineJoin: 'round',
        ),
      );
      return;
    }

    // Planning mode
    final highlighted = switch (state.displaySegment) {
      RouteSegment.go => route.goPolyline,
      RouteSegment.returnLeg => route.returnPolyline,
      RouteSegment.full => route.fullPolyline,
    };
    final fgColor = switch (state.displaySegment) {
      RouteSegment.go => AppColors.routeGo,
      RouteSegment.returnLeg => AppColors.routeReturn,
      RouteSegment.full => AppColors.routeFull,
    };

    await c.setGeoJsonSource(_srcBg, _lineGeoJson(route.fullPolyline));
    await c.setLayerProperties(
      _lyrBg,
      LineLayerProperties(
        lineColor: _rgba(AppColors.textMuted.withValues(alpha: 0.55)),
        lineWidth: 4,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );
    await c.setGeoJsonSource(_srcFg, _lineGeoJson(highlighted));
    await c.setLayerProperties(
      _lyrFg,
      LineLayerProperties(
        lineColor: _hex(fgColor),
        lineWidth: 7,
        lineCap: 'round',
        lineJoin: 'round',
      ),
    );
    await c.setGeoJsonSource(_srcTrail, _emptyGeoJson);
  }

  // ── Symbol management ───────────────────────────────────────────────────────

  /// Reconciles live symbols on the map with the desired state.
  /// Symbols are rendered as canvas PNG images registered with the map style,
  /// so they move perfectly in sync with map tiles — no overlay lag.
  Future<void> _syncSymbols(RoutePlannerState state) async {
    final c = _controller;
    if (c == null || !_styleLoaded) return;

    try {
      // iOS loads images via UIImage(data:scale:UIScreen.main.scale), so the
      // logical pt size = pixelSize / dpr. Multiply iconSize by dpr to restore
      // the original logical size (e.g. 34px at 3× → 11pt × 3 = 34pt).
      final dpr = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

      final specs = await _buildSymbolSpecs(state);
      final specKeys = {for (final s in specs) s.key};

      // Remove symbols that are no longer in the desired set.
      for (final key in _symbols.keys.toList()) {
        if (!specKeys.contains(key)) {
          await c.removeSymbol(_symbols.remove(key)!);
        }
      }

      // Add or update each desired symbol.
      for (final spec in specs) {
        final opts = SymbolOptions(
          geometry: LatLng(spec.position.latitude, spec.position.longitude),
          iconImage: spec.imageId,
          iconSize: dpr,
          iconAnchor: 'center',
          iconRotate: spec.rotation,
        );
        if (_symbols.containsKey(spec.key)) {
          await c.updateSymbol(_symbols[spec.key]!, opts);
        } else {
          final data = spec.pointId != null ? {'pointId': spec.pointId!} : null;
          final sym = await c.addSymbol(opts, data);
          _symbols[spec.key] = sym;
        }
      }
    } catch (e, st) {
      debugPrint('[RouteMapView] _syncSymbols error: $e\n$st');
    }
  }

  Future<List<_SymbolSpec>> _buildSymbolSpecs(RoutePlannerState state) async {
    final specs = <_SymbolSpec>[];

    // ── User location ──────────────────────────────────────────────────────
    final userLoc = state.userLocation;
    if (userLoc != null) {
      final isNav = state.navigationActive;
      final imgId = isNav
          ? await _ensureImage('img-nveh', _renderNavVehicle)
          : await _ensureImage('img-uloc', _renderUserLocation);
      specs.add(_SymbolSpec(
        key: 'usr-loc',
        imageId: imgId,
        position: userLoc,
        rotation: isNav ? (state.navigationHeading ?? 0.0) : 0.0,
      ));
    }

    // ── Route points (depot + stops) ───────────────────────────────────────
    final simTarget = state.simulationActive && state.optimizedRoute != null
        ? _simTargetIndex(state.optimizedRoute!, state.simulationProgress)
        : null;
    final simFinished =
        state.simulationActive && state.simulationProgress >= 1.0;

    // Navigation visit state — navigationStopIndex is an index into
    // orderedPoints, which aligns with state.points (minus return depot).
    final navTarget =
        state.navigationActive ? state.navigationStopIndex : null;
    final navFinished = state.navigationActive &&
        state.optimizedRoute != null &&
        state.navigationStopIndex >=
            state.optimizedRoute!.orderedPoints.length - 1;

    var stopIndex = 0;
    for (var i = 0; i < state.points.length; i++) {
      final p = state.points[i];

      StopVisitState? visit;
      if (simTarget != null && !p.isDepot) {
        visit = simFinished || i < simTarget
            ? StopVisitState.visited
            : i == simTarget
                ? StopVisitState.visiting
                : StopVisitState.upcoming;
      } else if (navTarget != null && !p.isDepot) {
        visit = navFinished || i < navTarget
            ? StopVisitState.visited
            : i == navTarget
                ? StopVisitState.visiting
                : StopVisitState.upcoming;
      }

      String imgId;
      if (p.isDepot) {
        imgId = await _ensureImage('img-depot', _renderDepot);
      } else {
        final idx = ++stopIndex;
        final v = visit;
        imgId = await _ensureImage(
          'img-s$idx-${v?.name ?? 'n'}',
          () => _renderStop(idx, v),
        );
      }

      specs.add(_SymbolSpec(
        key: 'pt-${p.id}',
        imageId: imgId,
        position: p.latLng,
        pointId: p.id,
      ));
    }

    // ── Simulation vehicle ─────────────────────────────────────────────────
    if (state.simulationActive && state.optimizedRoute != null) {
      final sample = PolylineUtils.sampleAt(
        state.optimizedRoute!.fullPolyline,
        state.simulationProgress,
      );
      if (sample != null) {
        final imgId = await _ensureImage('img-vehicle', _renderVehicle);
        final bearing =
            state.simulationCameraMode == SimulationCameraMode.chase
                ? 0.0
                : sample.bearing;
        specs.add(_SymbolSpec(
          key: 'vehicle',
          imageId: imgId,
          position: sample.point,
          rotation: bearing,
        ));
      }
    }

    return specs;
  }

  /// Returns [id] after ensuring the image has been registered with the map.
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

  // ── Canvas image rendering ─────────────────────────────────────────────────

  static Future<Uint8List> _renderToPng(
    double w,
    double h,
    void Function(ui.Canvas, ui.Size) painter,
  ) async {
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec, Rect.fromLTWH(0, 0, w, h));
    painter(canvas, ui.Size(w, h));
    final pic = rec.endRecording();
    final img = await pic.toImage(w.round(), h.round());
    final bd = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return bd!.buffer.asUint8List();
  }

  /// Draws a filled circle with optional glow or drop-shadow and a white border.
  static void _paintDot(
    ui.Canvas c,
    ui.Size sz, {
    required Color fill,
    Color border = AppColors.white,
    required double r,
    Color? glow,
  }) {
    final center = Offset(sz.width / 2, sz.height / 2);
    if (glow != null) {
      c.drawCircle(
        center,
        r + 2,
        ui.Paint()
          ..color = glow.withValues(alpha: 0.55)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6),
      );
    } else {
      // Subtle drop-shadow
      c.drawCircle(
        Offset(sz.width / 2, sz.height / 2 + 1.5),
        r,
        ui.Paint()
          ..color = Colors.black.withValues(alpha: 0.22)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2.5),
      );
    }
    c.drawCircle(center, r, ui.Paint()..color = fill);
    c.drawCircle(
      center,
      r,
      ui.Paint()
        ..color = border
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
  }

  /// Paints text (or an icon glyph) centred in [sz].
  static void _paintGlyph(
    ui.Canvas c,
    ui.Size sz,
    String text, {
    required double fontSize,
    required Color color,
    String fontFamily = 'MaterialIcons',
    FontWeight fontWeight = FontWeight.normal,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          color: color,
          fontWeight: fontWeight,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      c,
      Offset(sz.width / 2 - tp.width / 2, sz.height / 2 - tp.height / 2),
    );
  }

  static Future<Uint8List> _renderDepot() => _renderToPng(34, 34, (c, sz) {
        _paintDot(c, sz, fill: AppColors.primary, r: 10);
        _paintGlyph(
          c,
          sz,
          String.fromCharCode(Icons.flag_rounded.codePoint),
          fontSize: 12,
          color: AppColors.white,
        );
      });

  static Future<Uint8List> _renderStop(int index, StopVisitState? visit) =>
      _renderToPng(34, 34, (c, sz) {
        switch (visit) {
          case null:
            _paintDot(c, sz, fill: AppColors.accent, r: 10);
            _paintGlyph(c, sz, '$index',
                fontSize: 11,
                color: AppColors.white,
                fontFamily: 'Almarai',
                fontWeight: FontWeight.w800);
          case StopVisitState.upcoming:
            _paintDot(c, sz,
                fill: AppColors.white, border: AppColors.primary, r: 10);
            _paintGlyph(c, sz, '$index',
                fontSize: 11,
                color: AppColors.primary,
                fontFamily: 'Almarai',
                fontWeight: FontWeight.w800);
          case StopVisitState.visiting:
            _paintDot(c, sz,
                fill: AppColors.pinOrange,
                r: 13,
                glow: AppColors.pinOrange);
            _paintGlyph(c, sz, '$index',
                fontSize: 11,
                color: AppColors.white,
                fontFamily: 'Almarai',
                fontWeight: FontWeight.w800);
          case StopVisitState.visited:
            _paintDot(c, sz, fill: AppColors.primary, r: 10);
            _paintGlyph(
              c,
              sz,
              String.fromCharCode(Icons.check_rounded.codePoint),
              fontSize: 13,
              color: AppColors.white,
            );
        }
      });

  static Future<Uint8List> _renderVehicle() =>
      _renderToPng(40, 40, (c, sz) => const TopViewCarPainter().paint(c, sz));

  static Future<Uint8List> _renderUserLocation() =>
      _renderToPng(32, 32, (c, sz) {
        final center = Offset(sz.width / 2, sz.height / 2);
        // Outer halo
        c.drawCircle(
            center, 11, ui.Paint()..color = AppColors.primary.withValues(alpha: 0.15));
        // Shadow
        c.drawCircle(
          Offset(center.dx, center.dy + 1),
          6,
          ui.Paint()
            ..color = Colors.black.withValues(alpha: 0.18)
            ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2),
        );
        // Inner dot
        c.drawCircle(center, 6, ui.Paint()..color = AppColors.primary);
        c.drawCircle(
          center,
          6,
          ui.Paint()
            ..color = AppColors.white
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      });

  static Future<Uint8List> _renderNavVehicle() =>
      _renderToPng(44, 44, (c, sz) {
        final center = Offset(sz.width / 2, sz.height / 2);
        // Outer semi-transparent halo
        c.drawCircle(
            center, 22, ui.Paint()..color = AppColors.primary.withValues(alpha: 0.13));
        // Shadow for inner circle
        c.drawCircle(
          Offset(center.dx, center.dy + 2.5),
          15,
          ui.Paint()
            ..color = Colors.black.withValues(alpha: 0.18)
            ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3.5),
        );
        // Inner circle
        c.drawCircle(center, 15, ui.Paint()..color = AppColors.primary);
        c.drawCircle(
          center,
          15,
          ui.Paint()
            ..color = AppColors.white
            ..style = ui.PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        // Navigation arrow glyph (points up; iconRotate handles heading)
        _paintGlyph(
          c,
          sz,
          String.fromCharCode(Icons.navigation_rounded.codePoint),
          fontSize: 17,
          color: AppColors.white,
        );
      });

  // ── Symbol event handlers ───────────────────────────────────────────────────

  void _onSymbolTapped(Symbol sym) {
    final pointId = sym.data?['pointId'] as String?;
    if (pointId == null || !mounted) return;
    final state = context.read<RoutePlannerCubit>().state;
    try {
      final point = state.points.firstWhere((p) => p.id == pointId);
      _showPointActions(context, point);
    } catch (_) {}
  }

  void _onMapLongClick(math.Point<double> screenPoint, LatLng coordinates) {
    if (!mounted) return;
    final tapPos = ll.LatLng(coordinates.latitude, coordinates.longitude);
    final state = context.read<RoutePlannerCubit>().state;

    RoutePoint? nearest;
    var nearestDist = double.infinity;
    for (final p in state.points) {
      final dist = DistanceUtils.haversineKm(tapPos, p.latLng);
      if (dist < nearestDist) {
        nearestDist = dist;
        nearest = p;
      }
    }
    if (nearest != null && nearestDist < 0.15) {
      HapticFeedback.mediumImpact();
      _confirmRemovePoint(context, nearest.id);
    }
  }

  // ── Camera sync ─────────────────────────────────────────────────────────────

  Future<void> _syncCamera(RoutePlannerState state) async {
    if (!_styleLoaded) return;

    if (state.navigationActive && state.optimizedRoute != null) {
      if (!_wasNavigationActive) _northLock = false;
      _wasNavigationActive = true;
      await _syncNavigationCamera(state);
      return;
    }

    if (state.simulationActive && state.optimizedRoute != null) {
      await _syncSimulationCamera(state);
      return;
    }

    if (_wasNavigationActive) {
      _wasNavigationActive = false;
      await _moveCamera(CameraUpdate.bearingTo(0));
    }
    if (_lastSimCameraMode != null) {
      await _moveCamera(CameraUpdate.bearingTo(0));
    }
    _hasFitOverviewBounds = false;
    _lastSimCameraMode = null;
    _northLock = false;
    _followDetached = false;

    final route = state.optimizedRoute;
    if (route != null && route.fullPolyline.isNotEmpty) {
      if (!_hasFitOptimizedBounds) {
        _hasFitOptimizedBounds = true;
        await _fitPoints(
          route.fullPolyline,
          padding: const EdgeInsets.fromLTRB(34, 76, 34, 230),
          maxZoom: 16,
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
          CameraPosition(target: _ml(target), zoom: AppConfig.focusedZoom),
        ),
      );
    }
  }

  Future<void> _syncSimulationCamera(RoutePlannerState state) async {
    final route = state.optimizedRoute;
    if (route == null || route.fullPolyline.isEmpty) return;

    final mode = state.simulationCameraMode;
    if (_lastSimCameraMode != mode) {
      _hasFitOverviewBounds = false;
      _simCameraAnchored = false;
      _northLock = false;
      _followDetached = false;
      _lastSimCameraMode = mode;
    }

    if (_followDetached) return;

    switch (mode) {
      case SimulationCameraMode.overview:
        if (!_hasFitOverviewBounds) {
          _hasFitOverviewBounds = true;
          await _moveCamera(CameraUpdate.bearingTo(0));
          await _fitPoints(
            route.fullPolyline,
            padding: const EdgeInsets.fromLTRB(34, 76, 34, 230),
            maxZoom: 16,
          );
        }
        return;

      case SimulationCameraMode.follow:
        final sample = PolylineUtils.sampleAt(
          route.fullPolyline,
          state.simulationProgress,
        );
        if (sample == null) return;
        if (!_simCameraAnchored) {
          _simCameraAnchored = true;
          await _moveCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                  target: _ml(sample.point), zoom: 14.0, bearing: 0),
            ),
          );
        } else {
          final zoom = _controller?.cameraPosition?.zoom ?? 14.0;
          await _moveCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: _ml(sample.point), zoom: zoom),
            ),
          );
        }
        return;

      case SimulationCameraMode.chase:
        final sample = PolylineUtils.sampleAt(
          route.fullPolyline,
          state.simulationProgress,
        );
        if (sample == null) return;
        final chaseRotation = _northLock ? 0.0 : sample.bearing;
        if (!_simCameraAnchored) {
          _simCameraAnchored = true;
          await _moveCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: _ml(sample.point),
                zoom: 15.2,
                bearing: chaseRotation,
              ),
            ),
          );
        } else {
          final zoom = _controller?.cameraPosition?.zoom ?? 15.2;
          await _moveCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: _ml(sample.point),
                zoom: zoom,
                bearing: chaseRotation,
              ),
            ),
          );
        }
        return;
    }
  }

  Future<void> _syncNavigationCamera(RoutePlannerState state) async {
    final loc = state.userLocation;
    if (loc == null) return;

    _hasFitOptimizedBounds = false;
    _hasFitOverviewBounds = false;
    _lastSimCameraMode = null;

    final heading = _northLock ? 0.0 : (state.navigationHeading ?? 0.0);
    await _moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _ml(loc), zoom: 16.2, bearing: heading),
      ),
    );
  }

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

  void _holdNorth() {
    _northLock = true;
    unawaited(_animateCamera(CameraUpdate.bearingTo(0)));
  }

  void _recenterOnVehicle() {
    setState(() {
      _followDetached = false;
      _simCameraAnchored = false;
    });
    unawaited(_syncCamera(context.read<RoutePlannerCubit>().state));
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocListener<RoutePlannerCubit, RoutePlannerState>(
      listenWhen: (a, b) =>
          a.cameraTarget != b.cameraTarget ||
          a.optimizedRoute != b.optimizedRoute ||
          a.simulationActive != b.simulationActive ||
          a.simulationProgress != b.simulationProgress ||
          a.simulationCameraMode != b.simulationCameraMode ||
          a.navigationActive != b.navigationActive ||
          a.navigationProgress != b.navigationProgress ||
          a.navigationStopIndex != b.navigationStopIndex ||
          a.navigationHeading != b.navigationHeading ||
          a.userLocation != b.userLocation ||
          a.points != b.points ||
          a.displaySegment != b.displaySegment,
      listener: (_, state) {
        unawaited(_syncCamera(state));
        unawaited(_syncPolylines(state));
        unawaited(_syncSymbols(state));
      },
      child: Stack(
        children: [
          Positioned.fill(child: _buildMapLibreMap(context)),
          Align(
            alignment: const Alignment(-1, -0.15),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 14),
                child: MapCompass(
                  bearing: _bearing,
                  onTap: _holdNorth,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom + 96,
            child: BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
              buildWhen: (a, b) => a.simulationActive != b.simulationActive,
              builder: (context, state) {
                final show = state.simulationActive && _followDetached;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: show
                      ? Center(
                          key: const ValueKey('recenter'),
                          child: _RecenterButton(onTap: _recenterOnVehicle),
                        )
                      : const SizedBox.shrink(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapLibreMap(BuildContext context) {
    final state = context.read<RoutePlannerCubit>().state;
    final initialTarget =
        state.cameraTarget ?? const ll.LatLng(AppConfig.fallbackLat, AppConfig.fallbackLon);

    return MapLibreMap(
      styleString: EnvConfig.mapStyleUrl,
      initialCameraPosition: CameraPosition(
        target: _ml(initialTarget),
        zoom: AppConfig.initialZoom,
      ),
      onMapCreated: _onMapCreated,
      onStyleLoadedCallback: _onStyleLoaded,
      onCameraMove: _onCameraMove,
      onCameraIdle: _onCameraIdle,
      onMapLongClick: _onMapLongClick,
      trackCameraPosition: true,
      compassEnabled: false,
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      tiltGesturesEnabled: false,
      myLocationEnabled: false,
      minMaxZoomPreference: const MinMaxZoomPreference(3, 19),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static LatLng _ml(ll.LatLng p) => LatLng(p.latitude, p.longitude);

  static String _hex(Color c) {
    final r = (c.r * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  static String _rgba(Color c) {
    final r = (c.r * 255).round().clamp(0, 255);
    final g = (c.g * 255).round().clamp(0, 255);
    final b = (c.b * 255).round().clamp(0, 255);
    return 'rgba($r,$g,$b,${c.a.toStringAsFixed(3)})';
  }

  static Map<String, dynamic> _lineGeoJson(List<ll.LatLng> pts) {
    if (pts.isEmpty) return _emptyGeoJson;
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': pts.map((p) => [p.longitude, p.latitude]).toList(),
          },
          'properties': <String, dynamic>{},
        },
      ],
    };
  }

  int _simTargetIndex(OptimizedRoute route, double progress) {
    final count = route.orderedPoints.length;
    if (count < 2) return 0;
    final segments = count - 1;
    return ((progress * segments).floor() + 1).clamp(1, count - 1);
  }

  List<ll.LatLng> _trailUpTo(List<ll.LatLng> path, double t) {
    if (path.length < 2 || t <= 0) return const [];
    final total = DistanceUtils.pathLengthKm(path);
    if (total <= 0) return const [];
    final target = total * t.clamp(0.0, 1.0);

    final out = <ll.LatLng>[path.first];
    double traveled = 0;
    for (var i = 0; i < path.length - 1; i++) {
      final segLen = DistanceUtils.haversineKm(path[i], path[i + 1]);
      if (traveled + segLen >= target) {
        final remaining = target - traveled;
        final f = segLen == 0 ? 0.0 : (remaining / segLen);
        out.add(
          ll.LatLng(
            path[i].latitude + (path[i + 1].latitude - path[i].latitude) * f,
            path[i].longitude + (path[i + 1].longitude - path[i].longitude) * f,
          ),
        );
        return out;
      }
      traveled += segLen;
      out.add(path[i + 1]);
    }
    return out;
  }

  List<ll.LatLng> _trailFrom(List<ll.LatLng> path, double t) {
    if (path.length < 2) return path;
    final start = PolylineUtils.interpolateByLength(path, t);
    if (start == null) return path;

    final total = DistanceUtils.pathLengthKm(path);
    if (total <= 0) return path;
    final target = total * t.clamp(0.0, 1.0);

    final out = <ll.LatLng>[start];
    double traveled = 0;
    for (var i = 0; i < path.length - 1; i++) {
      final segLen = DistanceUtils.haversineKm(path[i], path[i + 1]);
      if (traveled + segLen >= target) {
        out.addAll(path.skip(i + 1));
        return out;
      }
      traveled += segLen;
    }
    return [path.last];
  }

  // ── Point-action modals ─────────────────────────────────────────────────────

  void _showPointActions(BuildContext context, RoutePoint p) {
    final cubit = context.read<RoutePlannerCubit>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _PointActionsSheet(
        point: p,
        onRename: () async {
          Navigator.pop(sheetCtx);
          final newLabel = await AppDialog.input(
            context: context,
            title: AppStrings.rename,
            hint: AppStrings.rename,
            initialValue: p.label,
            icon: Iconsax.edit,
            tone: AppDialogTone.primary,
          );
          if (newLabel != null && newLabel.trim().isNotEmpty) {
            cubit.renamePoint(p.id, newLabel.trim());
          }
        },
        onSetDeparture: p.isDepot
            ? null
            : () {
                Navigator.pop(sheetCtx);
                cubit.setAsDeparture(p.id);
              },
        onRemove: () {
          Navigator.pop(sheetCtx);
          _confirmRemovePoint(context, p.id);
        },
      ),
    );
  }

  void _confirmRemovePoint(BuildContext context, String pointId) {
    final cubit = context.read<RoutePlannerCubit>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(22, 24, 22, 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.trash, color: AppColors.danger, size: 26),
            ),
            const SizedBox(height: 14),
            Text(
              AppStrings.removePointTitle,
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(AppStrings.cancel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      cubit.removePoint(pointId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(AppStrings.remove),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Point actions sheet ─────────────────────────────────────────────────────

class _PointActionsSheet extends StatelessWidget {
  final RoutePoint point;
  final VoidCallback onRename;
  final VoidCallback? onSetDeparture;
  final VoidCallback onRemove;

  const _PointActionsSheet({
    required this.point,
    required this.onRename,
    required this.onSetDeparture,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final accent = point.isDepot ? AppColors.primary : AppColors.accent;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 30,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      point.isDepot ? Iconsax.flag : Iconsax.location,
                      color: accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          point.label,
                          style: AppTextStyles.titleMd,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (point.address?.isNotEmpty == true) ...[
                          const SizedBox(height: 2),
                          Text(
                            point.address!,
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.divider),
            _ActionRow(
              icon: Iconsax.edit,
              label: AppStrings.rename,
              color: AppColors.primary,
              onTap: onRename,
            ),
            if (onSetDeparture != null)
              _ActionRow(
                icon: Iconsax.flag,
                label: AppStrings.setAsDeparture,
                color: AppColors.accent,
                onTap: onSetDeparture!,
              ),
            _ActionRow(
              icon: Iconsax.trash,
              label: AppStrings.remove,
              color: AppColors.danger,
              destructive: true,
              onTap: onRemove,
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool destructive;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(width: 14),
            Text(
              label,
              style: AppTextStyles.bodyLg.copyWith(
                color: destructive ? AppColors.danger : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecenterButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RecenterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.85),
              width: 1.4,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Iconsax.gps, color: AppColors.white, size: 18),
              const SizedBox(width: 7),
              Text(
                AppStrings.recenter,
                style: AppTextStyles.titleSm.copyWith(color: AppColors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
