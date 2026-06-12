import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class CenterPinWidget extends StatefulWidget {
  final Color color;
  const CenterPinWidget({super.key, required this.color});

  @override
  State<CenterPinWidget> createState() => _CenterPinWidgetState();
}

class _CenterPinWidgetState extends State<CenterPinWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => CustomPaint(
          painter: _CrosshairPainter(color: widget.color, pulse: _pulse.value),
        ),
      ),
    );
  }
}

class _CrosshairPainter extends CustomPainter {
  final Color color;
  final double pulse;

  _CrosshairPainter({required this.color, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);

    final outerR = 22.0 + pulse * 4.0;
    canvas.drawCircle(
      center,
      outerR,
      Paint()
        ..color = color.withValues(alpha: 0.06 + pulse * 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    canvas.drawCircle(
      center,
      11,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    const gap = 14.0;
    const len = 10.0;
    canvas.drawLine(
      Offset(cx, cy - gap),
      Offset(cx, cy - gap - len),
      linePaint,
    );
    canvas.drawLine(
      Offset(cx, cy + gap),
      Offset(cx, cy + gap + len),
      linePaint,
    );
    canvas.drawLine(
      Offset(cx - gap, cy),
      Offset(cx - gap - len, cy),
      linePaint,
    );
    canvas.drawLine(
      Offset(cx + gap, cy),
      Offset(cx + gap + len, cy),
      linePaint,
    );

    canvas.drawCircle(center, 3.5, Paint()..color = color);
    canvas.drawCircle(
      center,
      3.5,
      Paint()
        ..color = AppColors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_CrosshairPainter old) =>
      old.pulse != pulse || old.color != color;
}
