import 'optimized_route_model.dart';
import 'route_metrics_model.dart';

/// Wire model for the full Afdal VRP response.
///
/// Documented top-level fields:
///   total_distance (float)
///   vehicles_used (int)
///   routes (list of [OptimizedRouteModel])
///
/// Any extra metric fields (duration, savings, fuel) are picked up
/// opportunistically by [RouteMetricsModel.fromJson].
class RouteResponseModel {
  final RouteMetricsModel metrics;
  final List<OptimizedRouteModel> routes;

  /// `local_osrm` | `lebanon_ch` | `public_osrm` | `haversine`, or null from
  /// a backend older than the field. Straight-line ordering is a materially
  /// worse plan and the driver is entitled to know they got one.
  final String? routingMethod;

  /// Non-fatal remarks from the solver — a fallback taken, an endpoint
  /// ignored, a reorder applied.
  final List<String> notes;

  const RouteResponseModel({
    required this.metrics,
    required this.routes,
    this.routingMethod,
    this.notes = const [],
  });

  factory RouteResponseModel.fromJson(Map<String, dynamic> json) {
    final routesRaw = json['routes'] ?? const [];
    final routes = <OptimizedRouteModel>[];
    if (routesRaw is List) {
      for (final r in routesRaw) {
        if (r is Map<String, dynamic>) {
          routes.add(OptimizedRouteModel.fromJson(r));
        }
      }
    }
    final notesRaw = json['notes'];
    return RouteResponseModel(
      metrics: RouteMetricsModel.fromJson(json),
      routes: routes,
      routingMethod: json['routing_method'] as String?,
      notes: notesRaw is List
          ? notesRaw.whereType<String>().toList(growable: false)
          : const [],
    );
  }
}
