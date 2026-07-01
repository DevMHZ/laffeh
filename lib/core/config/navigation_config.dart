/// Tuning for live drive mode (turn-by-turn following).
class NavigationConfig {
  NavigationConfig._();

  // ── Camera ───────────────────────────────────────────────
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

  /// Native camera interpolation between GPS-driven follow targets. Long
  /// enough to glide over the ~1 s / 5 m GPS cadence, short enough that the
  /// view never lags a genuine turn.
  static const Duration cameraAnimDuration = Duration(milliseconds: 700);

  // ── Speed-adaptive zoom ──────────────────────────────────
  // The follow camera zooms out as the vehicle speeds up so the driver
  // always sees an appropriate amount of road ahead. Zoom is interpolated
  // piecewise between these anchors and then exponentially smoothed, so
  // transitions are gradual — never a visible "gear change".
  static const double zoomCrawl = 17.5; // ≤ crawl speed (stopped/serving)
  static const double zoomCity = 17.0; // urban driving
  static const double zoomFast = 16.2; // arterials
  static const double zoomHighway = 15.4; // ≥ highway speed
  static const double speedCrawlKmh = 15;
  static const double speedCityKmh = 40;
  static const double speedFastKmh = 80;

  /// Exponential smoother applied to the zoom target per camera frame.
  static const double zoomSmoothingFactor = 0.15;

  // ── Free exploration (drive mode) ────────────────────────
  /// After the user stops touching the map, follow-mode resumes
  /// automatically once this much time passes with no interaction.
  static const Duration exploreResumeDelay = Duration(seconds: 3);

  // ── GPS stream ───────────────────────────────────────────
  /// Minimum movement (metres) between position updates.
  static const int distanceFilterMeters = 5;

  /// Fixes with a worse reported accuracy than this are noise — they can
  /// teleport the car and mis-trigger service radii, so they're dropped.
  static const double maxAccuracyMeters = 40.0;

  /// Heading is meaningless when barely moving — only update it once
  /// the speed (m/s) clears this floor, so the camera doesn't spin in
  /// place at a standstill.
  static const double minSpeedForHeadingMps = 0.8;

  /// Exponential smoother for the drive camera heading (0..1).
  static const double headingSmoothingFactor = 0.3;

  /// Exponential smoother for GPS speed (drives the adaptive zoom).
  static const double speedSmoothingFactor = 0.3;

  // ── Service points ───────────────────────────────────────
  /// Radius (metres) around the current service point in which the driver
  /// counts as "arrived": the Point Served button appears and the
  /// enter-then-leave auto-serve arms itself.
  static const double serviceRadiusMeters = 10.0;

  /// The service radius grows by the fix's reported accuracy, capped at
  /// this — otherwise a 10 m radius can be physically unreachable on a
  /// phone that only ever reports 15–25 m accuracy.
  static const double serviceRadiusAccuracySlack = 15.0;

  /// After entering the service radius, moving farther than this from the
  /// point auto-completes it (the driver has served it and moved on).
  static const double autoServeExitMeters = 20.0;

  /// Chord length (metres) used to read the road tangent under the car for
  /// the avatar's rotation — long enough to smooth polyline vertex kinks,
  /// short enough to still be "the road under the car" (unlike the camera,
  /// which anticipates [cameraAnticipationMeters] ahead).
  static const double avatarTangentMeters = 12.0;

  /// Max distance (metres) a GPS fix may sit from the planned route for it
  /// to drive `navigationProgress`. Beyond this the fix is treated as
  /// off-route (Simulator, or the driver hasn't reached the start yet) and
  /// progress / arrival are frozen instead of snapping to the nearest
  /// polyline point — which used to jump progress to ~1.0 and fire bogus
  /// arrivals on the Simulator.
  static const double onRouteThresholdMeters = 120.0;

  // ── Turn guidance ────────────────────────────────────────
  /// The upcoming maneuver's road segment is highlighted (bright white)
  /// once the vehicle is within this many metres of it.
  static const double maneuverHighlightWithinMeters = 250.0;

  /// Length (metres) of the highlighted guidance segment drawn from the
  /// maneuver point forward along the selected branch.
  static const double maneuverHighlightLengthMeters = 45.0;

  // ── Debug ────────────────────────────────────────────────
  /// Distance the debug "step forward" control advances per tap.
  static const double debugStepKm = 0.10;
}
