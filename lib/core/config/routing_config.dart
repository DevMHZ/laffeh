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

  /// Max working time per driver (minutes).
  static const int defaultMaxVehicleTimeMinutes = 480;

  /// `car` | `bike` | `walking`.
  static const String defaultRoutingMode = 'car';
}
