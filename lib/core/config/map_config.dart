import 'dart:io' show Platform;
import 'package:flutter/widgets.dart';

/// Tuning for the map surface, camera, and route polylines.
///
/// Everything the planning/preview/drive map cares about — zoom limits,
/// camera animation timing, bounds-fit padding, and line widths — lives
/// here so behaviour can be adjusted in one place.
class MapConfig {
  /// Whether the round map chrome (compass, the 2D/3D and locate buttons)
  /// blurs the map behind it.
  ///
  /// Off on Android. A BackdropFilter samples its backdrop in a *rectangular*
  /// layer; on older GPUs the ClipOval around it does not always constrain
  /// that layer, and the result is a shaded square with the circle sitting
  /// inside it — reported on an Oppo, on every round control at once.
  ///
  /// Little is lost. The fill in front of the blur is 92-94% opaque, so the
  /// blur was contributing a few percent of each pixel while costing an
  /// offscreen pass. Flip this to true to get it back on a device where it
  /// renders correctly.
  static final bool blurMapChrome = !Platform.isAndroid;

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
  static const EdgeInsets optimizedFitPadding = EdgeInsets.fromLTRB(
    34,
    76,
    34,
    230,
  );
  static const EdgeInsets overviewFitPadding = EdgeInsets.fromLTRB(
    40,
    96,
    40,
    240,
  );

  // ── On-map controls ──────────────────────────────────────
  /// "Return to my location" appears once the user pans this many
  /// logical px away from their current position.
  static const double recenterDriftPx = 90;

  /// How far above the bottom inset drive mode's "Re-center" pill floats,
  /// in logical px.
  ///
  /// It has to clear the HUD, not merely sit near it — and it has to do it
  /// without floating in the middle of the map either, which is what these
  /// became when the HUD's bottom panel folded into a one-row dock. The
  /// collapsed dock is 64 tall over an 8 px gutter; arriving stacks the
  /// 60 px arrival bar and its own gutter on top of that. Each value is
  /// that plus a thumb's worth of clearance.
  static const double navRecenterLiftPx = 88;
  static const double navRecenterLiftArrivedPx = 156;

  /// Half-size of the box a tap searches for a map label, in logical px.
  ///
  /// A single-pixel query is the wrong shape for a finger: it only hits a
  /// label when the touch lands exactly on a glyph, which on a real phone
  /// is almost never — verified on the simulator, where tapping visibly on
  /// "طريق بيروت" returned nothing at all. Roughly half a touch target,
  /// which finds the label under the thumb without swallowing its
  /// neighbours.
  static const double labelTapRadiusPx = 22;

  /// How close a tap must be to one of our own stop markers, in logical px,
  /// to count as hitting it rather than the map underneath.
  ///
  /// In pixels rather than metres because that is the question being asked:
  /// "did the finger land on the pin?" is about the screen, not the ground.
  /// The metre-based radius used for long-press-to-remove is ~150 m, which
  /// at street zoom covers a third of the display and silently swallows
  /// every label near a stop — observed doing exactly that to a park 112 m
  /// from the depot.
  static const double markerTapRadiusPx = 26;

  // ── Live location (planning mode) ────────────────────────
  /// How far the driver must move before the blue dot follows.
  ///
  /// Planning is not driving: this stream exists so the dot on an idle map
  /// is where the driver actually is — the whole point of the map working
  /// offline — not so it can steer a car. A 12 m filter keeps it honest at
  /// walking and city-driving speed while costing a fraction of the
  /// navigation stream's battery. Drive mode has its own, far tighter
  /// stream (see [NavigationConfig]) and this one stands down while it runs.
  static const int liveLocationDistanceFilterMeters = 12;

  /// Android's polling interval for the same stream. iOS derives its own
  /// cadence from the distance filter.
  static const Duration liveLocationInterval = Duration(seconds: 5);

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
  static const double driveManeuverWidth = 5;
  static const double simGhostWidth = 5;
  static const double simTrailWidth = 8;
}
