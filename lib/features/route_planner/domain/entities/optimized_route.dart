import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

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

  const OptimizedRoute({
    required this.orderedPoints,
    required this.fullPolyline,
    required this.goPolyline,
    required this.returnPolyline,
    required this.metrics,
    required this.hasRoadGeometry,
  });

  bool get isEmpty => orderedPoints.isEmpty;

  @override
  List<Object?> get props => [
    orderedPoints,
    fullPolyline,
    goPolyline,
    returnPolyline,
    metrics,
    hasRoadGeometry,
  ];
}
