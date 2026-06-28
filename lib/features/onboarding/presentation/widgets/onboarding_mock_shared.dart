part of 'onboarding_mock.dart';

// ─────────────────────────────────────────────────────────────────────
// Shared bits
// ─────────────────────────────────────────────────────────────────────

/// A teardrop map pin with a white outline, sized to [size].
class _MockPin extends StatelessWidget {
  final Color color;
  final double size;
  const _MockPin({required this.color, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.location_on, size: size, color: AppColors.white),
          Icon(Icons.location_on, size: size * 0.8, color: color),
        ],
      ),
    );
  }
}

/// Soft mini-map: parks, blocks and a couple of roads. Pure paint, no
/// tiles — enough to read as "a map" behind the pins.
class _MapBackdrop extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEDF1E8),
    );

    final park = Paint()..color = AppColors.primarySoft;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.52,
          size.height * 0.08,
          size.width * 0.42,
          size.height * 0.24,
        ),
        const Radius.circular(12),
      ),
      park,
    );

    final block = Paint()..color = const Color(0xFFE1E8DA);
    final blocks = [
      Rect.fromLTWH(
        size.width * 0.06,
        size.height * 0.10,
        size.width * 0.32,
        size.height * 0.18,
      ),
      Rect.fromLTWH(
        size.width * 0.08,
        size.height * 0.58,
        size.width * 0.36,
        size.height * 0.22,
      ),
      Rect.fromLTWH(
        size.width * 0.58,
        size.height * 0.62,
        size.width * 0.34,
        size.height * 0.24,
      ),
    ];
    for (final r in blocks) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(9)),
        block,
      );
    }

    final road = Paint()
      ..color = AppColors.white
      ..strokeWidth = size.width * 0.055
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, size.height * 0.46),
      Offset(size.width, size.height * 0.5),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.5, 0),
      Offset(size.width * 0.45, size.height),
      road,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Strokes a polyline through [points] (normalised 0..1), revealing
/// [progress] of its length.
class _RouteLinePainter extends CustomPainter {
  final List<Offset> points;
  final double progress;
  final Color color;

  _RouteLinePainter({
    required this.points,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || progress <= 0) return;
    final abs = points
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();
    final path = Path()..moveTo(abs.first.dx, abs.first.dy);
    for (var i = 1; i < abs.length; i++) {
      path.lineTo(abs[i].dx, abs[i].dy);
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final m in path.computeMetrics()) {
      canvas.drawPath(
        m.extractPath(0, m.length * progress.clamp(0.0, 1.0)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RouteLinePainter old) =>
      old.progress != progress || old.color != color;
}

double _loopFade(double t) {
  if (t < 0.05) return t / 0.05;
  if (t > 0.93) return ((1 - t) / 0.07).clamp(0.0, 1.0);
  return 1.0;
}
