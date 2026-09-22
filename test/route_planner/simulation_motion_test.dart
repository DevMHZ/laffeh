import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/features/route_planner/presentation/utils/simulation_motion.dart';

void main() {
  group('shared simulation position', () {
    test('interpolates between samples without passing logical progress', () {
      final motion = SimulationMotion();
      motion.update(progress: 0, playing: true, elapsed: Duration.zero);
      motion.update(
        progress: 0.1,
        playing: true,
        elapsed: const Duration(milliseconds: 33),
      );
      expect(motion.sample(const Duration(milliseconds: 33)), 0);
      expect(
        motion.sample(const Duration(microseconds: 49500)),
        closeTo(0.05, 1e-10),
      );
      expect(motion.sample(const Duration(milliseconds: 66)), 0.1);
      expect(motion.sample(const Duration(seconds: 5)), 0.1);
    });

    test('jittered display frames and 8x samples never move backwards', () {
      final motion = SimulationMotion();
      var progress = 0.0;
      var rendered = 0.0;
      for (var ms = 0; ms < 500; ms++) {
        if (ms % 33 == 0) {
          progress += 33 / 45000 * 8;
          motion.update(
            progress: progress,
            playing: true,
            elapsed: Duration(milliseconds: ms),
          );
        }
        if (ms % 7 == 0 || ms % 17 == 0) {
          final next = motion.sample(Duration(milliseconds: ms));
          expect(next, inInclusiveRange(rendered, progress));
          rendered = next;
        }
      }
    });

    test('pause, forward seek, rewind and replay are exact', () {
      final motion = SimulationMotion();
      motion.update(progress: 0.3, playing: true, elapsed: Duration.zero);
      motion.update(
        progress: 0.4,
        playing: true,
        elapsed: const Duration(milliseconds: 33),
      );
      motion.update(
        progress: 0.4,
        playing: false,
        elapsed: const Duration(milliseconds: 40),
      );
      expect(motion.sample(const Duration(milliseconds: 40)), 0.4);
      expect(motion.sample(const Duration(seconds: 3)), 0.4);
      motion.update(
        progress: 0.9,
        playing: false,
        elapsed: const Duration(seconds: 4),
      );
      expect(motion.sample(const Duration(seconds: 4)), 0.9);
      motion.update(
        progress: 0.1,
        playing: false,
        elapsed: const Duration(seconds: 5),
      );
      expect(motion.sample(const Duration(seconds: 5)), 0.1);
      motion.update(
        progress: 0,
        playing: true,
        elapsed: const Duration(seconds: 6),
        reset: true,
      );
      expect(motion.sample(const Duration(seconds: 6)), 0);
    });

    test('unrelated camera states do not restart interpolation', () {
      final motion = SimulationMotion();
      motion.update(progress: 0, playing: true, elapsed: Duration.zero);
      motion.update(
        progress: 0.1,
        playing: true,
        elapsed: const Duration(milliseconds: 33),
      );
      motion.update(
        progress: 0.1,
        playing: true,
        elapsed: const Duration(milliseconds: 50),
      );
      expect(motion.sample(const Duration(milliseconds: 66)), 0.1);
    });
  });

  group('stable turning in 2D and 3D', () {
    test('turns by the shortest arc through north without oscillating', () {
      final heading = MotionHeading();
      expect(heading.update(359, Duration.zero), 359);
      final first = heading.update(1, const Duration(milliseconds: 33));
      expect(first, inInclusiveRange(359, 360));
      final settled = heading.update(1, const Duration(seconds: 2));
      expect(settled, closeTo(1, 0.001));
      heading.reset();
      expect(heading.update(180, const Duration(seconds: 3)), 180);
    });

    test('heading smoothing is independent of display frequency', () {
      final slow = MotionHeading()..update(0, Duration.zero);
      final fast = MotionHeading()..update(0, Duration.zero);
      var fastHeading = 0.0;
      for (var ms = 10; ms <= 100; ms += 10) {
        fastHeading = fast.update(90, Duration(milliseconds: ms));
      }
      expect(
        slow.update(90, const Duration(milliseconds: 100)),
        closeTo(fastHeading, 1e-9),
      );
    });

    test(
      'sprite boundary jitter keeps the same image while residual rotates',
      () {
        final frames = VehicleHeadingFrame();
        expect(frames.select(3, Duration.zero), 0);
        for (var ms = 100; ms <= 1000; ms += 100) {
          expect(
            frames.select(
              ms % 200 == 0 ? 3.5 : 4.2,
              Duration(milliseconds: ms),
            ),
            0,
          );
        }
        expect(frames.select(6, const Duration(milliseconds: 1100)), 1);
        expect(frames.select(14, const Duration(milliseconds: 1150)), 1);
        expect(frames.select(14, const Duration(milliseconds: 1200)), 2);
      },
    );

    test(
      'sprite hysteresis handles north wrap and resets between vehicles',
      () {
        final frames = VehicleHeadingFrame();
        expect(frames.select(359, Duration.zero), 0);
        expect(frames.select(-1, const Duration(milliseconds: 100)), 0);
        expect(frames.select(-7.5, const Duration(milliseconds: 200)), 47);
        frames.reset();
        expect(frames.select(180, const Duration(milliseconds: 201)), 24);
      },
    );
  });
}
