/// Tuning for the pseudo-3D vehicle marker (the pre-baked nav sprite
/// sheets rendered from the GLB models by tool/bake_vehicle_sprites).
class VehicleMarkerConfig {
  VehicleMarkerConfig._();

  // ── Nav sheet geometry ───────────────────────────────────
  // Must match the bake script's output: row-major grid, frame index =
  // heading * phases + phase, frame 0 = nose pointing up, headings
  // clockwise.
  static const int navSheetHeadings = 48; // 7.5° per heading step
  static const int navSheetPhases = 4; // animation phases per heading
  static const int navSheetCols = 16;
  static const int navSheetFramePx = 160;

  /// Degrees covered by one heading step.
  static const double headingStepDeg = 360 / navSheetHeadings;

  // ── Animation ────────────────────────────────────────────
  /// Wall-clock time per wheel/leg animation phase while the vehicle is
  /// moving (the clock freezes when it stops). Only the Flutter pucks
  /// animate phases; the native symbols hold phase 0, because every
  /// `iconImage` swap re-layouts the symbol and reads as a pulse against
  /// its otherwise-smooth glide.
  static const int phaseDurationMs = 150;

  /// Floor between native `iconImage` swaps (heading-frame changes in
  /// turns), so a fast bend can't churn the symbol layer every frame.
  static const int minFrameSwapMs = 90;

  // ── Rendering ────────────────────────────────────────────
  /// Native frame images are rasterised at this multiple of their logical
  /// size (and drawn with `iconSize: dpr / iconOversample`) so they stay
  /// crisp on high-DPR screens.
  static const double iconOversample = 3.0;
}
