part of 'splash_page.dart';

/// Three bouncing dots in the logo-pin colors.
class _PinDots extends StatelessWidget {
  final double phase;
  const _PinDots({required this.phase});

  static final _colors = [AppColors.pinBlue, AppColors.pinRed, AppColors.pinOrange];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final t = (phase + i * 0.18) % 1.0;
        // Quick hop with a soft landing.
        final hop = math.sin((t.clamp(0.0, 0.5) / 0.5) * math.pi);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Transform.translate(
            offset: Offset(0, -7 * hop),
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: _colors[i],
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.white, width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.asphaltDark.withValues(alpha: 0.25),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// A miniature of the product: a car drives along an asphalt road and
/// a pin pops up (with a bounce) at every stop it passes.
///
/// [trip] 0→1 is the car's journey across the screen; [dashPhase]
/// continuously scrolls the lane dashes so the road feels alive even
/// while the car eases.
class _RoadTripPainter extends CustomPainter {
  final double trip;
  final double dashPhase;

  _RoadTripPainter({required this.trip, required this.dashPhase});

  static final _pinColors = [AppColors.pinBlue, AppColors.pinRed, AppColors.pinOrange];
  // Stops along the road (fraction of width).
  static const _stops = [0.28, 0.52, 0.76];

  @override
  void paint(Canvas canvas, Size size) {
    final roadY = size.height - 34;
    const roadH = 30.0;

    // ── Road bed ──
    final roadRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(-4, roadY - roadH / 2, size.width + 8, roadH),
      const Radius.circular(15),
    );
    canvas.drawRRect(
      roadRect.shift(const Offset(0, 3)),
      Paint()..color = AppColors.asphaltDark.withValues(alpha: 0.25),
    );
    canvas.drawRRect(roadRect, Paint()..color = AppColors.asphalt);

    // ── Scrolling center dashes ──
    final dashPaint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.92)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const dashLen = 16.0, gap = 14.0, period = dashLen + gap;
    final offset = -dashPhase * period;
    for (var x = offset - period; x < size.width + period; x += period) {
      canvas.drawLine(Offset(x, roadY), Offset(x + dashLen, roadY), dashPaint);
    }

    // ── Pins pop up after the car passes their stop ──
    final carX = _carX(size.width);
    for (var i = 0; i < _stops.length; i++) {
      final stopX = _stops[i] * size.width;
      if (carX < stopX) continue;
      // 0→1 pop driven by how far past the stop the car is.
      final pop = ((carX - stopX) / 60).clamp(0.0, 1.0);
      final bounce = Curves.elasticOut.transform(pop);
      _drawPin(canvas, Offset(stopX, roadY - roadH / 2 - 6), bounce, _pinColors[i]);
    }

    // ── The car ──
    if (trip > 0 && trip < 1) {
      final bob = math.sin(dashPhase * 6 * math.pi) * 1.2;
      _drawCar(canvas, Offset(carX, roadY - roadH / 2 - 1 + bob));
    }
  }

  double _carX(double width) => trip * (width + 160) - 80;

  void _drawPin(Canvas canvas, Offset base, double t, Color color) {
    if (t <= 0.01) return;
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.scale(t);

    const h = 26.0, r = 9.0;
    final body = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-r * 1.15, -h * 0.45, -r, -h + r)
      ..arcTo(
        Rect.fromCircle(center: const Offset(0, -h + r), radius: r),
        math.pi,
        math.pi,
        false,
      )
      ..quadraticBezierTo(r * 1.15, -h * 0.45, 0, 0)
      ..close();

    canvas.drawPath(
      body.shift(const Offset(0, 2)),
      Paint()..color = AppColors.asphaltDark.withValues(alpha: 0.2),
    );
    canvas.drawPath(body, Paint()..color = color);
    canvas.drawPath(
      body,
      Paint()
        ..color = AppColors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      const Offset(0, -h + r),
      r * 0.42,
      Paint()..color = AppColors.white,
    );
    canvas.restore();
  }

  void _drawCar(Canvas canvas, Offset ground) {
    canvas.save();
    canvas.translate(ground.dx, ground.dy);

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 1), width: 46, height: 6),
      Paint()..color = AppColors.asphaltDark.withValues(alpha: 0.25),
    );

    // Body
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, -11), width: 44, height: 14),
      const Radius.circular(6),
    );
    canvas.drawRRect(body, Paint()..color = AppColors.white);

    // Cabin
    final cabin = RRect.fromRectAndCorners(
      Rect.fromCenter(center: const Offset(-2, -21), width: 24, height: 11),
      topLeft: const Radius.circular(7),
      topRight: const Radius.circular(7),
    );
    canvas.drawRRect(cabin, Paint()..color = AppColors.white);

    // Windows
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(-8, -20.5), width: 9, height: 7),
        const Radius.circular(2),
      ),
      Paint()..color = AppColors.pinBlue.withValues(alpha: 0.85),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(3, -20.5), width: 9, height: 7),
        const Radius.circular(2),
      ),
      Paint()..color = AppColors.pinBlue.withValues(alpha: 0.85),
    );

    // Headlight
    canvas.drawCircle(
      const Offset(20, -12),
      2.2,
      Paint()..color = AppColors.pinOrange,
    );

    // Wheels (spin with the dashes)
    for (final wx in const [-13.0, 13.0]) {
      canvas.drawCircle(Offset(wx, -3), 5.5, Paint()..color = AppColors.asphaltDark);
      canvas.drawCircle(Offset(wx, -3), 2.4, Paint()..color = AppColors.white);
      final spoke = dashPhase * 2 * math.pi * 3;
      canvas.drawLine(
        Offset(wx + 2.4 * math.cos(spoke), -3 + 2.4 * math.sin(spoke)),
        Offset(wx - 2.4 * math.cos(spoke), -3 - 2.4 * math.sin(spoke)),
        Paint()
          ..color = AppColors.asphaltDark
          ..strokeWidth = 1.2,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_RoadTripPainter old) =>
      old.trip != trip || old.dashPhase != dashPhase;
}
