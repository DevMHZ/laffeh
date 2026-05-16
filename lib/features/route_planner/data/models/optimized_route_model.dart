import 'route_point_model.dart';

/// A single vehicle's itinerary inside the AI response.
///
/// Shape (from the Python sample):
/// ```json
/// {
///   "vehicle_id": 1,
///   "total_distance": 50.21,
///   "total_load": 220,
///   "stops": [{"address": "..."}, ...]
/// }
/// ```
class OptimizedRouteModel {
  final int vehicleId;
  final double totalDistanceKm;
  final double totalLoad;
  final List<RoutePointModel> stops;

  /// Optional encoded polyline if the API ever returns one.
  final String? encodedPolyline;

  const OptimizedRouteModel({
    required this.vehicleId,
    required this.totalDistanceKm,
    required this.totalLoad,
    required this.stops,
    this.encodedPolyline,
  });

  factory OptimizedRouteModel.fromJson(Map<String, dynamic> json) {
    final stopsRaw = json['stops'] ?? json['itinerary'] ?? const [];
    final stops = <RoutePointModel>[];
    if (stopsRaw is List) {
      for (var i = 0; i < stopsRaw.length; i++) {
        final s = stopsRaw[i];
        if (s is Map<String, dynamic>) {
          final p = RoutePointModel.fromJson(s);
          stops.add(
            RoutePointModel(
              address: p.address,
              lat: p.lat,
              lon: p.lon,
              weight: p.weight,
              sequence: p.sequence ?? i,
            ),
          );
        }
      }
    }

    return OptimizedRouteModel(
      vehicleId: (json['vehicle_id'] is num)
          ? (json['vehicle_id'] as num).toInt()
          : 0,
      totalDistanceKm: (json['total_distance'] is num)
          ? (json['total_distance'] as num).toDouble()
          : 0,
      totalLoad:
          (json['total_load'] is num) ? (json['total_load'] as num).toDouble() : 0,
      stops: stops,
      encodedPolyline: json['polyline']?.toString() ??
          json['encoded_polyline']?.toString(),
    );
  }
}
