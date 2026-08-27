import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/services/location_gate.dart';
import '../../domain/entities/optimized_route.dart';
import '../../domain/entities/route_point.dart';

/// Id of the departure that tracks the driver's live location. Kept here
/// rather than inside the cubit because both the map (which hides its marker
/// — the blue dot already stands there) and the state's own
/// [RoutePlannerState.departureIsCurrentLocation] have to recognise it.
const String kCurrentLocationDepotId = 'depot_current';

/// Id of a departure the driver named themselves. A different id on purpose:
/// optimizing refreshes [kCurrentLocationDepotId] to the latest fix, and a
/// chosen starting point must not be dragged along behind the driver.
const String kCustomDepotId = 'depot_custom';

/// What the crosshair is aiming at.
enum PlacementTarget { stop, departure }

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

  /// Whether the device will give us a position at all. Unlike [errorMessage]
  /// — which is transient and cleared by the next successful action — this
  /// tracks the standing state, so the map can keep offering a way to turn
  /// location on for as long as it is off. Null until first checked.
  final LocationAccess? locationAccess;

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
  /// the first fix. Straight-line — this is the figure the service-radius
  /// machine compares against, since "am I standing at the stop?" is a
  /// question about physical proximity, not about roads.
  final double? navigationStopDistanceMeters;

  /// Distance (metres) still to **drive** to the current target stop,
  /// measured along the planned polyline — U-turns, one-ways and every
  /// other detour included. This is what the HUD shows the driver; null
  /// while the fix is off-route (no trustworthy projection), when the UI
  /// falls back to [navigationStopDistanceMeters].
  final double? navigationStopRouteDistanceMeters;

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

  /// True while a deviation-triggered route recalculation is in flight.
  /// Navigation keeps running off the old geometry until the new route
  /// lands; the HUD shows a subtle "recalculating" notice meanwhile.
  final bool isRerouting;

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

  /// What the next map-drop lands as. The crosshair flow is shared: the
  /// driver aims the same way whether they are placing where the trip ends
  /// or where it starts.
  final PlacementTarget placementTarget;

  /// True once the driver has said, up front, that this is a multi-stop
  /// trip. It keeps the planner on screen from the first point instead of
  /// waiting for a second destination to reveal it.
  ///
  /// Progressive disclosure is right for someone finding their way in; it is
  /// in the way of someone who already knows what they came to do.
  final bool multiStopIntent;

  /// True while a single destination is being routed in the background —
  /// the navigator shape's quiet equivalent of optimizing. Deliberately not
  /// [RoutePlannerStatus.optimizing]: that raises the full-screen planning
  /// animation, which is the ceremony this shape exists to avoid.
  final bool quietRouting;

  /// When the driver sets off. Null — the default — means "now", resolved
  /// at optimize time. Only matters once a stop carries a time window,
  /// since windows are clock times that have to be measured from somewhere.
  final DateTime? departureAt;

  const RoutePlannerState({
    this.status = RoutePlannerStatus.initial,
    this.points = const [],
    this.userLocation,
    this.cameraTarget,
    this.optimizedRoute,
    this.displaySegment = RouteSegment.full,
    this.stopFractions = const [],
    this.errorMessage,
    this.locationAccess,
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
    this.navigationStopRouteDistanceMeters,
    this.maneuverFractions = const [],
    this.autoServeCount = 0,
    this.autoServedStopLabel,
    this.isRerouting = false,
    this.isOffline = false,
    this.draftRestored = false,
    this.movingPointId,
    this.manualPlacement = false,
    this.quietRouting = false,
    this.placementTarget = PlacementTarget.stop,
    this.multiStopIntent = false,
    this.departureAt,
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

  /// Destinations the driver has actually asked for — every routable point
  /// that isn't the departure. This is the number the whole UI shape hangs
  /// off: one is a navigator, more than one is the planner.
  int get destinationCount =>
      points.where((p) => !p.isDepot && p.isRoutable).length;

  /// True while the trip is "drive me to this one place" — the shape that
  /// should look and feel like any other navigator, with none of the
  /// planning apparatus. Multi-stop is what the app sells, so it appears the
  /// moment the driver asks for a second destination — or the moment they
  /// say up front that a second one is coming.
  bool get isSingleDestination => destinationCount == 1 && !multiStopIntent;

  /// Where the trip starts. Null before the first destination lands, since
  /// the departure is injected alongside it.
  RoutePoint? get departurePoint {
    for (final p in points) {
      if (p.isDepot) return p;
    }
    return null;
  }

  /// True while the trip starts from wherever the driver happens to be — the
  /// default, and the only thing a navigator ever assumes. False once they
  /// have named a starting place of their own.
  bool get departureIsCurrentLocation =>
      departurePoint == null || departurePoint!.id == kCurrentLocationDepotId;

  /// True once any stop carries a clock window — gates the departure-time
  /// control, which is meaningless without one.
  bool get hasTimeWindows => points.any((p) => p.hasTimeWindow);

  /// Stops whose requested time the last optimization couldn't hit.
  ///
  /// The [RoutePoint.hasTimeWindow] guard is the invariant, not a filter:
  /// every warning in the UI reads this list, so a stop the user set no
  /// arrival time on can never be accused of missing one.
  List<RoutePoint> get missedTimeWindowPoints =>
      points.where((p) => p.timeWindowMissed && p.hasTimeWindow).toList();

  RoutePlannerState copyWith({
    RoutePlannerStatus? status,
    List<RoutePoint>? points,
    LatLng? userLocation,
    LatLng? cameraTarget,
    OptimizedRoute? optimizedRoute,
    RouteSegment? displaySegment,
    List<double>? stopFractions,
    String? errorMessage,
    LocationAccess? locationAccess,
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
    double? navigationStopRouteDistanceMeters,
    List<double>? maneuverFractions,
    int? autoServeCount,
    String? autoServedStopLabel,
    bool? isRerouting,
    bool? isOffline,
    bool? draftRestored,
    String? movingPointId,
    bool? manualPlacement,
    bool? quietRouting,
    PlacementTarget? placementTarget,
    bool? multiStopIntent,
    DateTime? departureAt,
    bool clearOptimizedRoute = false,
    bool clearError = false,
    bool clearNavigationHeading = false,
    bool clearNavigationSpeed = false,
    bool clearNavigationStopDistance = false,
    bool clearNavigationStopRouteDistance = false,
    bool clearMovingPoint = false,
    bool clearDepartureAt = false,
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
      locationAccess: locationAccess ?? this.locationAccess,
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
      navigationStopRouteDistanceMeters:
          clearNavigationStopDistance || clearNavigationStopRouteDistance
          ? null
          : (navigationStopRouteDistanceMeters ??
                this.navigationStopRouteDistanceMeters),
      maneuverFractions: maneuverFractions ?? this.maneuverFractions,
      autoServeCount: autoServeCount ?? this.autoServeCount,
      autoServedStopLabel: autoServedStopLabel ?? this.autoServedStopLabel,
      isRerouting: isRerouting ?? this.isRerouting,
      isOffline: isOffline ?? this.isOffline,
      draftRestored: draftRestored ?? this.draftRestored,
      movingPointId: clearMovingPoint
          ? null
          : (movingPointId ?? this.movingPointId),
      manualPlacement: manualPlacement ?? this.manualPlacement,
      quietRouting: quietRouting ?? this.quietRouting,
      placementTarget: placementTarget ?? this.placementTarget,
      multiStopIntent: multiStopIntent ?? this.multiStopIntent,
      departureAt: clearDepartureAt ? null : (departureAt ?? this.departureAt),
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
    locationAccess,
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
    navigationStopRouteDistanceMeters,
    maneuverFractions,
    autoServeCount,
    autoServedStopLabel,
    isRerouting,
    isOffline,
    draftRestored,
    movingPointId,
    manualPlacement,
    quietRouting,
    placementTarget,
    multiStopIntent,
    departureAt,
  ];
}
