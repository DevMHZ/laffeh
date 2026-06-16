import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:iconsax/iconsax.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

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

/// How far above the viewport's geometric centre the aim reticle sits, in
/// logical pixels. Raised so it clears the bottom sheet and sits in the
/// driver's natural line of sight. The crosshair widget and [mapCenter] both
/// use this so the dropped point always lands exactly under the reticle.
const double kMapAimRaise = 88;

/// Map-event sources that mean *the user* moved the map (pan / pinch / rotate /
/// fling / wheel) — as opposed to our own programmatic camera moves. Used to
/// detach the simulation camera from following the vehicle.
const Set<MapEventSource> _kUserMoveSources = {
  MapEventSource.dragStart,
  MapEventSource.onDrag,
  MapEventSource.dragEnd,
  MapEventSource.multiFingerGestureStart,
  MapEventSource.onMultiFinger,
  MapEventSource.multiFingerEnd,
  MapEventSource.flingAnimationController,
  MapEventSource.doubleTapHold,
  MapEventSource.doubleTapZoomAnimationController,
  MapEventSource.scrollWheel,
  MapEventSource.cursorKeyboardRotation,
};

/// OSM-backed map surface. Renders user-picked points, the optimized
/// polyline, and an animated vehicle marker during playback.
///
/// Uses a pin-to-center interaction: a fixed pin sits in the centre of
/// the viewport; the user pans the map to position it, then confirms
/// with the floating "+" button.
class RouteMapView extends StatefulWidget {
  const RouteMapView({super.key});

  @override
  State<RouteMapView> createState() => RouteMapViewState();
}

class RouteMapViewState extends State<RouteMapView> {
  final MapController _controller = MapController();

  bool _mapReady = false;
  bool _hasFitOptimizedBounds = false;
  bool _hasFitOverviewBounds = false;
  LatLng? _lastFocusedTarget;
  SimulationCameraMode? _lastSimCameraMode;
  bool _wasNavigationActive = false;

  /// Whether a follow/chase mode has done its one-time "anchor" move (the
  /// initial zoom/rotation). After that the camera only re-centres on the
  /// vehicle and keeps whatever zoom (and, in follow, rotation) the user has
  /// pinched/rotated to — so they can zoom and turn the map mid-playback.
  bool _simCameraAnchored = false;

  /// Set by the compass: force north-up in the auto-rotating modes (navigation
  /// / chase) instead of following the heading. Cleared whenever the context
  /// changes (mode switch, navigation start, or back to planning).
  bool _northLock = false;

  /// True once the user has panned/zoomed/rotated the map during simulation:
  /// the camera stops following the vehicle until they tap "Recenter" (or the
  /// simulation context changes). Lets them freely explore the route mid-play.
  bool _followDetached = false;

  StreamSubscription<MapEvent>? _eventSub;

  @override
  void initState() {
    super.initState();
    // Detach the follow-camera as soon as the user moves the map themselves
    // (only while simulating — _lastSimCameraMode is non-null there).
    _eventSub = _controller.mapEventStream.listen((e) {
      if (_lastSimCameraMode == null || _followDetached) return;
      if (_kUserMoveSources.contains(e.source)) {
        setState(() => _followDetached = true);
      }
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  /// Re-attach the camera to the vehicle and snap back to the mode's default
  /// framing immediately (covers the paused case where no tick would fire).
  void _recenterOnVehicle() {
    setState(() {
      _followDetached = false;
      _simCameraAnchored = false;
    });
    _syncCamera(context.read<RoutePlannerCubit>().state);
  }

  /// Expose the map controller so the parent can read the map center.
  MapController get mapController => _controller;

  /// The LatLng beneath the aim reticle — the viewport centre raised by
  /// [kMapAimRaise] so a dropped point lands exactly where the reticle points.
  /// Falls back to the plain camera centre before the map has been laid out.
  LatLng get mapCenter {
    final cam = _controller.camera;
    final s = cam.nonRotatedSize;
    if (!s.isFinite || s.isEmpty) return cam.center;
    return cam.screenOffsetToLatLng(
      Offset(s.width / 2, s.height / 2 - kMapAimRaise),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: _buildMap(context)),
        // Compass on the left — appears when the map is turned off north, taps
        // back to north-up. Centre-left keeps it clear of the top/bottom
        // overlays in every mode (planning, simulation, navigation).
        Align(
          alignment: const Alignment(-1, -0.15),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 14),
              child: MapCompass(
                controller: _controller,
                onResetNorth: _holdNorth,
              ),
            ),
          ),
        ),
        // "Recenter" — appears during simulation once the user has panned the
        // map away from the vehicle; taps to resume following.
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
    );
  }

  /// Hold north-up even in the auto-rotating modes (navigation / chase) until
  /// the context changes. Harmless in the manual modes, which don't read it.
  void _holdNorth() => _northLock = true;

  Widget _buildMap(BuildContext context) {
    return BlocConsumer<RoutePlannerCubit, RoutePlannerState>(
      listenWhen: (a, b) =>
          a.cameraTarget != b.cameraTarget ||
          a.optimizedRoute != b.optimizedRoute ||
          a.simulationActive != b.simulationActive ||
          a.simulationProgress != b.simulationProgress ||
          a.simulationCameraMode != b.simulationCameraMode ||
          a.navigationActive != b.navigationActive ||
          a.navigationProgress != b.navigationProgress ||
          a.navigationHeading != b.navigationHeading ||
          a.userLocation != b.userLocation,
      listener: (_, state) => _syncCamera(state),
      buildWhen: (a, b) =>
          a.points != b.points ||
          a.userLocation != b.userLocation ||
          a.optimizedRoute != b.optimizedRoute ||
          a.displaySegment != b.displaySegment ||
          a.cameraTarget != b.cameraTarget ||
          a.simulationActive != b.simulationActive ||
          a.simulationProgress != b.simulationProgress ||
          a.simulationCameraMode != b.simulationCameraMode ||
          a.navigationActive != b.navigationActive ||
          a.navigationProgress != b.navigationProgress ||
          a.navigationHeading != b.navigationHeading,
      builder: (context, state) {
        final target =
            state.cameraTarget ??
            const LatLng(AppConfig.fallbackLat, AppConfig.fallbackLon);

        return FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: target,
            initialZoom: AppConfig.initialZoom,
            minZoom: 3,
            maxZoom: 19,
            onMapReady: () {
              _mapReady = true;
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _syncCamera(state),
              );
            },
          ),
          children: [
            TileLayer(
              urlTemplate: EnvConfig.tileUrlTemplate,
              userAgentPackageName: 'com.example.laffeh',
              maxNativeZoom: 22,
            ),
            PolylineLayer(polylines: _buildPolylines(state)),
            MarkerLayer(markers: _buildMarkers(state)),
            RichAttributionWidget(
              showFlutterMapAttribution: false,
              attributions: [
                TextSourceAttribution(
                  EnvConfig.mapboxAccessToken.isNotEmpty
                      ? '© Mapbox, © OpenStreetMap'
                      : '© CARTO, © OpenStreetMap',
                  onTap: _openOsmCopyright,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _syncCamera(RoutePlannerState state) {
    if (!_mapReady) return;

    if (state.navigationActive && state.optimizedRoute != null) {
      if (!_wasNavigationActive) _northLock = false; // fresh drive session
      _wasNavigationActive = true;
      _syncNavigationCamera(state);
      return;
    }

    if (state.simulationActive && state.optimizedRoute != null) {
      _syncSimulationCamera(state);
      return;
    }

    if (_wasNavigationActive) {
      _wasNavigationActive = false;
      _controller.rotate(0);
    }
    if (_lastSimCameraMode != null) {
      _controller.rotate(0);
    }
    _hasFitOverviewBounds = false;
    _lastSimCameraMode = null;
    _northLock = false;
    _followDetached = false;

    final route = state.optimizedRoute;
    if (route != null && route.fullPolyline.isNotEmpty) {
      if (!_hasFitOptimizedBounds) {
        _hasFitOptimizedBounds = true;
        _fitPoints(
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
      _controller.move(target, AppConfig.focusedZoom);
    }
  }

  void _syncSimulationCamera(RoutePlannerState state) {
    final route = state.optimizedRoute;
    if (route == null || route.fullPolyline.isEmpty) return;

    final mode = state.simulationCameraMode;
    if (_lastSimCameraMode != mode) {
      _hasFitOverviewBounds = false;
      _simCameraAnchored = false;
      _northLock = false; // each mode starts at its own default orientation
      _followDetached = false; // re-attach when the user picks a mode
      _lastSimCameraMode = mode;
    }

    // The user took the wheel — leave the camera wherever they put it.
    if (_followDetached) return;

    switch (mode) {
      case SimulationCameraMode.overview:
        if (!_hasFitOverviewBounds) {
          _hasFitOverviewBounds = true;
          _controller.rotate(0);
          _fitPoints(
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
          // First frame of this mode: anchor north-up at a sensible zoom.
          _simCameraAnchored = true;
          _controller.moveAndRotate(sample.point, 14.0, 0);
        } else {
          // Keep the vehicle centred but honour the user's pinch-zoom and
          // rotation (move() leaves zoom/rotation as the user set them).
          _controller.move(sample.point, _controller.camera.zoom);
        }
        return;

      case SimulationCameraMode.chase:
        final sample = PolylineUtils.sampleAt(
          route.fullPolyline,
          state.simulationProgress,
        );
        if (sample == null) return;
        // Compass override holds north; otherwise the map turns to the heading.
        final chaseRotation = _northLock ? 0.0 : sample.bearing;
        if (!_simCameraAnchored) {
          _simCameraAnchored = true;
          _controller.moveAndRotate(sample.point, 15.2, chaseRotation);
        } else {
          // Chase keeps the map turned to the driving direction, but the
          // user's zoom is preserved so they can zoom in/out mid-playback.
          _controller.moveAndRotate(
            sample.point,
            _controller.camera.zoom,
            chaseRotation,
          );
        }
        return;
    }
  }

  void _syncNavigationCamera(RoutePlannerState state) {
    final loc = state.userLocation;
    if (loc == null) return;

    _hasFitOptimizedBounds = false;
    _hasFitOverviewBounds = false;
    _lastSimCameraMode = null;

    // Compass override holds north; otherwise the map turns to the heading.
    final heading = _northLock ? 0.0 : (state.navigationHeading ?? 0.0);
    _controller.moveAndRotate(loc, 16.2, heading);
  }

  void _fitPoints(
    List<LatLng> points, {
    required EdgeInsets padding,
    double? maxZoom,
  }) {
    if (points.isEmpty) return;
    final bounds = DistanceUtils.boundsOf(points);
    _controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(bounds.corners),
        padding: padding,
        maxZoom: maxZoom,
      ),
    );
  }

  List<Marker> _buildMarkers(RoutePlannerState state) {
    final markers = <Marker>[];

    final userLocation = state.userLocation;
    if (userLocation != null) {
      markers.add(
        Marker(
          point: userLocation,
          width: state.navigationActive ? 44 : 32,
          height: state.navigationActive ? 44 : 32,
          alignment: Alignment.center,
          child: state.navigationActive
              ? MarkerFactory.navigationVehicle(
                  bearing: state.navigationHeading ?? 0,
                )
              : MarkerFactory.userLocation(tooltip: AppStrings.yourLocation),
        ),
      );
    }

    // During playback the stop dots mirror the headline timeline:
    // green ring = upcoming, orange = visiting now, green check = done.
    final simTarget = state.simulationActive && state.optimizedRoute != null
        ? _simTargetIndex(state.optimizedRoute!, state.simulationProgress)
        : null;
    final simFinished =
        state.simulationActive && state.simulationProgress >= 1.0;

    var stopIndex = 0;
    for (var i = 0; i < state.points.length; i++) {
      final p = state.points[i];
      final label = p.address?.isNotEmpty == true
          ? '${p.label}\n${p.address}'
          : p.label;

      StopVisitState? visit;
      if (simTarget != null && !p.isDepot) {
        visit = simFinished || i < simTarget
            ? StopVisitState.visited
            : i == simTarget
            ? StopVisitState.visiting
            : StopVisitState.upcoming;
      }

      final markerChild = p.isDepot
          ? MarkerFactory.depot(tooltip: label)
          : MarkerFactory.stop(++stopIndex, tooltip: label, visit: visit);

      markers.add(
        Marker(
          point: p.latLng,
          width: 34,
          height: 34,
          alignment: Alignment.center,
          child: GestureDetector(
            // Tap to select the point and rename / set-departure / remove it;
            // long-press stays a quick shortcut to remove.
            onTap: () => _showPointActions(context, p),
            onLongPress: () => _confirmRemovePoint(context, p.id),
            child: markerChild,
          ),
        ),
      );
    }

    if (state.simulationActive && state.optimizedRoute != null) {
      final sample = PolylineUtils.sampleAt(
        state.optimizedRoute!.fullPolyline,
        state.simulationProgress,
      );
      if (sample != null) {
        final bearing = state.simulationCameraMode == SimulationCameraMode.chase
            ? 0.0
            : sample.bearing;
        markers.add(
          Marker(
            point: sample.point,
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: MarkerFactory.vehicle(bearing: bearing),
          ),
        );
      }
    }

    return markers;
  }

  /// Index (into orderedPoints) of the stop the playback vehicle is
  /// currently driving to — same math as the preview headline.
  int _simTargetIndex(OptimizedRoute route, double progress) {
    final count = route.orderedPoints.length;
    if (count < 2) return 0;
    final segments = count - 1;
    return ((progress * segments).floor() + 1).clamp(1, count - 1);
  }

  List<Polyline> _buildPolylines(RoutePlannerState state) {
    final route = state.optimizedRoute;
    if (route == null) return const [];

    final polylines = <Polyline>[];

    if (state.navigationActive) {
      if (route.fullPolyline.isNotEmpty) {
        polylines.add(
          Polyline(
            points: route.fullPolyline,
            color: AppColors.textMuted.withValues(alpha: 0.35),
            strokeWidth: 5,
          ),
        );
      }
      final remaining = _trailFrom(
        route.fullPolyline,
        state.navigationProgress,
      );
      if (remaining.isNotEmpty) {
        polylines.add(
          Polyline(points: remaining, color: AppColors.primary, strokeWidth: 8),
        );
      }
      return polylines;
    }

    if (state.simulationActive) {
      if (route.fullPolyline.isNotEmpty) {
        polylines.add(
          Polyline(
            points: route.fullPolyline,
            color: AppColors.primary.withValues(alpha: 0.30),
            strokeWidth: 5,
          ),
        );
      }
      final trail = _trailUpTo(route.fullPolyline, state.simulationProgress);
      if (trail.isNotEmpty) {
        polylines.add(
          Polyline(points: trail, color: AppColors.accent, strokeWidth: 8),
        );
      }
      return polylines;
    }

    final highlighted = switch (state.displaySegment) {
      RouteSegment.go => route.goPolyline,
      RouteSegment.returnLeg => route.returnPolyline,
      RouteSegment.full => route.fullPolyline,
    };

    final color = switch (state.displaySegment) {
      RouteSegment.go => AppColors.routeGo,
      RouteSegment.returnLeg => AppColors.routeReturn,
      RouteSegment.full => AppColors.routeFull,
    };

    if (route.fullPolyline.isNotEmpty) {
      polylines.add(
        Polyline(
          points: route.fullPolyline,
          color: AppColors.textMuted.withValues(alpha: 0.55),
          strokeWidth: 4,
        ),
      );
    }
    if (highlighted.isNotEmpty) {
      polylines.add(
        Polyline(points: highlighted, color: color, strokeWidth: 7),
      );
    }
    return polylines;
  }

  /// Take the prefix of [path] up to fraction `t` of its total length.
  List<LatLng> _trailUpTo(List<LatLng> path, double t) {
    if (path.length < 2 || t <= 0) return const [];
    final total = DistanceUtils.pathLengthKm(path);
    if (total <= 0) return const [];
    final target = total * t.clamp(0.0, 1.0);

    final out = <LatLng>[path.first];
    double traveled = 0;
    for (var i = 0; i < path.length - 1; i++) {
      final segLen = DistanceUtils.haversineKm(path[i], path[i + 1]);
      if (traveled + segLen >= target) {
        final remaining = target - traveled;
        final f = segLen == 0 ? 0.0 : (remaining / segLen);
        out.add(
          LatLng(
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

  List<LatLng> _trailFrom(List<LatLng> path, double t) {
    if (path.length < 2) return path;
    final start = PolylineUtils.interpolateByLength(path, t);
    if (start == null) return path;

    final total = DistanceUtils.pathLengthKm(path);
    if (total <= 0) return path;
    final target = total * t.clamp(0.0, 1.0);

    final out = <LatLng>[start];
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

  /// Tapping a placed marker selects it and opens its actions: rename, set as
  /// departure (stops only), or remove.
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
              child: const Icon(
                Iconsax.trash,
                color: AppColors.danger,
                size: 26,
              ),
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

  void _openOsmCopyright() {
    unawaited(
      launchUrl(
        Uri.parse('https://www.openstreetmap.org/copyright'),
        mode: LaunchMode.externalApplication,
      ),
    );
  }
}

/// Actions for a tapped map point: rename, set as departure (stops only),
/// or remove. Presented as a small bottom sheet anchored over the map.
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
            BoxShadow(color: AppColors.shadow, blurRadius: 30, offset: Offset(0, 12)),
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

/// "Recenter" pill shown during simulation after the user pans away — taps to
/// resume following the vehicle.
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
              BoxShadow(color: AppColors.shadow, blurRadius: 18, offset: Offset(0, 6)),
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
