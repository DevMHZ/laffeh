import 'package:flutter/widgets.dart';

/// Tuning for the map surface, camera, and route polylines.
///
/// Everything the planning/preview/drive map cares about — zoom limits,
/// camera animation timing, bounds-fit padding, and line widths — lives
/// here so behaviour can be adjusted in one place.
class MapConfig {
  MapConfig._();

  // ── Fallback location ────────────────────────────────────
  /// Riyadh city centre — the initial camera target while the real
  /// user location is still resolving.
  static const double fallbackLat = 24.7136;
  static const double fallbackLon = 46.6753;

  // ── Zoom ─────────────────────────────────────────────────
  static const double minZoom = 3;
  static const double maxZoom = 19;

  /// Wide establishing shot used before a location/route is known.
  static const double initialZoom = 12.5;

  /// Comfortable street-level zoom when focusing a single target.
  static const double focusedZoom = 14.5;

  /// Lowest zoom we allow when entering "move a point" mode.
  static const double movePointMinZoom = 16;

  /// Cap applied after fitting a set of points to bounds.
  static const double fitMaxZoom = 16;

  // ── Camera animation ─────────────────────────────────────
  /// Settle pause after an animated camera move completes.
  static const Duration animateSettle = Duration(milliseconds: 200);

  /// Native follow-camera interpolation between 30 fps playback targets.
  static const Duration followCamDuration = Duration(milliseconds: 140);

  // ── Bounds-fit padding ───────────────────────────────────
  static const EdgeInsets optimizedFitPadding =
      EdgeInsets.fromLTRB(34, 76, 34, 230);
  static const EdgeInsets overviewFitPadding =
      EdgeInsets.fromLTRB(40, 96, 40, 240);

  // ── On-map controls ──────────────────────────────────────
  /// "Return to my location" appears once the user pans this many
  /// logical px away from their current position.
  static const double recenterDriftPx = 90;

  /// A long-press within this distance (km) of a marker offers to
  /// remove it.
  static const double removeTapRadiusKm = 0.15;

  /// Overview is considered "adjusted" (offering a reset) once the user
  /// zooms past this delta or pans past this many metres.
  static const double overviewResetZoomDelta = 0.25;
  static const double overviewResetMoveMeters = 50;

  // ── Geometry ─────────────────────────────────────────────
  /// Shortest-arc heading smoothing for the playback vehicle + camera.
  static const double angleSmoothingFactor = 0.35;

  /// Earth radius (metres) for the look-ahead destination math.
  static const double earthRadiusMeters = 6371008.8;

  // ── Polyline widths (by role) ────────────────────────────
  static const double planBgWidth = 4;
  static const double planFgWidth = 7;
  static const double driveDoneWidth = 6;
  static const double driveAheadWidth = 7;
  static const double driveCurrentWidth = 9;
  static const double simGhostWidth = 5;
  static const double simTrailWidth = 8;
}
