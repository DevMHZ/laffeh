import 'package:flutter/material.dart';

/// A complete, swappable colour palette for the app.
///
/// [AppColors] delegates every theme-varying colour to the currently active
/// [DriverPalette], so switching a palette live re-themes the whole app. Each
/// palette is tuned for glanceability while driving (strong figure/ground,
/// distinct route/drive semantics, day- or night-appropriate contrast).
///
/// Truly theme-agnostic colours (pure white/black, overlay shadows) stay
/// `const` on [AppColors] and are intentionally NOT part of a palette.
@immutable
class DriverPalette {
  /// Stable id used for persistence + Settings selection.
  final String id;

  /// Whether this is a light or dark palette (drives status-bar icon colour).
  final Brightness brightness;

  // ── Brand ────────────────────────────────────────────────
  final Color leaf;
  final Color primary;
  final Color primaryDark;
  final Color primarySoft;
  final Color primaryGlass;
  final Color accent;
  final Color accentDark;
  final Color accentSoft;
  final Color asphalt;
  final Color asphaltDark;

  // ── Pins ─────────────────────────────────────────────────
  final Color pinBlue;
  final Color pinRed;
  final Color pinOrange;

  // ── Surfaces ─────────────────────────────────────────────
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceDim;

  // ── Text / icon ──────────────────────────────────────────
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color hint;

  // ── State ────────────────────────────────────────────────
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  // ── Route ────────────────────────────────────────────────
  final Color routeFull;
  final Color routeGo;
  final Color routeReturn;
  final Color routeShadow;

  // ── Drive-mode segmentation ──────────────────────────────
  final Color driveDone;
  final Color driveCurrent;
  final Color driveAhead;

  // ── Optional points ──────────────────────────────────────
  final Color optional;
  final Color optionalOff;

  // ── Border / divider ─────────────────────────────────────
  final Color border;
  final Color borderStrong;
  final Color divider;

  const DriverPalette({
    required this.id,
    required this.brightness,
    required this.leaf,
    required this.primary,
    required this.primaryDark,
    required this.primarySoft,
    required this.primaryGlass,
    required this.accent,
    required this.accentDark,
    required this.accentSoft,
    required this.asphalt,
    required this.asphaltDark,
    required this.pinBlue,
    required this.pinRed,
    required this.pinOrange,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceDim,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.hint,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.routeFull,
    required this.routeGo,
    required this.routeReturn,
    required this.routeShadow,
    required this.driveDone,
    required this.driveCurrent,
    required this.driveAhead,
    required this.optional,
    required this.optionalOff,
    required this.border,
    required this.borderStrong,
    required this.divider,
  });

  bool get isDark => brightness == Brightness.dark;

  /// All selectable palettes, in Settings display order (lightest to
  /// darkest background).
  static const List<DriverPalette> all = [
    daylight,
    laffah,
    graphiteEv,
    amberDusk,
    midnight,
  ];

  static DriverPalette byId(String id) =>
      all.firstWhere((p) => p.id == id, orElse: () => daylight);

  // ── Laffah Leaf — light brand (default) ──────────────────
  static const DriverPalette laffah = DriverPalette(
    id: 'laffah',
    brightness: Brightness.light,
    leaf: Color(0xFF8BCA7E),
    primary: Color(0xFF3E9148),
    primaryDark: Color(0xFF2F7339),
    primarySoft: Color(0xFFE9F4E5),
    primaryGlass: Color(0xCC3E9148),
    accent: Color(0xFF63B956),
    accentDark: Color(0xFF4CA341),
    accentSoft: Color(0xFFEAF6E4),
    asphalt: Color(0xFF383B3F),
    asphaltDark: Color(0xFF232529),
    pinBlue: Color(0xFF2D7FD3),
    pinRed: Color(0xFFE0524C),
    pinOrange: Color(0xFFF2A03D),
    background: Color(0xFFF4F8F2),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEFF4EC),
    surfaceDim: Color(0xFFE5EDE1),
    textPrimary: Color(0xFF1D2620),
    textSecondary: Color(0xFF4A5950),
    textMuted: Color(0xFF87978C),
    hint: Color(0xFFB2C0B4),
    success: Color(0xFF3E9148),
    warning: Color(0xFFF2A03D),
    danger: Color(0xFFE0524C),
    info: Color(0xFF2D7FD3),
    routeFull: Color(0xFF383B3F),
    routeGo: Color(0xFF3E9148),
    routeReturn: Color(0xFFF2A03D),
    routeShadow: Color(0x66DDE8DA),
    driveDone: Color(0xFF9FD493),
    driveCurrent: Color(0xFF2D7FD3),
    driveAhead: Color(0xFF3E9148),
    optional: Color(0xFFF2A03D),
    optionalOff: Color(0xFF9AA6A0),
    border: Color(0xFFDFE8DA),
    borderStrong: Color(0xFFC4D3BE),
    divider: Color(0xFFEAF0E6),
  );

  // ── Midnight — OLED dark, green/mint ─────────────────────
  static const DriverPalette midnight = DriverPalette(
    id: 'midnight',
    brightness: Brightness.dark,
    leaf: Color(0xFF5BD07A),
    primary: Color(0xFF5BD07A),
    primaryDark: Color(0xFF3DA85E),
    primarySoft: Color(0xFF14261B),
    primaryGlass: Color(0xCC1E2724),
    accent: Color(0xFF37E0A0),
    accentDark: Color(0xFF21B57E),
    accentSoft: Color(0xFF10231C),
    asphalt: Color(0xFF0A0E0D),
    asphaltDark: Color(0xFF050807),
    pinBlue: Color(0xFF5AB0FF),
    pinRed: Color(0xFFFF6B6B),
    pinOrange: Color(0xFFFFB454),
    background: Color(0xFF0A0E0D),
    surface: Color(0xFF141A18),
    surfaceAlt: Color(0xFF1E2724),
    surfaceDim: Color(0xFF263230),
    textPrimary: Color(0xFFEAF2EC),
    textSecondary: Color(0xFF9FB0A6),
    textMuted: Color(0xFF6E827A),
    hint: Color(0xFF56675F),
    success: Color(0xFF5BD07A),
    warning: Color(0xFFFFB454),
    danger: Color(0xFFFF6B6B),
    info: Color(0xFF5AB0FF),
    routeFull: Color(0xFF8FA39A),
    routeGo: Color(0xFF5BD07A),
    routeReturn: Color(0xFFFFB454),
    routeShadow: Color(0x3337E0A0),
    driveDone: Color(0xFF3DA85E),
    driveCurrent: Color(0xFF5AB0FF),
    driveAhead: Color(0xFF5BD07A),
    optional: Color(0xFFFFB454),
    optionalOff: Color(0xFF5A6B63),
    border: Color(0xFF26302C),
    borderStrong: Color(0xFF38453F),
    divider: Color(0xFF1E2724),
  );

  // ── Amber Dusk — warm dark, low blue light ───────────────
  static const DriverPalette amberDusk = DriverPalette(
    id: 'amberDusk',
    brightness: Brightness.dark,
    leaf: Color(0xFFF2A03D),
    primary: Color(0xFFF2A03D),
    primaryDark: Color(0xFFC97F26),
    primarySoft: Color(0xFF2A1E10),
    primaryGlass: Color(0xCC1F1810),
    accent: Color(0xFFFFC46B),
    accentDark: Color(0xFFD99E48),
    accentSoft: Color(0xFF241A0E),
    asphalt: Color(0xFF14100B),
    asphaltDark: Color(0xFF0C0906),
    pinBlue: Color(0xFF7FB0D8),
    pinRed: Color(0xFFFF6B5A),
    pinOrange: Color(0xFFFFB454),
    background: Color(0xFF14100B),
    surface: Color(0xFF1F1810),
    surfaceAlt: Color(0xFF2A2016),
    surfaceDim: Color(0xFF352A1D),
    textPrimary: Color(0xFFF5ECDD),
    textSecondary: Color(0xFFC4B49C),
    textMuted: Color(0xFF8A7C66),
    hint: Color(0xFF6E6250),
    success: Color(0xFF7FB069),
    warning: Color(0xFFFFC46B),
    danger: Color(0xFFFF6B5A),
    info: Color(0xFF7FB0D8),
    routeFull: Color(0xFFB0A088),
    routeGo: Color(0xFFFFC46B),
    routeReturn: Color(0xFFF2A03D),
    routeShadow: Color(0x33FFC46B),
    driveDone: Color(0xFF8A6E3D),
    driveCurrent: Color(0xFFFFD98A),
    driveAhead: Color(0xFFF2A03D),
    optional: Color(0xFFFFC46B),
    optionalOff: Color(0xFF6E6250),
    border: Color(0xFF2E2317),
    borderStrong: Color(0xFF40311F),
    divider: Color(0xFF241A0E),
  );

  // ── Graphite EV — neutral dark, electric blue/cyan ───────
  static const DriverPalette graphiteEv = DriverPalette(
    id: 'graphiteEv',
    brightness: Brightness.dark,
    leaf: Color(0xFF3B82F6),
    primary: Color(0xFF3B82F6),
    primaryDark: Color(0xFF2563EB),
    primarySoft: Color(0xFF10233F),
    primaryGlass: Color(0xCC191D22),
    accent: Color(0xFF22D3EE),
    accentDark: Color(0xFF0EA5C4),
    accentSoft: Color(0xFF0C2830),
    asphalt: Color(0xFF101316),
    asphaltDark: Color(0xFF0A0C0E),
    pinBlue: Color(0xFF3B82F6),
    pinRed: Color(0xFFFB7185),
    pinOrange: Color(0xFFFBBF24),
    background: Color(0xFF101316),
    surface: Color(0xFF191D22),
    surfaceAlt: Color(0xFF232830),
    surfaceDim: Color(0xFF2D343D),
    textPrimary: Color(0xFFEDF1F5),
    textSecondary: Color(0xFFA3AEBD),
    textMuted: Color(0xFF6B7684),
    hint: Color(0xFF545E6B),
    success: Color(0xFF34D399),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFFB7185),
    info: Color(0xFF3B82F6),
    routeFull: Color(0xFF94A3B8),
    routeGo: Color(0xFF22D3EE),
    routeReturn: Color(0xFFFBBF24),
    routeShadow: Color(0x333B82F6),
    driveDone: Color(0xFF64748B),
    driveCurrent: Color(0xFF3B82F6),
    driveAhead: Color(0xFF22D3EE),
    optional: Color(0xFFFBBF24),
    optionalOff: Color(0xFF5B6672),
    border: Color(0xFF262C34),
    borderStrong: Color(0xFF38414C),
    divider: Color(0xFF1E242B),
  );

  // ── Daylight HC — high-contrast light, bold blue route ───
  static const DriverPalette daylight = DriverPalette(
    id: 'daylight',
    brightness: Brightness.light,
    leaf: Color(0xFF0B7A2E),
    primary: Color(0xFF0B7A2E),
    primaryDark: Color(0xFF075C22),
    primarySoft: Color(0xFFDCF0E1),
    primaryGlass: Color(0xCC0B7A2E),
    accent: Color(0xFF0E8A38),
    accentDark: Color(0xFF0B6E2C),
    accentSoft: Color(0xFFDFF3E4),
    asphalt: Color(0xFF14181B),
    asphaltDark: Color(0xFF0A0D0F),
    pinBlue: Color(0xFF0A66C2),
    pinRed: Color(0xFFC81E1E),
    pinOrange: Color(0xFFC2410C),
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEEF2EE),
    surfaceDim: Color(0xFFE2E8E2),
    textPrimary: Color(0xFF0A0F0C),
    textSecondary: Color(0xFF2C352E),
    textMuted: Color(0xFF55605A),
    hint: Color(0xFF8A948D),
    success: Color(0xFF0B7A2E),
    warning: Color(0xFFC2410C),
    danger: Color(0xFFC81E1E),
    info: Color(0xFF0A66C2),
    routeFull: Color(0xFF2C352E),
    routeGo: Color(0xFF0B7A2E),
    routeReturn: Color(0xFFC2410C),
    routeShadow: Color(0x330A66C2),
    driveDone: Color(0xFF7FB98C),
    driveCurrent: Color(0xFF0A66C2),
    driveAhead: Color(0xFF0B7A2E),
    optional: Color(0xFFC2410C),
    optionalOff: Color(0xFF8A948D),
    border: Color(0xFFC7D2C9),
    borderStrong: Color(0xFF9FB0A3),
    divider: Color(0xFFE2E8E2),
  );
}
