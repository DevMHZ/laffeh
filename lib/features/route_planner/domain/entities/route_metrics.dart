import 'package:equatable/equatable.dart';

/// Summary metrics returned to the UI after an optimization run.
///
/// All fields are nullable because the AI/VRP server may omit
/// any of them. The UI renders "غير متاح من الخادم" when a value
/// is missing rather than faking it.
class RouteMetrics extends Equatable {
  final double? totalDistanceKm;
  final double? estimatedDurationMinutes;
  final double? savedDistanceKm;
  final double? savedDurationMinutes;
  final double? fuelLiters;
  final int? vehiclesUsed;
  final double? totalLoad;

  const RouteMetrics({
    this.totalDistanceKm,
    this.estimatedDurationMinutes,
    this.savedDistanceKm,
    this.savedDurationMinutes,
    this.fuelLiters,
    this.vehiclesUsed,
    this.totalLoad,
  });

  RouteMetrics copyWith({
    double? totalDistanceKm,
    double? estimatedDurationMinutes,
    double? savedDistanceKm,
    double? savedDurationMinutes,
    double? fuelLiters,
    int? vehiclesUsed,
    double? totalLoad,
  }) =>
      RouteMetrics(
        totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
        estimatedDurationMinutes:
            estimatedDurationMinutes ?? this.estimatedDurationMinutes,
        savedDistanceKm: savedDistanceKm ?? this.savedDistanceKm,
        savedDurationMinutes:
            savedDurationMinutes ?? this.savedDurationMinutes,
        fuelLiters: fuelLiters ?? this.fuelLiters,
        vehiclesUsed: vehiclesUsed ?? this.vehiclesUsed,
        totalLoad: totalLoad ?? this.totalLoad,
      );

  @override
  List<Object?> get props => [
        totalDistanceKm,
        estimatedDurationMinutes,
        savedDistanceKm,
        savedDurationMinutes,
        fuelLiters,
        vehiclesUsed,
        totalLoad,
      ];
}
