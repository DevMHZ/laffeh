import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../../../core/utils/marker_factory.dart';
import '../../../../core/utils/polyline_utils.dart';
import '../../domain/entities/optimized_route.dart';
import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';

/// Map surface. Renders user-picked points, the optimized polyline,
/// and (during playback) an animated vehicle marker that walks the
/// route from depot → stops → depot.
class RouteMapView extends StatefulWidget {
  const RouteMapView({super.key});

  @override
  State<RouteMapView> createState() => _RouteMapViewState();
}

class _RouteMapViewState extends State<RouteMapView> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  bool _hasAnimatedToFirstFix = false;
  bool _hasFitOptimizedBounds = false;

  // Cached, canvas-rendered marker bitmaps.
  //
  // We pre-build everything we'll plausibly need during `initState`
  // (BEFORE the user can tap), so by the time a marker is added the
  // icon is already in memory and the marker renders in its final
  // form — no flicker from the default Google "pin" to the branded
  // numbered circle.
  BitmapDescriptor? _depotIcon;
  BitmapDescriptor? _vehicleIcon;
  final Map<int, BitmapDescriptor> _stopIcons = {};

  /// How many stop icons to pre-rasterize at startup. Anything above
  /// this falls back to lazy load (no flicker either — we just skip
  /// the marker until the icon is ready).
  static const int _preloadStops = 20;

  @override
  void initState() {
    super.initState();
    _loadIcons();
  }

  Future<void> _loadIcons() async {
    // Parallel: depot + vehicle + stops 1..N all build at the same time.
    final results = await Future.wait([
      MarkerFactory.depot(),
      MarkerFactory.vehicle(),
      for (var i = 1; i <= _preloadStops; i++) MarkerFactory.stop(i),
    ]);
    if (!mounted) return;
    setState(() {
      _depotIcon = results[0];
      _vehicleIcon = results[1];
      for (var i = 1; i <= _preloadStops; i++) {
        _stopIcons[i] = results[1 + i];
      }
    });
  }

  Future<void> _ensureStopIcon(int index) async {
    if (_stopIcons.containsKey(index)) return;
    final icon = await MarkerFactory.stop(index);
    if (!mounted) return;
    setState(() => _stopIcons[index] = icon);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RoutePlannerCubit, RoutePlannerState>(
      listenWhen: (a, b) =>
          a.cameraTarget != b.cameraTarget ||
          a.optimizedRoute != b.optimizedRoute ||
          a.simulationActive != b.simulationActive ||
          a.simulationProgress != b.simulationProgress ||
          a.simulationCameraMode != b.simulationCameraMode,
      listener: _onStateChange,
      buildWhen: (a, b) =>
          a.points != b.points ||
          a.optimizedRoute != b.optimizedRoute ||
          a.displaySegment != b.displaySegment ||
          a.cameraTarget != b.cameraTarget ||
          a.simulationActive != b.simulationActive ||
          a.simulationProgress != b.simulationProgress ||
          a.simulationCameraMode != b.simulationCameraMode,
      builder: (context, state) {
        final target = state.cameraTarget ??
            const LatLng(AppConfig.fallbackLat, AppConfig.fallbackLon);

        return GoogleMap(
          initialCameraPosition: CameraPosition(
            target: target,
            zoom: AppConfig.initialZoom,
          ),
          myLocationEnabled: state.userLocation != null,
          myLocationButtonEnabled: false,
          compassEnabled: true,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          markers: _buildMarkers(context, state),
          polylines: _buildPolylines(state),
          onMapCreated: (c) {
            if (!_controller.isCompleted) _controller.complete(c);
            // Just in case the user already has more than [_preloadStops]
            // points (e.g. opened a saved route), warm up the extras.
            for (var i = _preloadStops + 1; i <= state.points.length; i++) {
              _ensureStopIcon(i);
            }
          },
          onTap: (pos) {
            if (state.isOptimizing || state.simulationActive) return;
            context.read<RoutePlannerCubit>().addPoint(pos);
          },
          padding: const EdgeInsets.only(bottom: 140),
        );
      },
    );
  }

  /// True after we've already framed the route once for the current
  /// simulation in overview mode — we don't want to keep re-fitting
  /// every tick.
  bool _hasFitOverviewBounds = false;

  /// Tracks the last camera mode we reacted to, so we re-fit bounds
  /// when the user just switched into overview.
  SimulationCameraMode? _lastSimCameraMode;

  Future<void> _onStateChange(
    BuildContext context,
    RoutePlannerState state,
  ) async {
    final controller = await _controller.future;

    // ── Simulation playback ───────────────────────────────
    if (state.simulationActive && state.optimizedRoute != null) {
      final route = state.optimizedRoute!;
      final mode = state.simulationCameraMode;

      // User switched mode in-flight: reset the overview-fit guard.
      if (_lastSimCameraMode != mode) {
        _hasFitOverviewBounds = false;
        _lastSimCameraMode = mode;
      }

      switch (mode) {
        case SimulationCameraMode.overview:
          if (!_hasFitOverviewBounds && route.fullPolyline.isNotEmpty) {
            _hasFitOverviewBounds = true;
            final bounds = DistanceUtils.boundsOf(route.fullPolyline);
            await controller.animateCamera(
              CameraUpdate.newLatLngBounds(bounds, 80),
            );
          }
          // No follow — let the vehicle move inside the static frame.
          return;

        case SimulationCameraMode.follow:
          final sample = PolylineUtils.sampleAt(
            route.fullPolyline,
            state.simulationProgress,
          );
          if (sample != null) {
            await controller.moveCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: sample.point,
                  zoom: 14.0, // moderate, no street-level
                  bearing: 0,
                  tilt: 0,
                ),
              ),
            );
          }
          return;

        case SimulationCameraMode.chase:
          final sample = PolylineUtils.sampleAt(
            route.fullPolyline,
            state.simulationProgress,
          );
          if (sample != null) {
            await controller.moveCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: sample.point,
                  zoom: 15.2,
                  bearing: sample.bearing,
                  tilt: 45,
                ),
              ),
            );
          }
          return;
      }
    }

    // Simulation ended → clear overview guard for next run.
    _hasFitOverviewBounds = false;
    _lastSimCameraMode = null;

    // ── Just-finished optimization → fit bounds once ──────
    final route = state.optimizedRoute;
    if (route != null && route.fullPolyline.isNotEmpty) {
      if (!_hasFitOptimizedBounds) {
        _hasFitOptimizedBounds = true;
        final bounds = DistanceUtils.boundsOf(route.fullPolyline);
        await controller.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 70),
        );
      }
      return;
    } else {
      _hasFitOptimizedBounds = false;
    }

    if (state.cameraTarget != null && !_hasAnimatedToFirstFix) {
      _hasAnimatedToFirstFix = true;
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(state.cameraTarget!, AppConfig.focusedZoom),
      );
    }
  }

  // ── Markers ──────────────────────────────────────────────

  Set<Marker> _buildMarkers(BuildContext context, RoutePlannerState state) {
    final markers = <Marker>{};
    final cubit = context.read<RoutePlannerCubit>();

    // Points are NOT draggable during optimization or simulation —
    // changing them mid-flight would silently invalidate the result.
    final canDrag = !state.isOptimizing && !state.simulationActive;

    var stopIndex = 0;
    for (final p in state.points) {
      // Resolve the branded icon for this point.
      // If the icon hasn't been rasterized yet (edge case: > 20 stops
      // and the lazy load is still in flight), SKIP the marker entirely
      // for this frame. We never show the default Google pin to avoid
      // the "default pin flashing into custom number" flicker.
      BitmapDescriptor? icon;
      if (p.isDepot) {
        icon = _depotIcon;
      } else {
        stopIndex += 1;
        icon = _stopIcons[stopIndex];
        if (icon == null) {
          // Trigger async load; this frame stays clean, next frame
          // (after setState) will include the marker.
          _ensureStopIcon(stopIndex);
        }
      }

      if (icon == null) continue;

      markers.add(Marker(
        markerId: MarkerId(p.id),
        position: p.latLng,
        anchor: const Offset(0.5, 0.5),
        infoWindow: InfoWindow(title: p.label, snippet: p.address),
        icon: icon,
        zIndexInt: p.isDepot ? 10 : 5,
        draggable: canDrag,
        onDragEnd: (newPos) => cubit.updatePointPosition(p.id, newPos),
      ));
    }

    // Simulation vehicle marker — only when its branded icon is ready.
    if (state.simulationActive &&
        state.optimizedRoute != null &&
        _vehicleIcon != null) {
      final sample = PolylineUtils.sampleAt(
        state.optimizedRoute!.fullPolyline,
        state.simulationProgress,
      );
      if (sample != null) {
        markers.add(Marker(
          markerId: const MarkerId('__sim_vehicle__'),
          position: sample.point,
          rotation: 0,
          anchor: const Offset(0.5, 0.5),
          flat: false,
          zIndexInt: 99,
          icon: _vehicleIcon!,
        ));
      }
    }

    return markers;
  }

  // ── Polylines ────────────────────────────────────────────

  Set<Polyline> _buildPolylines(RoutePlannerState state) {
    final route = state.optimizedRoute;
    if (route == null) return const {};

    // During simulation we render two layers: the dim full route as a
    // backdrop, and the "trail" (the part already driven) on top in
    // bright accent. Outside simulation we just show the segment the
    // user picked via the toggle.

    if (state.simulationActive) {
      return {
        Polyline(
          polylineId: const PolylineId('sim_bg'),
          points: route.fullPolyline,
          color: AppColors.primary.withOpacity(0.30),
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
        Polyline(
          polylineId: const PolylineId('sim_trail'),
          points: _trailUpTo(route.fullPolyline, state.simulationProgress),
          color: AppColors.accent,
          width: 8,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      };
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

    return {
      Polyline(
        polylineId: const PolylineId('route_full_bg'),
        points: route.fullPolyline,
        color: AppColors.textMuted.withOpacity(0.55),
        width: 4,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
      Polyline(
        polylineId: const PolylineId('route_highlight'),
        points: highlighted,
        color: color,
        width: 7,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
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
        out.add(LatLng(
          path[i].latitude + (path[i + 1].latitude - path[i].latitude) * f,
          path[i].longitude + (path[i + 1].longitude - path[i].longitude) * f,
        ));
        return out;
      }
      traveled += segLen;
      out.add(path[i + 1]);
    }
    return out;
  }
}
