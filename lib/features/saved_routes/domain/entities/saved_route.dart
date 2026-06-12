import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import '../../../route_planner/domain/entities/optimized_route.dart';
import '../../../route_planner/domain/entities/route_metrics.dart';
import '../../../route_planner/domain/entities/route_point.dart';

/// A frozen-in-time snapshot of an optimized route, stored to local
/// history so the user can reopen / rename / delete it later.
///
/// This entity is the projection the rest of the app cares about; the
/// data layer round-trips it through JSON.
class SavedRoute extends Equatable {
  final String id;
  final String name;
  final DateTime savedAt;
  final String routingMode;

  /// Final, optimizer-ordered points. First (and possibly last) is
  /// the depot.
  final List<RoutePoint> orderedPoints;

  final RouteMetrics metrics;
  final List<LatLng> fullPolyline;
  final List<LatLng> goPolyline;
  final List<LatLng> returnPolyline;
  final bool hasRoadGeometry;

  const SavedRoute({
    required this.id,
    required this.name,
    required this.savedAt,
    required this.routingMode,
    required this.orderedPoints,
    required this.metrics,
    required this.fullPolyline,
    required this.goPolyline,
    required this.returnPolyline,
    required this.hasRoadGeometry,
  });

  /// Number of "real" stops (excluding the duplicated return depot).
  int get stopsCount {
    if (orderedPoints.length < 2) return 0;
    final last = orderedPoints.last;
    final first = orderedPoints.first;
    final closed =
        last.latitude == first.latitude && last.longitude == first.longitude;
    final unique = closed ? orderedPoints.length - 1 : orderedPoints.length;
    // Subtract the depot itself.
    return (unique - 1).clamp(0, unique);
  }

  /// Rebuild an [OptimizedRoute] from this record so the planner can
  /// display it again.
  OptimizedRoute toOptimizedRoute() => OptimizedRoute(
    orderedPoints: orderedPoints,
    fullPolyline: fullPolyline,
    goPolyline: goPolyline,
    returnPolyline: returnPolyline,
    metrics: metrics,
    hasRoadGeometry: hasRoadGeometry,
  );

  SavedRoute copyWith({
    String? id,
    String? name,
    DateTime? savedAt,
    String? routingMode,
    List<RoutePoint>? orderedPoints,
    RouteMetrics? metrics,
    List<LatLng>? fullPolyline,
    List<LatLng>? goPolyline,
    List<LatLng>? returnPolyline,
    bool? hasRoadGeometry,
  }) => SavedRoute(
    id: id ?? this.id,
    name: name ?? this.name,
    savedAt: savedAt ?? this.savedAt,
    routingMode: routingMode ?? this.routingMode,
    orderedPoints: orderedPoints ?? this.orderedPoints,
    metrics: metrics ?? this.metrics,
    fullPolyline: fullPolyline ?? this.fullPolyline,
    goPolyline: goPolyline ?? this.goPolyline,
    returnPolyline: returnPolyline ?? this.returnPolyline,
    hasRoadGeometry: hasRoadGeometry ?? this.hasRoadGeometry,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    savedAt,
    routingMode,
    orderedPoints,
    metrics,
    fullPolyline,
    goPolyline,
    returnPolyline,
    hasRoadGeometry,
  ];
}
