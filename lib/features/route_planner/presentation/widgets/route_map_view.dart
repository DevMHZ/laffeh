import 'dart:async';

import 'package:flutter/material.dart';
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
import '../../domain/entities/optimized_route.dart';
import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';

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

  /// Expose the map controller so the parent can read the map center.
  MapController get mapController => _controller;

  /// Current center of the map viewport.
  LatLng get mapCenter => _controller.camera.center;

  @override
  Widget build(BuildContext context) {
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
              urlTemplate: EnvConfig.osmTileUrlTemplate,
              userAgentPackageName: 'com.example.laffeh',
              maxNativeZoom: 19,
            ),
            PolylineLayer(polylines: _buildPolylines(state)),
            MarkerLayer(markers: _buildMarkers(state)),
            RichAttributionWidget(
              showFlutterMapAttribution: false,
              attributions: [
                TextSourceAttribution(
                  '© CARTO, © OpenStreetMap',
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
      _lastSimCameraMode = mode;
    }

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
        if (sample != null) {
          _controller.moveAndRotate(sample.point, 14.0, 0);
        }
        return;

      case SimulationCameraMode.chase:
        final sample = PolylineUtils.sampleAt(
          route.fullPolyline,
          state.simulationProgress,
        );
        if (sample != null) {
          _controller.moveAndRotate(sample.point, 15.2, sample.bearing);
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

    final heading = state.navigationHeading;
    if (heading == null) {
      _controller.moveAndRotate(loc, 16.2, 0);
    } else {
      _controller.moveAndRotate(loc, 16.2, heading);
    }
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

    var stopIndex = 0;
    for (final p in state.points) {
      final label = p.address?.isNotEmpty == true
          ? '${p.label}\n${p.address}'
          : p.label;

      final markerChild = p.isDepot
          ? MarkerFactory.depot(tooltip: label)
          : MarkerFactory.stop(++stopIndex, tooltip: label);

      markers.add(
        Marker(
          point: p.latLng,
          width: 34,
          height: 34,
          alignment: Alignment.center,
          child: GestureDetector(
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
