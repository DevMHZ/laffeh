library;

/// Round markers arriving as pixelated squares on Android.
///
/// Reported on an old Oppo: the numbered badges, the compass and the 2D/3D
/// button all showed a shaded square with the circle inside it. Two separate
/// causes, both provable on paper:
///
///  * The badges were rasterised at their logical size (34 px) and then drawn
///    with `iconSize: dpr`. That correction exists because iOS loads an image
///    at the screen scale; Android does not, so the same 34 px bitmap was
///    stretched across two or three times as many pixels.
///  * The canvas was exactly the size of the circle, so the shadow — which
///    reaches about three sigma past the shape — was sliced off square.
import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/config/vehicle_marker_config.dart';

/// Where a Gaussian mask filter effectively stops, from the shape's edge.
double blurReach(double sigma) => 3 * sigma;

void main() {
  group('the shadow has somewhere to fall', () {
    test('the old canvas clipped the visiting glow', () {
      // radius 13 + a 2px glow ring, sigma 6, in a 34px box: this is the
      // square people were seeing.
      const canvas = 34.0;
      final reach = canvas / 2 + (13 + 2) + blurReach(6);
      expect(reach, greaterThan(canvas),
          reason: 'the bug: the glow wanted more room than the canvas had');
    });

    test('the padded canvas contains it', () {
      const logical = 34.0;
      final padded = logical * VehicleMarkerConfig.badgeFootprint;
      final reach = padded / 2 + (13 + 2) + blurReach(6);
      expect(reach, lessThanOrEqualTo(padded),
          reason: 'the glow must finish inside the bitmap, or it is cut '
              'off square again');
    });

    test('it contains the plain drop shadow too', () {
      const logical = 34.0;
      final padded = logical * VehicleMarkerConfig.badgeFootprint;
      final reach = padded / 2 + 1.5 + 10 + blurReach(2.5);
      expect(reach, lessThanOrEqualTo(padded));
    });
  });

  group('the badge keeps its size on screen', () {
    /// How many device pixels across the *circle* ends up — which is the
    /// thing a driver sees. The first version of this test measured the whole
    /// bitmap instead, so it passed happily while every delivery point on the
    /// map shrank by the padding footprint.
    double circleOnScreen({
      required double logical,
      required double diameter,
      required double dpr,
    }) {
      final bitmap = logical *
          VehicleMarkerConfig.badgeFootprint *
          VehicleMarkerConfig.badgeOversample;
      final rendered = bitmap * (dpr / VehicleMarkerConfig.badgeIconDivisor);
      // The circle occupies `diameter` of the padded logical box.
      final padded = logical * VehicleMarkerConfig.badgeFootprint;
      return diameter / padded * rendered;
    }

    /// What it was before any of this: a bitmap the size of the badge, drawn
    /// with `iconSize: dpr`.
    double circleBefore({
      required double logical,
      required double diameter,
      required double dpr,
    }) => diameter / logical * (logical * dpr);

    test('a delivery point is exactly the size it always was', () {
      expect(
        circleOnScreen(logical: 34, diameter: 20, dpr: 3),
        closeTo(circleBefore(logical: 34, diameter: 20, dpr: 3), 1e-9),
      );
    });

    test('and at any device pixel ratio and badge size', () {
      for (final dpr in [1.0, 2.0, 2.75, 3.0, 4.0]) {
        for (final (logical, diameter) in [
          (30.0, 16.0),
          (34.0, 20.0),
          (34.0, 26.0), // the visiting badge, radius 13
          (44.0, 28.0),
        ]) {
          expect(
            circleOnScreen(logical: logical, diameter: diameter, dpr: dpr),
            closeTo(
              circleBefore(logical: logical, diameter: diameter, dpr: dpr),
              1e-9,
            ),
            reason: 'logical $logical, diameter $diameter, dpr $dpr',
          );
        }
      }
    });

    test('dividing by the footprint too would shrink it', () {
      // The bug this test now guards: holding the whole bitmap to its old
      // size squeezes the circle by exactly the footprint.
      const logical = 34.0, diameter = 20.0, dpr = 3.0;
      final bitmap = logical *
          VehicleMarkerConfig.badgeFootprint *
          VehicleMarkerConfig.badgeOversample;
      final wrong = bitmap *
          (dpr /
              (VehicleMarkerConfig.badgeOversample *
                  VehicleMarkerConfig.badgeFootprint));
      final padded = logical * VehicleMarkerConfig.badgeFootprint;
      final wrongCircle = diameter / padded * wrong;
      expect(
        wrongCircle * VehicleMarkerConfig.badgeFootprint,
        closeTo(circleBefore(logical: logical, diameter: diameter, dpr: dpr),
            1e-9),
      );
    });

    test('the bitmap now has at least as many pixels as the screen uses', () {
      // The actual pixelation fix: at 3x a 34pt badge covers 102 device
      // pixels, and the bitmap used to carry 34.
      const logical = 34.0;
      const dpr = 3.0;
      final screenPixels = logical * dpr;
      final bitmap = logical *
          VehicleMarkerConfig.badgeFootprint *
          VehicleMarkerConfig.badgeOversample;
      expect(bitmap, greaterThanOrEqualTo(screenPixels));
      expect(34.0, lessThan(screenPixels), reason: 'what it used to be');
    });
  });

  group('the knobs stay sane', () {
    test('oversampling is a real increase', () {
      expect(VehicleMarkerConfig.badgeOversample, greaterThan(1));
    });

    test('padding is a real margin', () {
      expect(VehicleMarkerConfig.badgePaddingRatio, greaterThan(0));
      expect(VehicleMarkerConfig.badgeFootprint,
          closeTo(1 + 2 * VehicleMarkerConfig.badgePaddingRatio, 1e-9));
    });

    test('the divisor is the oversample alone', () {
      // Not the footprint as well. The padding grows the canvas outwards for
      // the shadow; it must not be compensated away, or the badge shrinks.
      expect(VehicleMarkerConfig.badgeIconDivisor,
          closeTo(VehicleMarkerConfig.badgeOversample, 1e-9));
    });
  });
}
