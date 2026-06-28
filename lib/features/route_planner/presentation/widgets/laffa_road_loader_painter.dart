part of 'laffa_road_loader.dart';

/// One fading exhaust puff.
class _Puff {
  final double x, y, born, r0, life, drift;
  _Puff(this.x, this.y, this.born, math.Random rng)
      : r0 = 2.5 + rng.nextDouble() * 2,
        life = 650 + rng.nextDouble() * 350,
        drift = 4 + rng.nextDouble() * 5;
}

class _ScenePainter extends CustomPainter {
  final _LaffaRoadLoaderState s;
  _ScenePainter(this.s);

  // Pin anchors (tip) in bitmap coordinates (shifted down by _yShift at use).
  static const _pinBlue = Offset(227, 328);
  static const _pinRed = Offset(372, 327);
  static const _pinOrange = Offset(720, 325);

  // Bridge crossings (bitmap coords) where the road passes over the car.
  static const _bridge1 = Rect.fromLTWH(690.0 - 117.9, 632.0 - 74.0, 117.9 * 2, 74.0 * 2);
  static const _bridge2 = Rect.fromLTWH(435.0 - 109.9, 577.0 - 92.3, 109.9 * 2, 92.3 * 2);

  @override
  void paint(Canvas canvas, Size size) {
    final road = s._road;
    if (road == null) return;

    final shift = s._yShift;
    final scale = size.width / _imgSize.width;
    canvas.save();
    canvas.scale(scale);

    // Bitmap sits below the procedural tail.
    final dst = Rect.fromLTWH(0, shift, _imgSize.width, _imgSize.height);
    final src = Rect.fromLTWH(0, 0, road.width.toDouble(), road.height.toDouble());
    final imgPaint = Paint()..filterQuality = FilterQuality.high;

    // 1. The lengthened tail (procedural), then the road bitmap on top of it so
    // the bitmap's own top edge hides the seam.
    if (shift > 0) _drawTail(canvas, shift);
    canvas.drawImageRect(road, src, dst, imgPaint);

    final now = s._nowMs;
    final phase = now % s._cycleMs;
    final driving = phase < s._driveMs;
    final p = driving ? phase / s._driveMs : 1.0;

    // 2. Exhaust puffs (behind the car).
    for (final pf in s._puffs) {
      final age = (now - pf.born) / pf.life;
      if (age < 0 || age >= 1) continue;
      final r = pf.r0 + age * 14;
      final o = (1 - age) * 0.42;
      canvas.drawCircle(
        Offset(pf.x - age * pf.drift, pf.y - age * 12),
        r,
        Paint()..color = const Color(0xFF5C5F5A).withValues(alpha: o),
      );
    }

    // 3. Pins (pop up, above road, below car).
    _drawPin(canvas, _pinOrange.translate(0, shift), AppColors.pinOrange, s._orangeShown, now);
    _drawPin(canvas, _pinRed.translate(0, shift), AppColors.pinRed, s._redShown, now);
    _drawPin(canvas, _pinBlue.translate(0, shift), AppColors.pinBlue, s._blueShown, now);

    // 4. The car.
    if (driving) {
      final tan = s._metric.getTangentForOffset(p * s._len)!;
      var op = 1.0;
      if (p < 0.03) op = p / 0.03;
      if (p >= s._tunnels[1][0]) {
        op = math.max(0, 1 - (p - s._tunnels[1][0]) / 0.03);
      }
      if (op > 0) {
        canvas.save();
        canvas.translate(tan.position.dx, tan.position.dy);
        canvas.rotate(math.atan2(tan.vector.dy, tan.vector.dx));
        _drawCar(canvas, op);
        canvas.restore();
      }

      // 5. Over-pass: re-draw the road on top of the car at active crossings.
      const mg = 0.02;
      final t1 = s._tunnels[0], t2 = s._tunnels[1];
      if (p > t1[0] - mg && p < t1[1] + mg) {
        _overpass(canvas, road, src, dst, imgPaint, _bridge1.translate(0, shift));
      }
      if (p > t2[0] - mg && p < t2[1] + mg) {
        _overpass(canvas, road, src, dst, imgPaint, _bridge2.translate(0, shift));
      }
    }

    canvas.restore();
  }

  void _overpass(Canvas canvas, ui.Image road, Rect src, Rect dst, Paint paint,
      Rect clip) {
    canvas.save();
    canvas.clipRect(clip);
    canvas.drawImageRect(road, src, dst, paint);
    canvas.restore();
  }

  // Colours and edges measured from the bitmap's straight tail so the drawn
  // extension is indistinguishable from it.
  static const _tailAsphalt = Color(0xFF363634); // rgb(54,54,52)
  static const _tailWhite = Color(0xFFF7F8F4); // rgb(247,248,244)

  /// Paints the lengthened straight tail above the bitmap (canvas y in
  /// [0, shift]). The bitmap occupies y >= shift, so a bitmap row at y' maps to
  /// tail coordinate y' - shift; the centre dashes continue that pattern.
  void _drawTail(Canvas canvas, double shift) {
    const haloL = 950.0, haloR = 1082.0; // white outline halo
    const roadL = 962.0, roadR = 1070.0; // asphalt body
    const dashL = 1007.0, dashR = 1025.0; // centre lane dash

    canvas.drawRect(
      Rect.fromLTRB(haloL, 0, haloR, shift + 2),
      Paint()..color = _tailWhite,
    );
    canvas.drawRect(
      Rect.fromLTRB(roadL, 0, roadR, shift + 2),
      Paint()..color = _tailAsphalt,
    );

    // Centre dashes: in bitmap rows a white dash starts at y=36 with period 106
    // and length 52. Continue that upward into the tail.
    const period = 106.0, dashLen = 52.0, firstWhite = 36.0;
    final dashPaint = Paint()..color = _tailWhite;
    final kStart = ((-shift - dashLen - firstWhite) / period).floor() - 1;
    final kEnd = ((-firstWhite) / period).ceil() + 1;
    for (var k = kStart; k <= kEnd; k++) {
      final yTop = firstWhite + k * period + shift; // canvas y of dash top
      final t = math.max(0.0, yTop);
      final b = math.min(shift, yTop + dashLen);
      if (b <= t) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(dashL, t, dashR, b),
          const Radius.circular(9),
        ),
        dashPaint,
      );
    }
  }

  void _drawPin(Canvas canvas, Offset tip, Color color, double? shownAt, double now) {
    if (shownAt == null) return;
    final elapsed = now - shownAt;
    final pop = (elapsed / 500).clamp(0.0, 1.0);
    final scale = Curves.elasticOut.transform(pop);
    final opacity = (elapsed / 250).clamp(0.0, 1.0);
    if (scale <= 0.001) return;

    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.scale(scale); // origin at the tip (50% 100%)

    // Tear-drop body: M0,0 L-42.9,-62.6 A52,52 (large, sweep) to 42.9,-62.6 Z
    final body = Path()
      ..moveTo(0, 0)
      ..lineTo(-42.9, -62.6)
      ..arcToPoint(
        const Offset(42.9, -62.6),
        radius: const Radius.circular(52),
        largeArc: true,
        clockwise: true,
      )
      ..close();

    canvas.drawPath(
      body,
      Paint()..color = color.withValues(alpha: opacity),
    );
    canvas.drawPath(
      body,
      Paint()
        ..color = AppColors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9,
    );
    canvas.drawCircle(
      const Offset(0, -92),
      19,
      Paint()..color = AppColors.white.withValues(alpha: opacity),
    );
    canvas.restore();
  }

  /// Top-down car, pointing +x (direction of travel). Ported from the source
  /// SVG. [op] applies the fade-in / dive-under-for-good opacity.
  void _drawCar(Canvas canvas, double op) {
    RRect rr(double x, double y, double w, double h, double r) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));
    Color c(Color base) => base.withValues(alpha: op);

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 84, height: 52),
      Paint()..color = AppColors.black.withValues(alpha: 0.18 * op),
    );
    // Wheels
    final wheel = Paint()..color = c(const Color(0xFF1C1C1C));
    for (final r in [
      rr(-25, -21, 14, 9, 3),
      rr(-25, 12, 14, 9, 3),
      rr(14, -21, 14, 9, 3),
      rr(14, 12, 14, 9, 3),
    ]) {
      canvas.drawRRect(r, wheel);
    }
    // Body
    canvas.drawRRect(rr(-38, -19, 76, 38, 14), Paint()..color = c(const Color(0xFFE23B2F)));
    canvas.drawRRect(
      rr(-38, -19, 76, 38, 14),
      Paint()
        ..color = c(const Color(0xFFB22A20))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Roof
    canvas.drawRRect(rr(-26, -14, 50, 28, 9), Paint()..color = c(const Color(0xFFCF3127)));
    // Wind-screen + rear window
    canvas.drawRRect(rr(13, -12, 11, 24, 4), Paint()..color = c(const Color(0xFF222633)));
    canvas.drawRRect(rr(-22, -12, 9, 24, 4), Paint()..color = c(const Color(0xFF222633)));
    // Centre seam
    canvas.drawRect(
      const Rect.fromLTWH(-6, -13, 2.5, 26),
      Paint()..color = c(const Color(0xFFB22A20)),
    );
    // Head-lights
    final hl = Paint()..color = c(const Color(0xFFFFE7A3));
    canvas.drawCircle(const Offset(34, -11), 4, hl);
    canvas.drawCircle(const Offset(34, 11), 4, hl);
    // Tail nub
    canvas.drawRRect(rr(-39, -9, 3, 6, 1.5), Paint()..color = c(const Color(0xFFD23B2F)));
  }

  @override
  bool shouldRepaint(_ScenePainter old) => true;
}
