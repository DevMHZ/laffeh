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

/// The scalar part of a preview camera. Its geographic target continues to
/// come from the same route sample as the vehicle.
class PreviewCameraPose {
  final double zoom;
  final double tilt;
  final double bearing;

  const PreviewCameraPose({
    required this.zoom,
    required this.tilt,
    required this.bearing,
  });
}

/// Eases a preview's viewing angle without starting a second native camera
/// animation. Call [update] on the playback display clock, including while
/// paused, then apply its pose together with the vehicle's route position.
///
/// Zoom and tilt changes start a transition. A changing road heading updates
/// the endpoint of that transition without extending it; once settled, the
/// bearing follows the caller's already-smoothed [MotionHeading] directly.
/// Use `transition: true` once for a deliberate bearing-only view change.
class PreviewCameraMotion {
  final Duration duration;
  PreviewCameraPose? _from;
  PreviewCameraPose? _target;
  Duration _startedAt = Duration.zero;
  double _targetBearing = 0;

  PreviewCameraMotion({this.duration = const Duration(milliseconds: 400)})
    : assert(duration > Duration.zero);

  /// Seed from the actual native camera before entering a follow mode.
  void reset({
    required double zoom,
    required double tilt,
    required double bearing,
    required Duration elapsed,
  }) {
    _from = _target = PreviewCameraPose(
      zoom: zoom,
      tilt: tilt,
      bearing: bearing % 360,
    );
    _targetBearing = bearing % 360;
    _startedAt = elapsed - duration;
  }

  void clear() {
    _from = null;
    _target = null;
  }

  PreviewCameraPose update({
    required double zoom,
    required double tilt,
    required double bearing,
    required Duration elapsed,
    bool transition = false,
  }) {
    final previousTarget = _target;
    if (previousTarget == null) {
      reset(zoom: zoom, tilt: tilt, bearing: bearing, elapsed: elapsed);
      return _target!;
    }

    if (transition ||
        zoom != previousTarget.zoom ||
        tilt != previousTarget.tilt) {
      // Sample the old transition first: rapid reversals begin at the pose
      // currently on screen, never at the previous requested destination.
      _from = sample(elapsed)!;
      _targetBearing = _from!.bearing + _shortArc(_from!.bearing, bearing);
      _startedAt = elapsed;
    } else if (elapsed - _startedAt < duration) {
      // Keep this endpoint unwrapped. Recomputing its shortest arc from the
      // original bearing each frame would flip a half-complete transition
      // when the road heading crosses the opposite compass direction.
      _targetBearing += _shortArc(_targetBearing, bearing);
    } else {
      // Moving road headings already pass through MotionHeading. Applying
      // another 400 ms transition here would make the camera chase the car.
      _targetBearing = bearing % 360;
      _from = PreviewCameraPose(zoom: zoom, tilt: tilt, bearing: bearing % 360);
    }
    _target = PreviewCameraPose(zoom: zoom, tilt: tilt, bearing: bearing % 360);
    return sample(elapsed)!;
  }

  PreviewCameraPose? sample(Duration elapsed) {
    final from = _from;
    final target = _target;
    if (from == null || target == null) return null;
    final fraction =
        ((elapsed - _startedAt).inMicroseconds / duration.inMicroseconds).clamp(
          0.0,
          1.0,
        );
    if (fraction >= 1) return target;
    final eased = fraction * fraction * (3 - 2 * fraction);
    return PreviewCameraPose(
      zoom: from.zoom + (target.zoom - from.zoom) * eased,
      tilt: from.tilt + (target.tilt - from.tilt) * eased,
      bearing: (from.bearing + (_targetBearing - from.bearing) * eased) % 360,
    );
  }

  static double _shortArc(double from, double to) =>
      ((to - from + 540) % 360) - 180;
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
