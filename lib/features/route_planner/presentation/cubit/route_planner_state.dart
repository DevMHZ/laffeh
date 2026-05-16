import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../domain/entities/optimized_route.dart';
import '../../domain/entities/route_point.dart';

/// Explicit lifecycle phases. Callers switch on this enum instead
/// of destructuring multiple booleans.
enum RoutePlannerStatus {
  initial,
  loadingLocation,
  locationReady,
  pointsUpdated,
  optimizing,
  optimizedSuccess,
  optimizedFailure,
}

/// How the camera behaves during simulation playback.
///
///   * [overview] — sits still on the whole route bounds; the
///     animated vehicle moves within the frame.
///   * [follow]   — flat top-down, camera follows the vehicle at
///     a moderate zoom. Best default for most users.
///   * [chase]    — 3D cinematic, tilted, rotated to the bearing
///     of motion. Looks great but is the most "intense".
enum SimulationCameraMode { overview, follow, chase }

class RoutePlannerState extends Equatable {
  final RoutePlannerStatus status;

  /// User-picked points. Index 0 is always the depot.
  final List<RoutePoint> points;

  final LatLng? userLocation;
  final LatLng? cameraTarget;

  final OptimizedRoute? optimizedRoute;

  /// Which segment is highlighted on the map.
  final RouteSegment displaySegment;

  /// User-facing error message (Arabic). Only meaningful on
  /// `optimizedFailure`.
  final String? errorMessage;

  final bool missingMapsKey;

  // ── Simulation ──────────────────────────────────────────
  /// True while the simulation sheet is mounted (paused or playing).
  final bool simulationActive;
  final bool simulationPlaying;

  /// 0..1 — fraction along [OptimizedRoute.fullPolyline].
  final double simulationProgress;

  /// 0.5 / 1 / 2 / 4 — speed multiplier.
  final double simulationSpeed;

  final SimulationCameraMode simulationCameraMode;

  const RoutePlannerState({
    this.status = RoutePlannerStatus.initial,
    this.points = const [],
    this.userLocation,
    this.cameraTarget,
    this.optimizedRoute,
    this.displaySegment = RouteSegment.full,
    this.errorMessage,
    this.missingMapsKey = false,
    this.simulationActive = false,
    this.simulationPlaying = false,
    this.simulationProgress = 0.0,
    this.simulationSpeed = 1.0,
    this.simulationCameraMode = SimulationCameraMode.follow,
  });

  bool get hasOptimizedRoute => optimizedRoute != null;
  bool get isOptimizing => status == RoutePlannerStatus.optimizing;
  bool get isLoadingLocation => status == RoutePlannerStatus.loadingLocation;
  bool get hasPoints => points.isNotEmpty;
  bool get canOptimize => points.length >= 2 && !isOptimizing;

  RoutePlannerState copyWith({
    RoutePlannerStatus? status,
    List<RoutePoint>? points,
    LatLng? userLocation,
    LatLng? cameraTarget,
    OptimizedRoute? optimizedRoute,
    RouteSegment? displaySegment,
    String? errorMessage,
    bool? missingMapsKey,
    bool? simulationActive,
    bool? simulationPlaying,
    double? simulationProgress,
    double? simulationSpeed,
    SimulationCameraMode? simulationCameraMode,
    bool clearOptimizedRoute = false,
    bool clearError = false,
  }) {
    return RoutePlannerState(
      status: status ?? this.status,
      points: points ?? this.points,
      userLocation: userLocation ?? this.userLocation,
      cameraTarget: cameraTarget ?? this.cameraTarget,
      optimizedRoute:
          clearOptimizedRoute ? null : (optimizedRoute ?? this.optimizedRoute),
      displaySegment: displaySegment ?? this.displaySegment,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      missingMapsKey: missingMapsKey ?? this.missingMapsKey,
      simulationActive: simulationActive ?? this.simulationActive,
      simulationPlaying: simulationPlaying ?? this.simulationPlaying,
      simulationProgress: simulationProgress ?? this.simulationProgress,
      simulationSpeed: simulationSpeed ?? this.simulationSpeed,
      simulationCameraMode:
          simulationCameraMode ?? this.simulationCameraMode,
    );
  }

  @override
  List<Object?> get props => [
        status,
        points,
        userLocation,
        cameraTarget,
        optimizedRoute,
        displaySegment,
        errorMessage,
        missingMapsKey,
        simulationActive,
        simulationPlaying,
        simulationProgress,
        simulationSpeed,
        simulationCameraMode,
      ];
}
