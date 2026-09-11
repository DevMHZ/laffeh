import 'dart:math' as math;

/// A coordinated follow view: close and readable near a stop, with more
/// road and perspective as speed rises. Distances are in metres.
class DrivingCameraPose {
  final double zoom;
  final double tilt;
  final double lookahead;
  final double anticipation;

  const DrivingCameraPose(
    this.zoom,
    this.tilt,
    this.lookahead,
    this.anticipation,
  );

  static const _speeds = [10.0, 40.0, 80.0, 120.0];
  static const _poses = [
    DrivingCameraPose(18.5, 38, 28, 14),
    DrivingCameraPose(17.4, 50, 65, 35),
    DrivingCameraPose(16.55, 58, 130, 65),
    DrivingCameraPose(15.8, 60, 210, 90),
  ];

  static DrivingCameraPose forSpeed(double? speedMps) {
    final kmh = speedMps != null && speedMps.isFinite
        ? (speedMps * 3.6).clamp(0.0, 120.0)
        : 0.0;
    if (kmh <= _speeds.first) return _poses.first;
    for (var i = 1; i < _speeds.length; i++) {
      if (kmh <= _speeds[i]) {
        final t = (kmh - _speeds[i - 1]) / (_speeds[i] - _speeds[i - 1]);
        return _poses[i - 1].toward(_poses[i], t);
      }
    }
    return _poses.last;
  }

  DrivingCameraPose toward(DrivingCameraPose other, double fraction) {
    final t = fraction.clamp(0.0, 1.0);
    double blend(double a, double b) => a + (b - a) * t;
    return DrivingCameraPose(
      blend(zoom, other.zoom),
      blend(tilt, other.tilt),
      blend(lookahead, other.lookahead),
      blend(anticipation, other.anticipation),
    );
  }

  /// A shorter viewport needs a shorter offset to keep the car in view.
  double lookaheadForViewport(double height) =>
      lookahead * (height / 850).clamp(0.35, 1.1);
}

/// Time-based easing keeps normal GPS (~1 Hz) and faster simulated fixes
/// equally smooth. The first fix of each trip uses the correct view at once.
class DrivingCameraSmoother {
  DrivingCameraPose? _pose;
  Duration? _lastUpdate;

  DrivingCameraPose update(double? speedMps, Duration elapsed) {
    final target = DrivingCameraPose.forSpeed(speedMps);
    final previous = _lastUpdate;
    _lastUpdate = elapsed;
    if (_pose == null || previous == null || elapsed < previous) {
      return _pose = target;
    }
    final seconds = (elapsed - previous).inMicroseconds / 1000000;
    return _pose = _pose!.toward(target, 1 - math.exp(-seconds / 1.4));
  }

  void reset() {
    _pose = null;
    _lastUpdate = null;
  }
}
