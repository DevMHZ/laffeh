/// Tuning for live drive mode (turn-by-turn following).
class NavigationConfig {
  NavigationConfig._();

  // ── Camera ───────────────────────────────────────────────
  /// Close, tilted 3rd-person zoom for the driver's view.
  static const double zoom = 17.0;

  /// Pitch — a behind-the-car perspective looking down the road.
  static const double tilt = 60;

  /// How far ahead of the vehicle the camera targets, so the driver
  /// sits in the lower-middle of the screen.
  static const double lookaheadMeters = 115.0;

  /// Distance ahead on the route used to orient the camera bearing, so it
  /// rotates *into* a turn before the car reaches it (the road ahead stays
  /// pointing up) instead of swinging sideways mid-bend. Larger = more
  /// anticipation but more corner-cutting on tight curves.
  static const double cameraAnticipationMeters = 60.0;

  // ── GPS stream ───────────────────────────────────────────
  /// Minimum movement (metres) between position updates.
  static const int distanceFilterMeters = 5;

  /// Heading is meaningless when barely moving — only update it once
  /// the speed (m/s) clears this floor, so the camera doesn't spin in
  /// place at a standstill.
  static const double minSpeedForHeadingMps = 0.8;

  /// Exponential smoother for the drive camera heading (0..1).
  static const double headingSmoothingFactor = 0.3;

  // ── Arrival detection ────────────────────────────────────
  /// GPS distance (metres) from the current target stop that triggers
  /// an automatic "Arrived" — the cubit advances [navigationStopIndex]
  /// without waiting for the driver to tap the button.
  static const double arrivalRadiusMeters = 150.0;

  /// Max distance (metres) a GPS fix may sit from the planned route for it
  /// to drive `navigationProgress`. Beyond this the fix is treated as
  /// off-route (Simulator, or the driver hasn't reached the start yet) and
  /// progress / arrival are frozen instead of snapping to the nearest
  /// polyline point — which used to jump progress to ~1.0 and fire bogus
  /// arrivals on the Simulator.
  static const double onRouteThresholdMeters = 120.0;

  // ── Debug ────────────────────────────────────────────────
  /// Distance the debug "step forward" control advances per tap.
  static const double debugStepKm = 0.10;
}
