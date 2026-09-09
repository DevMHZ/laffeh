import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import 'route_maneuver.dart';
import 'route_metrics.dart';
import 'route_point.dart';

/// Which segment of the round-trip the UI is currently showing.
enum RouteSegment { full, go, returnLeg }

/// The result of an optimization run.
///
/// The AI VRP returns the order in which to visit the stops; we
/// also keep a list of LatLngs along the actual driveable path
/// (populated from OSRM) so the polyline matches
/// real roads. If Directions fails we fall back to straight
/// segments between stops.
class OptimizedRoute extends Equatable {
  /// Ordered stops as returned by the optimizer.
  /// First & last entries are the depot.
  final List<RoutePoint> orderedPoints;

  /// Driveable geometry for the entire round-trip
  /// (depot → ... → depot).
  final List<LatLng> fullPolyline;

  /// Geometry for the "go" leg: depot → all stops (but not back).
  final List<LatLng> goPolyline;

  /// Geometry for the "return" leg: last stop → depot.
  final List<LatLng> returnPolyline;

  final RouteMetrics metrics;

  /// True when [fullPolyline] is real router geometry; false
  /// if we fell back to straight lines.
  final bool hasRoadGeometry;

  /// Route-ordered turn-by-turn maneuvers along [fullPolyline]. Empty for
  /// straight-line fallbacks and for routes saved before maneuvers existed
  /// — drive mode degrades to distance-to-stop guidance in that case.
  final List<RouteManeuver> maneuvers;

  /// Which distance matrix the optimiser ordered these stops with, as
  /// reported by the backend: `local_osrm`, `lebanon_ch`, `public_osrm` or
  /// `haversine`. Null for a route solved before the field existed, or for
  /// one restored from a saved file.
  ///
  /// It matters because the last value is a different product. Straight-line
  /// distances order stops badly wherever the short way is not the drivable
  /// way — across a canal, a railway, a motorway with few crossings — and the
  /// result is then drawn on real roads, so it reaches the driver looking
  /// like a zigzag with no explanation for it.
  final String? routingMethod;

  /// Whether the order came from straight-line distances rather than roads.
  bool get orderedOnStraightLines => routingMethod == 'haversine';

  const OptimizedRoute({
    required this.orderedPoints,
    required this.fullPolyline,
    required this.goPolyline,
    required this.returnPolyline,
    required this.metrics,
    required this.hasRoadGeometry,
    this.maneuvers = const [],
    this.routingMethod,
  });

  bool get isEmpty => orderedPoints.isEmpty;

  /// The same route with its stops replaced.
  ///
  /// Exists because a solved route holds its *own* copies of the points, so
  /// editing one in `state.points` afterwards changed nothing the driver
  /// could see — the summary sheet and the drive HUD both read from here.
  /// Geometry is untouched on purpose: this is for facts about a stop that
  /// do not move it, a phone number above all.
  OptimizedRoute withPoints(List<RoutePoint> points) => OptimizedRoute(
    orderedPoints: points,
    fullPolyline: fullPolyline,
    goPolyline: goPolyline,
    returnPolyline: returnPolyline,
    metrics: metrics,
    hasRoadGeometry: hasRoadGeometry,
    maneuvers: maneuvers,
    routingMethod: routingMethod,
  );

  @override
  List<Object?> get props => [
    orderedPoints,
    fullPolyline,
    goPolyline,
    returnPolyline,
    metrics,
    hasRoadGeometry,
    maneuvers,
    routingMethod,
  ];
}
