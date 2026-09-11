import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/config/driving_camera.dart';

void main() {
  test('stopped and unreliable speeds keep a close, calm view', () {
    for (final speed in <double?>[
      null,
      0,
      -1,
      double.nan,
      double.infinity,
      2,
    ]) {
      final pose = DrivingCameraPose.forSpeed(speed);
      expect(pose.zoom, greaterThanOrEqualTo(18));
      expect(pose.tilt, inInclusiveRange(30, 45));
      expect(pose.lookahead, lessThan(40));
      expect(pose.anticipation, lessThan(20));
    }
  });

  test('accelerating gradually reveals more road without camera jumps', () {
    var previous = DrivingCameraPose.forSpeed(0);
    for (var kmh = 1; kmh <= 160; kmh++) {
      final pose = DrivingCameraPose.forSpeed(kmh / 3.6);
      expect(pose.zoom, lessThanOrEqualTo(previous.zoom));
      expect(pose.tilt, greaterThanOrEqualTo(previous.tilt));
      expect(pose.lookahead, greaterThanOrEqualTo(previous.lookahead));
      expect(pose.anticipation, greaterThanOrEqualTo(previous.anticipation));
      expect((pose.zoom - previous.zoom).abs(), lessThan(0.04));
      expect((pose.tilt - previous.tilt).abs(), lessThan(0.5));
      expect(pose.zoom, inInclusiveRange(15, 19));
      expect(pose.tilt, lessThanOrEqualTo(60));
      previous = pose;
    }
  });

  test('short screens reduce the forward offset at every speed', () {
    for (final speed in [0, 20, 40, 80, 120]) {
      final pose = DrivingCameraPose.forSpeed(speed / 3.6);
      final portrait = pose.lookaheadForViewport(850);
      final landscape = pose.lookaheadForViewport(390);
      expect(landscape / portrait, closeTo(390 / 850, 0.001));
      expect(
        pose.lookaheadForViewport(1600),
        lessThanOrEqualTo(portrait * 1.1),
      );
      expect(pose.lookaheadForViewport(0), greaterThan(0));
    }
  });

  test('smoothing is independent of GPS update frequency', () {
    final slow = DrivingCameraSmoother();
    final fast = DrivingCameraSmoother();
    slow.update(0, Duration.zero);
    fast.update(0, Duration.zero);
    var a = DrivingCameraPose.forSpeed(0);
    var b = a;
    for (var ms = 100; ms <= 3000; ms += 100) {
      b = fast.update(30, Duration(milliseconds: ms));
      if (ms % 1000 == 0) a = slow.update(30, Duration(milliseconds: ms));
    }
    expect(a.zoom, closeTo(b.zoom, 1e-9));
    expect(a.tilt, closeTo(b.tilt, 1e-9));
    expect(a.lookahead, closeTo(b.lookahead, 1e-9));
    expect(a.anticipation, closeTo(b.anticipation, 1e-9));
    expect(a.zoom, greaterThan(DrivingCameraPose.forSpeed(30).zoom));
    expect(a.zoom, lessThan(DrivingCameraPose.forSpeed(0).zoom));
  });

  test(
    'braking converges without overshoot; a new trip resets immediately',
    () {
      final camera = DrivingCameraSmoother();
      camera.update(30, Duration.zero);
      var previous = camera.update(0, const Duration(seconds: 1));
      final target = DrivingCameraPose.forSpeed(0);
      for (var second = 2; second <= 12; second++) {
        final pose = camera.update(0, Duration(seconds: second));
        expect(pose.zoom, inInclusiveRange(previous.zoom, target.zoom));
        expect(pose.tilt, inInclusiveRange(target.tilt, previous.tilt));
        previous = pose;
      }
      expect(previous.zoom, closeTo(target.zoom, 0.001));
      camera.reset();
      final first = camera.update(30, const Duration(seconds: 13));
      expect(first.zoom, DrivingCameraPose.forSpeed(30).zoom);
      // Duplicate or out-of-order time cannot create a NaN or extrapolate.
      expect(camera.update(0, const Duration(seconds: 13)).zoom, first.zoom);
      expect(camera.update(0, Duration.zero).zoom, target.zoom);
    },
  );
}
