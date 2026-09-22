import 'dart:math' as math;

import '../../../../core/config/simulation_config.dart';
import '../../../../core/config/vehicle_marker_config.dart';

/// Interpolates authoritative playback samples on the display clock. The
/// vehicle and camera consume this same position, so neither can chase the
/// other on a separate animation. A pause or seek settles immediately.
class SimulationMotion {
  double _from = 0;
  double _target = 0;
  Duration _updatedAt = Duration.zero;
  bool _playing = false;
  bool _initialized = false;

  void update({
    required double progress,
    required bool playing,
    required Duration elapsed,
    bool reset = false,
  }) {
    final target = progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;
    if (!reset && _initialized && target == _target && playing == _playing) {
      return;
    }
    final snap = reset || !_initialized || !playing || target < _target;
    _from = snap ? target : sample(elapsed);
    _target = target;
    _updatedAt = elapsed;
    _playing = playing;
    _initialized = true;
  }

  double sample(Duration elapsed) {
    final fraction =
        ((elapsed - _updatedAt).inMicroseconds /
                SimulationConfig.tickInterval.inMicroseconds)
            .clamp(0.0, 1.0);
    return _from + (_target - _from) * fraction;
  }
}

/// Smooth shortest-arc turning independently of timer/display frequency.
class MotionHeading {
  double? _heading;
  Duration? _updatedAt;

  double update(double target, Duration elapsed) {
    final previous = _heading;
    final at = _updatedAt;
    _updatedAt = elapsed;
    if (previous == null || at == null || elapsed < at) {
      return _heading = target % 360;
    }
    final seconds = (elapsed - at).inMicroseconds / 1000000;
    final delta = ((target - previous + 540) % 360) - 180;
    final blend = 1 - math.exp(-seconds / 0.12);
    return _heading = (previous + delta * blend) % 360;
  }

  void reset() {
    _heading = null;
    _updatedAt = null;
  }
}

/// Avoids alternating adjacent baked images near a heading boundary.
/// The residual rotation still follows every frame while image swaps have
/// hysteresis and a minimum interval, preventing a pulsing silhouette.
class VehicleHeadingFrame {
  int? _frame;
  Duration? _changedAt;

  int select(double relativeHeading, Duration elapsed) {
    const step = VehicleMarkerConfig.headingStepDeg;
    final previous = _frame;
    final candidate =
        ((relativeHeading % 360) / step).round() %
        VehicleMarkerConfig.navSheetHeadings;
    if (previous == null) {
      _changedAt = elapsed;
      return _frame = candidate;
    }
    final difference = ((relativeHeading - previous * step + 540) % 360) - 180;
    final sinceChange = elapsed - _changedAt!;
    if (difference.abs() <= step / 2 + 1.5 ||
        sinceChange.inMilliseconds < VehicleMarkerConfig.minFrameSwapMs) {
      return previous;
    }
    _changedAt = elapsed;
    return _frame = candidate;
  }

  void reset() {
    _frame = null;
    _changedAt = null;
  }
}
