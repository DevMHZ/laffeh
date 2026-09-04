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

  /// The same treatment for the round badges (stops, depot, finish, the
  /// user dot). They were rasterised at their logical size — 34 px — and
  /// then drawn with `iconSize: dpr`. That correction exists because iOS
  /// loads an image at the screen scale; Android does not, so the same 34 px
  /// bitmap was being blown up two or three times and arrived visibly
  /// pixelated on an Android phone.
  static const double badgeOversample = 3.0;

  /// Room around a badge for its shadow to fall in, as a fraction of the
  /// badge's own size.
  ///
  /// A Gaussian mask filter reaches roughly three sigma past the shape, and
  /// the canvas was exactly the size of the circle: the "visiting" glow
  /// (sigma 6, from a circle of radius 12 in a 34 px box) wanted 47 px and
  /// got 34, so it was sliced off square on all four sides. That hard edge
  /// is the shaded box people see around the circle.
  ///
  /// Proportional rather than absolute so the compensation below stays a
  /// single number: every badge grows by the same factor, whatever its size.
  /// 0.6 rather than something tighter because the "visiting" glow is the
  /// hungriest: radius 15 plus three sigma of a sigma-6 blur wants 33 px
  /// clear of the centre, and 0.4 still sliced 2 px off it.
  static const double badgePaddingRatio = 0.6;

  /// How much bigger a padded badge is than the badge itself.
  static const double badgeFootprint = 1 + 2 * badgePaddingRatio;

  /// What to divide `iconSize` by so a padded, oversampled badge lands on
  /// screen at exactly the size it always was.
  ///
  /// The oversample only — deliberately *not* the footprint as well. Dividing
  /// by both holds the whole *bitmap* to its old size, which shrinks the
  /// badge inside it by exactly [badgeFootprint]: the padding is meant to
  /// extend the canvas outwards so the shadow has room, not to squeeze the
  /// circle into the space that was there before. Shipped that way once and
  /// the delivery points visibly shrank.
  static const double badgeIconDivisor = badgeOversample;
}
