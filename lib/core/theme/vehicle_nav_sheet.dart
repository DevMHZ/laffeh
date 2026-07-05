import 'dart:ui';

import '../config/vehicle_marker_config.dart';

/// Pure frame math for the nav sprite sheets baked by
/// tool/bake_vehicle_sprites (48 headings × 4 phases, row-major,
/// frame 0 = nose up, headings clockwise).
///
/// All angles here are the *relative* heading — vehicle bearing minus
/// camera bearing, i.e. clockwise degrees from screen-up — which is
/// exactly the rotation every map mode already computes today.
class VehicleNavSheet {
  VehicleNavSheet._();

  static const int headings = VehicleMarkerConfig.navSheetHeadings;
  static const int phases = VehicleMarkerConfig.navSheetPhases;
  static const int cols = VehicleMarkerConfig.navSheetCols;
  static const double _step = VehicleMarkerConfig.headingStepDeg;

  /// Index of the baked heading nearest to [relativeDeg].
  static int headingIndex(double relativeDeg) {
    final norm = ((relativeDeg % 360) + 360) % 360;
    return (norm / _step).round() % headings;
  }

  /// Signed leftover rotation (degrees, ±[_step]/2) after snapping
  /// [relativeDeg] to [headingIndex] — applied as a plain 2D rotation on
  /// top of the frame so turning stays perfectly smooth.
  static double residualDeg(double relativeDeg) {
    final norm = ((relativeDeg % 360) + 360) % 360;
    final snapped = headingIndex(relativeDeg) * _step;
    return ((norm - snapped + 540) % 360) - 180;
  }

  /// Source rect of the ([heading], [phase]) cell inside the sheet image.
  /// Uses the actual image width so the math survives a re-bake at a
  /// different frame size.
  static Rect frameRect(Image sheet, int heading, int phase) {
    final fw = sheet.width / cols;
    final fh = fw; // square frames
    final i = heading * phases + phase;
    return Rect.fromLTWH((i % cols) * fw, (i ~/ cols) * fh, fw, fh);
  }

}
