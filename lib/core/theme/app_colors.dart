import 'package:flutter/material.dart';

/// Laffah brand palette.
///
/// Derived from the road-logo (laffaAppAnim):
///   * Leaf-green canvas      → `leaf` / splash & launch background
///   * Asphalt road           → `asphalt` / dark chrome & route lines
///   * Blue / red / orange pins → info / danger / warning + route hues
///
/// Tones are kept restrained so the map remains the focus — the
/// brand colors live in the chrome (top bar, sheets, CTAs, routes).
class AppColors {
  AppColors._();

  // ── Brand ─────────────────────────────────────────────────
  /// Exact logo canvas green. Used for splash/launch so the native
  /// launch screen and the Flutter splash blend seamlessly.
  static const Color leaf = Color(0xFF8BCA7E);

  static const Color primary = Color(0xFF3E9148); // deep leaf green
  static const Color primaryDark = Color(0xFF2F7339);
  static const Color primarySoft = Color(0xFFE9F4E5);
  static const Color primaryGlass = Color(0xCC3E9148); // for overlays

  static const Color accent = Color(0xFF63B956); // bright leaf
  static const Color accentDark = Color(0xFF4CA341);
  static const Color accentSoft = Color(0xFFEAF6E4);

  /// Logo road color — dark chrome, route lines, snackbars.
  static const Color asphalt = Color(0xFF383B3F);
  static const Color asphaltDark = Color(0xFF232529);

  // ── Logo pins ────────────────────────────────────────────
  static const Color pinBlue = Color(0xFF2D7FD3);
  static const Color pinRed = Color(0xFFE0524C);
  static const Color pinOrange = Color(0xFFF2A03D);

  // ── Surfaces ─────────────────────────────────────────────
  static const Color background = Color(0xFFF4F8F2);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFEFF4EC);
  static const Color surfaceDim = Color(0xFFE5EDE1);

  // ── Text / Icon ─────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1D2620);
  static const Color textSecondary = Color(0xFF4A5950);
  static const Color textMuted = Color(0xFF87978C);
  static const Color hint = Color(0xFFB2C0B4);

  // ── State ────────────────────────────────────────────────
  static const Color success = Color(0xFF3E9148);
  static const Color warning = Color(0xFFF2A03D); // pin orange
  static const Color danger = Color(0xFFE0524C); // pin red
  static const Color info = Color(0xFF2D7FD3); // pin blue

  // ── Map route colors ─────────────────────────────────────
  static const Color routeFull = Color(0xFF383B3F); // asphalt
  static const Color routeGo = Color(0xFF3E9148); // leaf green
  static const Color routeReturn = Color(0xFFF2A03D); // pin orange
  static const Color routeShadow = Color(0x66DDE8DA);

  // ── Drive-mode route segmentation (#2) ───────────────────
  /// Already-driven leg — light, "done" green.
  static const Color driveDone = Color(0xFF9FD493);
  /// Current leg between the driver and the next stop — blue.
  static const Color driveCurrent = Color(0xFF2D7FD3);
  /// Road still ahead after the next stop — normal brand green.
  static const Color driveAhead = Color(0xFF3E9148);

  // ── Optional points (#8) ─────────────────────────────────
  /// Accent for optional (non-mandatory) stops.
  static const Color optional = Color(0xFFF2A03D); // amber
  /// Deactivated optional stop — muted/greyed.
  static const Color optionalOff = Color(0xFF9AA6A0);

  // ── Border / Divider ─────────────────────────────────────
  static const Color border = Color(0xFFDFE8DA);
  static const Color borderStrong = Color(0xFFC4D3BE);
  static const Color divider = Color(0xFFEAF0E6);

  // ── Misc ─────────────────────────────────────────────────
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color shadow = Color(0x1F142018);
  static const Color shadowSoft = Color(0x14000000);
}
