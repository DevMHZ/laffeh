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

  const RouteResponseModel({
    required this.metrics,
    required this.routes,
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
    return RouteResponseModel(
      metrics: RouteMetricsModel.fromJson(json),
      routes: routes,
    );
  }
}
