import 'package:flutter/material.dart';

/// Afdal-Laffeh brand palette.
///
/// Derived from the official logo:
///   * Deep navy background  → `primary`
///   * Hexagonal green arrow → `accent`
///   * White wordmark        → `surface` / on-primary
///
/// Tones are kept restrained so the map remains the focus — the
/// brand colors live in the chrome (top bar, sheets, CTAs, routes).
class AppColors {
  AppColors._();

  // ── Brand ─────────────────────────────────────────────────
  static const Color primary = Color(0xFF2A4255);        // logo navy
  static const Color primaryDark = Color(0xFF1A2D3D);
  static const Color primarySoft = Color(0xFFE7ECF0);
  static const Color primaryGlass = Color(0xCC2A4255);   // for overlays

  static const Color accent = Color(0xFF5DBE5F);         // logo green
  static const Color accentDark = Color(0xFF45A347);
  static const Color accentSoft = Color(0xFFE2F4E3);

  // ── Surfaces ─────────────────────────────────────────────
  static const Color background = Color(0xFFF6F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF1F4F7);
  static const Color surfaceDim = Color(0xFFE9EDF1);

  // ── Text / Icon ─────────────────────────────────────────
  static const Color textPrimary = Color(0xFF12212E);
  static const Color textSecondary = Color(0xFF4B5A66);
  static const Color textMuted = Color(0xFF8A98A4);
  static const Color hint = Color(0xFFB5BFC8);

  // ── State ────────────────────────────────────────────────
  static const Color success = Color(0xFF22A06B);
  static const Color warning = Color(0xFFE5A12B);
  static const Color danger = Color(0xFFE0524C);
  static const Color info = Color(0xFF3E7BC0);

  // ── Map route colors ─────────────────────────────────────
  static const Color routeFull = Color(0xFF2A4255);   // navy (primary)
  static const Color routeGo = Color(0xFF5DBE5F);     // green (accent)
  static const Color routeReturn = Color(0xFFE5A12B); // warm amber
  static const Color routeShadow = Color(0x66E5E9EE);

  // ── Border / Divider ─────────────────────────────────────
  static const Color border = Color(0xFFE2E7EC);
  static const Color borderStrong = Color(0xFFCAD2DA);
  static const Color divider = Color(0xFFEEF1F5);

  // ── Misc ─────────────────────────────────────────────────
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color shadow = Color(0x1F0E1F2B);
  static const Color shadowSoft = Color(0x14000000);
}
