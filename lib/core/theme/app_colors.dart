import 'package:flutter/material.dart';

import 'driver_palette.dart';

/// Laffah palette — now theme-aware.
///
/// Every theme-varying colour delegates to the active [DriverPalette]
/// ([active]); switching a theme (`AppTheme.setPalette`) re-points these
/// getters so the whole app re-themes live. Truly theme-agnostic colours
/// (pure white/black, overlay shadows) stay `const` so their many `const`
/// call-sites keep compiling.
class AppColors {
  AppColors._();

  /// The palette currently driving every dynamic colour below. Swapped by
  /// `AppTheme.setPalette`. Defaults to the high-contrast Daylight theme.
  static DriverPalette active = DriverPalette.daylight;

  // ── Brand ─────────────────────────────────────────────────
  static Color get leaf => active.leaf;
  static Color get primary => active.primary;
  static Color get primaryDark => active.primaryDark;
  static Color get primarySoft => active.primarySoft;
  static Color get primaryGlass => active.primaryGlass;

  static Color get accent => active.accent;
  static Color get accentDark => active.accentDark;
  static Color get accentSoft => active.accentSoft;

  static Color get asphalt => active.asphalt;
  static Color get asphaltDark => active.asphaltDark;

  // ── Logo pins ────────────────────────────────────────────
  static Color get pinBlue => active.pinBlue;
  static Color get pinRed => active.pinRed;
  static Color get pinOrange => active.pinOrange;

  // ── Surfaces ─────────────────────────────────────────────
  static Color get background => active.background;
  static Color get surface => active.surface;
  static Color get surfaceAlt => active.surfaceAlt;
  static Color get surfaceDim => active.surfaceDim;

  // ── Text / Icon ─────────────────────────────────────────
  static Color get textPrimary => active.textPrimary;
  static Color get textSecondary => active.textSecondary;
  static Color get textMuted => active.textMuted;
  static Color get hint => active.hint;

  // ── State ────────────────────────────────────────────────
  static Color get success => active.success;
  static Color get warning => active.warning;
  static Color get danger => active.danger;
  static Color get info => active.info;

  // ── Map route colors ─────────────────────────────────────
  static Color get routeFull => active.routeFull;
  static Color get routeGo => active.routeGo;
  static Color get routeReturn => active.routeReturn;
  static Color get routeShadow => active.routeShadow;

  // ── Drive-mode route segmentation ────────────────────────
  static Color get driveDone => active.driveDone;
  static Color get driveCurrent => active.driveCurrent;
  static Color get driveAhead => active.driveAhead;

  // ── Optional points ──────────────────────────────────────
  static Color get optional => active.optional;
  static Color get optionalOff => active.optionalOff;

  // ── Border / Divider ─────────────────────────────────────
  static Color get border => active.border;
  static Color get borderStrong => active.borderStrong;
  static Color get divider => active.divider;

  // ── Misc (theme-agnostic — kept const) ───────────────────
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color shadow = Color(0x1F142018);
  static const Color shadowSoft = Color(0x14000000);
}
