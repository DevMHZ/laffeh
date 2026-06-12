import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Inline circular loader (used inside cards / sheets).
class AppLoading extends StatelessWidget {
  final double size;
  final Color? color;
  final String? label;

  const AppLoading({super.key, this.size = 28, this.color, this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 2.6,
            valueColor: AlwaysStoppedAnimation(color ?? AppColors.primary),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 10),
          Text(label!, style: AppTextStyles.bodyMd),
        ],
      ],
    );
  }
}

/// Full-screen blocking overlay shown while the AI is computing
/// the optimized route.
class AppLoadingOverlay extends StatelessWidget {
  final String message;
  const AppLoadingOverlay({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.45),
        child: Center(
          child: Container(
            width: 260,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 32,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 120,
                  height: 120,
                  child: _RouteAIAnimation(),
                ),
                const SizedBox(height: 18),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleMd.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteAIAnimation extends StatefulWidget {
  const _RouteAIAnimation();

  @override
  State<_RouteAIAnimation> createState() => _RouteAIAnimationState();
}

class _RouteAIAnimationState extends State<_RouteAIAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _ring;
  late final AnimationController _pulse;
  late final AnimationController _trace;

  @override
  void initState() {
    super.initState();
    _ring = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _trace = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _ring.dispose();
    _pulse.dispose();
    _trace.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_ring, _pulse, _trace]),
      builder: (_, __) => CustomPaint(
        painter: _RouteAIPainter(
          rotation: _ring.value,
          pulse: _pulse.value,
          trace: _trace.value,
        ),
      ),
    );
  }
}

class _RouteAIPainter extends CustomPainter {
  final double rotation;
  final double pulse;
  final double trace;

  _RouteAIPainter({
    required this.rotation,
    required this.pulse,
    required this.trace,
  });

  static const _dotCount = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);
    final outerR = size.width * 0.44;
    final dotR = outerR * 0.68;

    _drawDashedRing(canvas, center, outerR);
    final dots = _computeDots(cx, cy, dotR);
    _drawRouteTrace(canvas, dots);
    _drawDots(canvas, dots);
    _drawCenterGlow(canvas, center);
    _drawSparkles(canvas, center);
  }

  List<Offset> _computeDots(double cx, double cy, double r) {
    return List.generate(_dotCount, (i) {
      final angle = (i / _dotCount) * 2 * math.pi - math.pi / 2;
      return Offset(cx + r * math.cos(angle), cy + r * math.sin(angle));
    });
  }

  void _drawDashedRing(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const dashes = 20;
    const dashAngle = 2 * math.pi / dashes;
    const gapRatio = 0.4;

    for (var i = 0; i < dashes; i++) {
      final start = rotation * 2 * math.pi + i * dashAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        dashAngle * (1 - gapRatio),
        false,
        paint,
      );
    }
  }

  void _drawRouteTrace(Canvas canvas, List<Offset> dots) {
    final path = Path()..moveTo(dots[0].dx, dots[0].dy);
    final segLen = 1.0 / _dotCount;

    for (var i = 0; i < _dotCount; i++) {
      final segStart = i * segLen;
      final segEnd = segStart + segLen;
      final next = dots[(i + 1) % _dotCount];

      if (trace <= segStart) break;
      if (trace >= segEnd) {
        path.lineTo(next.dx, next.dy);
      } else {
        final t = (trace - segStart) / segLen;
        path.lineTo(
          dots[i].dx + (next.dx - dots[i].dx) * t,
          dots[i].dy + (next.dy - dots[i].dy) * t,
        );
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.accent.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawDots(Canvas canvas, List<Offset> dots) {
    for (final d in dots) {
      canvas.drawCircle(d, 3.5, Paint()..color = AppColors.accent);
      canvas.drawCircle(
        d,
        3.5,
        Paint()
          ..color = AppColors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
  }

  void _drawCenterGlow(Canvas canvas, Offset center) {
    final glowR = 10.0 + pulse * 5.0;
    canvas.drawCircle(
      center,
      glowR,
      Paint()..color = AppColors.primary.withValues(alpha: 0.06 + pulse * 0.06),
    );
    canvas.drawCircle(center, 6, Paint()..color = AppColors.primary);
    canvas.drawCircle(
      center,
      6,
      Paint()
        ..color = AppColors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawSparkles(Canvas canvas, Offset center) {
    final angle = rotation * 2 * math.pi;
    final paint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.35)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 4; i++) {
      final a = angle + i * math.pi / 2;
      canvas.drawLine(
        Offset(center.dx + 9 * math.cos(a), center.dy + 9 * math.sin(a)),
        Offset(center.dx + 14 * math.cos(a), center.dy + 14 * math.sin(a)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RouteAIPainter old) =>
      old.rotation != rotation || old.pulse != pulse || old.trace != trace;
}
