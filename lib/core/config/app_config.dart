/// App-wide non-secret configuration constants.
///
/// Tunable defaults for the AI VRP request and map behaviour.
/// These are NOT environment-dependent; if a value depends on
/// environment, put it in `.env` and surface it via [EnvConfig].
class AppConfig {
  AppConfig._();

  // ── AI VRP defaults ──────────────────────────────────────
  /// Number of vehicles. Single-vehicle TSP-style routing by default.
  static const int defaultNumVehicles = 1;

  /// Vehicle capacity (kept large because we don't model real payloads).
  static const double defaultVehicleCapacity = 10000;

  /// Default per-stop weight when the user hasn't specified one.
  static const int defaultStopWeight = 10;

  /// AI search budget. The Afdal VRP API spends up to this many
  /// seconds looking for the best route.
  static const int defaultTimeLimitSeconds = 4;

  /// Max working time per driver (minutes).
  static const int defaultMaxVehicleTimeMinutes = 480;

  /// Default routing mode (`car` | `bike` | `walking`).
  static const String defaultRoutingMode = 'car';

  // ── Map defaults ─────────────────────────────────────────
  /// Riyadh city center — used as the initial camera target
  /// while the actual user location is still being resolved.
  static const double fallbackLat = 24.7136;
  static const double fallbackLon = 46.6753;
  static const double initialZoom = 12.5;
  static const double focusedZoom = 14.5;

  // ── Network ──────────────────────────────────────────────
  /// Dio timeout. The AI request may take a while — give it air.
  static const Duration networkTimeout = Duration(seconds: 60);
}
