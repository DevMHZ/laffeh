import 'route_point_model.dart';

/// Wire model for the Afdal VRP request body.
///
/// Matches the `OptimizationRequest` schema published by the backend:
/// ```
/// num_vehicles, vehicle_capacity, depot_lat, depot_lon, routing_mode,
/// time_limit, driver_hours, default_service_time, deliveries[]
/// ```
///
/// Note: earlier versions of this client sent `max_vehicle_time`, which is
/// not part of the schema and was silently discarded by the server. The
/// working-day cap is `driver_hours`, and it doubles as the ceiling for
/// every stop's time window, so it is derived from the windows we send.
class RouteRequestModel {
  final int numVehicles;
  final double vehicleCapacity;
  final double depotLat;
  final double depotLon;
  final String routingMode;
  final int timeLimitSeconds;

  /// Length of the driver's working day, in hours. Windows are measured
  /// against this horizon, so it must cover the latest one.
  final int driverHours;

  /// Minutes spent at each stop before moving on.
  final int defaultServiceTimeMinutes;

  final List<RoutePointModel> deliveries;

  const RouteRequestModel({
    required this.numVehicles,
    required this.vehicleCapacity,
    required this.depotLat,
    required this.depotLon,
    required this.routingMode,
    required this.timeLimitSeconds,
    required this.driverHours,
    required this.defaultServiceTimeMinutes,
    required this.deliveries,
  });

  Map<String, dynamic> toJson() => {
    'num_vehicles': numVehicles,
    'vehicle_capacity': vehicleCapacity,
    'depot_lat': depotLat,
    'depot_lon': depotLon,
    'routing_mode': routingMode,
    'time_limit': timeLimitSeconds,
    'driver_hours': driverHours,
    'default_service_time': defaultServiceTimeMinutes,
    'deliveries': deliveries.map((d) => d.toJson()).toList(),
  };
}
