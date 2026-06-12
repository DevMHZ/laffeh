import '../../domain/entities/route_metrics.dart';

class RouteMetricsModel {
  final double? totalDistanceKm;
  final double? estimatedDurationMinutes;
  final double? savedDistanceKm;
  final double? savedDurationMinutes;
  final double? fuelLiters;
  final int? vehiclesUsed;
  final double? totalLoad;

  const RouteMetricsModel({
    this.totalDistanceKm,
    this.estimatedDurationMinutes,
    this.savedDistanceKm,
    this.savedDurationMinutes,
    this.fuelLiters,
    this.vehiclesUsed,
    this.totalLoad,
  });

  /// Pluck metric fields out of the AI response.
  ///
  /// The documented fields are `total_distance` and `vehicles_used`;
  /// everything else is opportunistic and falls back to `null` so
  /// the UI can show "غير متاح من الخادم" instead of fabricating values.
  factory RouteMetricsModel.fromJson(Map<String, dynamic> json) {
    double? readDouble(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v is num) return v.toDouble();
      }
      return null;
    }

    int? readInt(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v is num) return v.toInt();
      }
      return null;
    }

    return RouteMetricsModel(
      totalDistanceKm: readDouble([
        'total_distance',
        'distance_km',
        'distance',
      ]),
      estimatedDurationMinutes: readDouble([
        'total_duration_minutes',
        'estimated_time',
        'duration_minutes',
        'duration',
      ]),
      savedDistanceKm: readDouble([
        'saved_distance',
        'distance_saved',
        'savings_distance',
      ]),
      savedDurationMinutes: readDouble([
        'saved_time',
        'saved_duration',
        'time_saved',
      ]),
      fuelLiters: readDouble([
        'fuel_liters',
        'fuel_consumption',
        'fuel',
        'fuel_saving',
      ]),
      vehiclesUsed: readInt(['vehicles_used', 'used_vehicles']),
      totalLoad: readDouble(['total_load']),
    );
  }

  RouteMetrics toEntity() => RouteMetrics(
    totalDistanceKm: totalDistanceKm,
    estimatedDurationMinutes: estimatedDurationMinutes,
    savedDistanceKm: savedDistanceKm,
    savedDurationMinutes: savedDurationMinutes,
    fuelLiters: fuelLiters,
    vehiclesUsed: vehiclesUsed,
    totalLoad: totalLoad,
  );
}
