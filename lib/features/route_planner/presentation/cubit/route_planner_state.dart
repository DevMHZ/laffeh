import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

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
///   * [overview] — panoramic: sits still on the whole route bounds so
///     every point is on screen; the animated vehicle moves within the
///     frame. This is the default the preview opens in.
///   * [follow]   — flat top-down, camera follows the vehicle at
///     a moderate zoom.
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

  /// True arc-length fraction (0..1) of each [optimizedRoute.orderedPoints]
  /// entry along the full polyline. Computed once when a route is set so
  /// marker/headline "visited" state flips exactly as the vehicle passes
  /// a stop (stops aren't evenly spaced along the road).
  final List<double> stopFractions;

  /// User-facing error message (Arabic). Only meaningful on
  /// `optimizedFailure`.
  final String? errorMessage;

  // ── Simulation ──────────────────────────────────────────
  /// True while the simulation sheet is mounted (paused or playing).
  final bool simulationActive;
  final bool simulationPlaying;

  /// 0..1 — fraction along [OptimizedRoute.fullPolyline].
  final double simulationProgress;

  /// 0.5 / 1 / 2 / 4 — speed multiplier.
  final double simulationSpeed;

  final SimulationCameraMode simulationCameraMode;

  // ── Live navigation ─────────────────────────────────────
  /// True while the driver is using the optimized route as a real
  /// route with GPS updates.
  final bool navigationActive;

  /// 0..1 — approximate current position along [OptimizedRoute.fullPolyline].
  final double navigationProgress;

  /// Index into [OptimizedRoute.orderedPoints] of the stop the driver is
  /// currently heading towards. Starts at 1 (first stop after the depot)
  /// and advances each time the driver marks a stop as done or GPS
  /// auto-detects arrival within 150 m.
  final int navigationStopIndex;

  /// Bearing reported by the device GPS, in degrees. May be null when
  /// the platform cannot provide a stable heading.
  final double? navigationHeading;

  /// Smoothed GPS speed in meters/second. May be null while stationary
  /// or when the platform does not report it. Drives the adaptive zoom
  /// and the HUD speed readout.
  final double? navigationSpeedMps;

  /// True while the driver is inside the service radius of the current
  /// target stop — the "Point Served" button is shown only in this phase.
  final bool navigationArrived;

  /// Live GPS distance (metres) to the current target stop; null before
  /// the first fix.
  final double? navigationStopDistanceMeters;

  /// Arc-length fraction (0..1) of each [OptimizedRoute.maneuvers] entry
  /// along the full polyline. Computed once when a route is set, same
  /// lifecycle as [stopFractions].
  final List<double> maneuverFractions;

  /// Monotonic counter bumped every time a service point is completed
  /// automatically (enter-then-leave). The HUD listens for increments to
  /// flash the "service point completed" notice; [autoServedStopLabel]
  /// carries the completed stop's name.
  final int autoServeCount;
  final String? autoServedStopLabel;

  /// True when the last connectivity probe found no internet. Drives the
  /// offline banner; edits keep saving locally regardless.
  final bool isOffline;

  /// True once a previously-saved local draft has been restored on
  /// startup — lets the UI show a subtle "we kept your work" hint.
  final bool draftRestored;

  /// Id of the point currently being repositioned on the map (#9), or
  /// null when not in "move" mode. While set, the planner UI collapses
  /// to a full-screen map with a reticle so the user can drop the point
  /// at a new spot with their finger.
  final String? movingPointId;

  /// True while the user is in the empty-state "drop a pin manually" flow —
  /// i.e. they tapped "add manually" but haven't placed the first point yet.
  /// Gates the centre crosshair so an untouched map stays clean.
  final bool manualPlacement;

  const RoutePlannerState({
    this.status = RoutePlannerStatus.initial,
    this.points = const [],
    this.userLocation,
    this.cameraTarget,
    this.optimizedRoute,
    this.displaySegment = RouteSegment.full,
    this.stopFractions = const [],
    this.errorMessage,
    this.simulationActive = false,
    this.simulationPlaying = false,
    this.simulationProgress = 0.0,
    this.simulationSpeed = 1.0,
    this.simulationCameraMode = SimulationCameraMode.overview,
    this.navigationActive = false,
    this.navigationProgress = 0.0,
    this.navigationStopIndex = 1,
    this.navigationHeading,
    this.navigationSpeedMps,
    this.navigationArrived = false,
    this.navigationStopDistanceMeters,
    this.maneuverFractions = const [],
    this.autoServeCount = 0,
    this.autoServedStopLabel,
    this.isOffline = false,
    this.draftRestored = false,
    this.movingPointId,
    this.manualPlacement = false,
  });

  bool get hasOptimizedRoute => optimizedRoute != null;
  bool get isOptimizing => status == RoutePlannerStatus.optimizing;
  bool get isLoadingLocation => status == RoutePlannerStatus.loadingLocation;
  bool get hasPoints => points.isNotEmpty;

  /// Points that will actually be optimized: every mandatory point plus
  /// optional points the user left active. Deactivated optional points
  /// are excluded.
  int get routableCount => points.where((p) => p.isRoutable).length;

  /// At least a depot + one active stop, and not mid-run.
  bool get canOptimize => routableCount >= 2 && !isOptimizing;

  RoutePlannerState copyWith({
    RoutePlannerStatus? status,
    List<RoutePoint>? points,
    LatLng? userLocation,
    LatLng? cameraTarget,
    OptimizedRoute? optimizedRoute,
    RouteSegment? displaySegment,
    List<double>? stopFractions,
    String? errorMessage,
    bool? simulationActive,
    bool? simulationPlaying,
    double? simulationProgress,
    double? simulationSpeed,
    SimulationCameraMode? simulationCameraMode,
    bool? navigationActive,
    double? navigationProgress,
    int? navigationStopIndex,
    double? navigationHeading,
    double? navigationSpeedMps,
    bool? navigationArrived,
    double? navigationStopDistanceMeters,
    List<double>? maneuverFractions,
    int? autoServeCount,
    String? autoServedStopLabel,
    bool? isOffline,
    bool? draftRestored,
    String? movingPointId,
    bool? manualPlacement,
    bool clearOptimizedRoute = false,
    bool clearError = false,
    bool clearNavigationHeading = false,
    bool clearNavigationSpeed = false,
    bool clearNavigationStopDistance = false,
    bool clearMovingPoint = false,
  }) {
    return RoutePlannerState(
      status: status ?? this.status,
      points: points ?? this.points,
      userLocation: userLocation ?? this.userLocation,
      cameraTarget: cameraTarget ?? this.cameraTarget,
      optimizedRoute: clearOptimizedRoute
          ? null
          : (optimizedRoute ?? this.optimizedRoute),
      displaySegment: displaySegment ?? this.displaySegment,
      stopFractions: stopFractions ?? this.stopFractions,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      simulationActive: simulationActive ?? this.simulationActive,
      simulationPlaying: simulationPlaying ?? this.simulationPlaying,
      simulationProgress: simulationProgress ?? this.simulationProgress,
      simulationSpeed: simulationSpeed ?? this.simulationSpeed,
      simulationCameraMode: simulationCameraMode ?? this.simulationCameraMode,
      navigationActive: navigationActive ?? this.navigationActive,
      navigationProgress: navigationProgress ?? this.navigationProgress,
      navigationStopIndex: navigationStopIndex ?? this.navigationStopIndex,
      navigationHeading: clearNavigationHeading
          ? null
          : (navigationHeading ?? this.navigationHeading),
      navigationSpeedMps: clearNavigationSpeed
          ? null
          : (navigationSpeedMps ?? this.navigationSpeedMps),
      navigationArrived: navigationArrived ?? this.navigationArrived,
      navigationStopDistanceMeters: clearNavigationStopDistance
          ? null
          : (navigationStopDistanceMeters ?? this.navigationStopDistanceMeters),
      maneuverFractions: maneuverFractions ?? this.maneuverFractions,
      autoServeCount: autoServeCount ?? this.autoServeCount,
      autoServedStopLabel: autoServedStopLabel ?? this.autoServedStopLabel,
      isOffline: isOffline ?? this.isOffline,
      draftRestored: draftRestored ?? this.draftRestored,
      movingPointId: clearMovingPoint
          ? null
          : (movingPointId ?? this.movingPointId),
      manualPlacement: manualPlacement ?? this.manualPlacement,
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
    stopFractions,
    errorMessage,
    simulationActive,
    simulationPlaying,
    simulationProgress,
    simulationSpeed,
    simulationCameraMode,
    navigationActive,
    navigationProgress,
    navigationStopIndex,
    navigationHeading,
    navigationSpeedMps,
    navigationArrived,
    navigationStopDistanceMeters,
    maneuverFractions,
    autoServeCount,
    autoServedStopLabel,
    isOffline,
    draftRestored,
    movingPointId,
    manualPlacement,
  ];
}
