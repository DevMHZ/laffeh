/// Defaults for the AI VRP (vehicle-routing) request.
///
/// Non-secret and environment-independent. Anything that varies per
/// environment belongs in `.env` (see [EnvConfig]).
class RoutingConfig {
  RoutingConfig._();

  /// Single-vehicle TSP-style routing by default.
  static const int defaultNumVehicles = 1;

  /// Kept large because real payloads aren't modelled.
  static const double defaultVehicleCapacity = 10000;

  /// Per-stop weight when the user hasn't specified one.
  static const int defaultStopWeight = 10;

  /// Seconds the solver may spend searching for the best route.
  static const int defaultTimeLimitSeconds = 4;

  /// Length of the driver's working day, in hours — the `driver_hours`
  /// field of the VRP request. It is also the ceiling every stop time
  /// window is measured against, so a trip with a late window raises it
  /// (see [driverHoursForHorizon]).
  static const int defaultDriverHours = 8;

  /// Hard ceiling for [driverHoursForHorizon]: a single trip never spans
  /// more than a day.
  static const int maxDriverHours = 24;

  /// Minutes the solver assumes are spent at each stop before driving on
  /// (`default_service_time`). Also used when projecting per-stop ETAs.
  static const int defaultServiceTimeMinutes = 5;

  /// Smallest `driver_hours` that still contains [horizonMinutes] — used so
  /// a stop due 11 hours after departure isn't rejected by the default
  /// 8-hour day. Clamped to [maxDriverHours].
  static int driverHoursForHorizon(int horizonMinutes) {
    final hours = (horizonMinutes / 60).ceil();
    if (hours < defaultDriverHours) return defaultDriverHours;
    return hours > maxDriverHours ? maxDriverHours : hours;
  }

  /// `car` | `bike` | `walking`.
  static const String defaultRoutingMode = 'car';
}
