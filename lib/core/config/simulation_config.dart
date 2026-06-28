/// Tuning for the trip preview ("simulation") playback.
class SimulationConfig {
  SimulationConfig._();

  /// Wall-clock time covered by one full preview playback at 1× speed.
  static const Duration baseDuration = Duration(seconds: 45);

  /// Playback tick rate (~30 fps). The map view coalesces frames so
  /// faster-than-render ticks never pile up.
  static const Duration tickInterval = Duration(milliseconds: 33);

  /// Speed multiplier bounds and default.
  static const double minSpeed = 0.25;
  static const double maxSpeed = 8.0;
  static const double defaultSpeed = 1.0;

  // ── Camera ───────────────────────────────────────────────
  /// Zoom for the north-up "follow" preview camera.
  static const double followZoom = 14.0;

  /// Zoom + tilt for the heading-up "chase" preview camera.
  static const double chaseZoom = 16.5;
  static const double chaseTilt = 60;

  // ── Vehicle easing (overview) ────────────────────────────
  /// Fraction of the gap to the target the vehicle closes each frame.
  static const double overviewEaseFactor = 0.22;

  /// Below this progress gap the vehicle is treated as settled.
  static const double overviewSettleThreshold = 0.0008;

  /// Skip pushing a vehicle update when rotation changed less than this.
  static const double vehicleRotationThreshold = 0.4;
}
