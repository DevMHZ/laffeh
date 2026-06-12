import 'route_point_model.dart';

/// Wire model for the Afdal VRP request body.
///
/// Matches the contract documented in `api_test/api_README.md`:
/// ```
/// num_vehicles, vehicle_capacity, depot_lat, depot_lon,
/// routing_mode, time_limit, max_vehicle_time, deliveries[]
/// ```
class RouteRequestModel {
  final int numVehicles;
  final double vehicleCapacity;
  final double depotLat;
  final double depotLon;
  final String routingMode;
  final int timeLimitSeconds;
  final int maxVehicleTimeMinutes;
  final List<RoutePointModel> deliveries;

  const RouteRequestModel({
    required this.numVehicles,
    required this.vehicleCapacity,
    required this.depotLat,
    required this.depotLon,
    required this.routingMode,
    required this.timeLimitSeconds,
    required this.maxVehicleTimeMinutes,
    required this.deliveries,
  });

  Map<String, dynamic> toJson() => {
    'num_vehicles': numVehicles,
    'vehicle_capacity': vehicleCapacity,
    'depot_lat': depotLat,
    'depot_lon': depotLon,
    'routing_mode': routingMode,
    'time_limit': timeLimitSeconds,
    'max_vehicle_time': maxVehicleTimeMinutes,
    'deliveries': deliveries.map((d) => d.toJson()).toList(),
  };
}
