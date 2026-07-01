import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppFontFamily {
  AppFontFamily._();
  static const String almarai = 'Almarai';
}

/// Tight, opinionated typography ramp.
///
/// Exposed as getters (not cached statics) so text colours track the active
/// theme: each access reads the current [AppColors] palette. The ramp follows
/// a 1.125 step: h1 28 / h2 22 / h3 18 / title 16 / body 14 / small 12.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get _base => TextStyle(
    fontFamily: AppFontFamily.almarai,
    color: AppColors.textPrimary,
    height: 1.32,
    letterSpacing: 0.0,
  );

  // ── Display / Headings ────────────────────────────────
  static TextStyle get display =>
      _base.copyWith(fontSize: 32, fontWeight: FontWeight.w800, height: 1.15);
  static TextStyle get h1 =>
      _base.copyWith(fontSize: 26, fontWeight: FontWeight.w800);
  static TextStyle get h2 =>
      _base.copyWith(fontSize: 22, fontWeight: FontWeight.w700);
  static TextStyle get h3 =>
      _base.copyWith(fontSize: 18, fontWeight: FontWeight.w700);

  // ── Titles ────────────────────────────────────────────
  static TextStyle get titleLg =>
      _base.copyWith(fontSize: 17, fontWeight: FontWeight.w700);
  static TextStyle get titleMd =>
      _base.copyWith(fontSize: 15, fontWeight: FontWeight.w700);
  static TextStyle get titleSm =>
      _base.copyWith(fontSize: 13, fontWeight: FontWeight.w700);

  // ── Body ──────────────────────────────────────────────
  static TextStyle get bodyLg =>
      _base.copyWith(fontSize: 16, fontWeight: FontWeight.w500);
  static TextStyle get bodyMd =>
      _base.copyWith(fontSize: 14, fontWeight: FontWeight.w500);
  static TextStyle get bodySm =>
      _base.copyWith(fontSize: 12, fontWeight: FontWeight.w500);

  // ── Muted / Helper ────────────────────────────────────
  static TextStyle get muted => _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );
  static TextStyle get mutedSm => _base.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
    letterSpacing: 0.2,
  );

  // ── Button / CTA ──────────────────────────────────────
  static TextStyle get button => _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
  );

  // ── Inverted ──────────────────────────────────────────
  static TextStyle get white14w600 => _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );
  static TextStyle get white16w700 => _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
  );

  // ── Colored variants ──────────────────────────────────
  static TextStyle get primary14w700 => _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );
  static TextStyle get accent14w700 => _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.accent,
  );
  static TextStyle get danger13w600 => _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.danger,
  );
  static TextStyle get success13w600 => _base.copyWith(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.success,
  );
}
