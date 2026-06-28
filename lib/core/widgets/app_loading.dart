import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'fun_loading_animations.dart';

/// Inline loader (used inside cards / sheets).
///
/// Renders a [LaffahLoader] — a miniature of the logo: a circular
/// road loop whose lane dashes drive around it, with a pin perched
/// on top — instead of a stock spinner.
class AppLoading extends StatelessWidget {
  final double size;
  final Color? color;
  final String? label;

  const AppLoading({super.key, this.size = 36, this.color, this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LaffahLoader(size: size, pinColor: color),
        if (label != null) ...[
          const SizedBox(height: 10),
          Text(label!, style: AppTextStyles.bodyMd),
        ],
      ],
    );
  }
}

/// A circular road-loop (straight from the logo) used as a spinner:
/// the white lane dashes travel around the asphalt ring while a map
/// pin bobs on top.
class LaffahLoader extends StatefulWidget {
  final double size;
  final Color? pinColor;

  const LaffahLoader({super.key, this.size = 36, this.pinColor});

  @override
  State<LaffahLoader> createState() => _LaffahLoaderState();
}

class _LaffahLoaderState extends State<LaffahLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Extra headroom above the ring so the pin isn't clipped.
    final h = widget.size * 1.34;
    return SizedBox(
      width: widget.size,
      height: h,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => CustomPaint(
          painter: _LaffahLoaderPainter(
            phase: _ctrl.value,
            pinColor: widget.pinColor ?? AppColors.pinRed,
          ),
        ),
      ),
    );
  }
}

class _LaffahLoaderPainter extends CustomPainter {
  final double phase;
  final Color pinColor;

  _LaffahLoaderPainter({required this.phase, required this.pinColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final ringR = size.width * 0.36;
    final cy = size.height - ringR - size.width * 0.12;
    final center = Offset(cx, cy);
    final roadW = size.width * 0.22;

    // Asphalt ring (the road loop).
    canvas.drawCircle(
      center,
      ringR,
      Paint()
        ..color = AppColors.asphalt
        ..style = PaintingStyle.stroke
        ..strokeWidth = roadW,
    );

    // Lane dashes driving around the loop.
    final dashPaint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = roadW * 0.22
      ..strokeCap = StrokeCap.round;
    const dashes = 7;
    const sweep = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      final start = phase * 2 * math.pi + i * sweep;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ringR),
        start,
        sweep * 0.55,
        false,
        dashPaint,
      );
    }

    // Pin bobbing on top of the loop.
    final bob = math.sin(phase * 2 * math.pi) * size.width * 0.04;
    final pinBase = Offset(cx, cy - ringR - roadW * 0.4 + bob);
    final pinH = size.width * 0.34;
    final headR = pinH * 0.38;

    final body = Path()
      ..moveTo(pinBase.dx, pinBase.dy)
      ..quadraticBezierTo(
        pinBase.dx - headR * 1.15,
        pinBase.dy - pinH * 0.45,
        pinBase.dx - headR,
        pinBase.dy - pinH + headR,
      )
      ..arcTo(
        Rect.fromCircle(
          center: Offset(pinBase.dx, pinBase.dy - pinH + headR),
          radius: headR,
        ),
        math.pi,
        math.pi,
        false,
      )
      ..quadraticBezierTo(
        pinBase.dx + headR * 1.15,
        pinBase.dy - pinH * 0.45,
        pinBase.dx,
        pinBase.dy,
      )
      ..close();

    canvas.drawPath(body, Paint()..color = pinColor);
    canvas.drawCircle(
      Offset(pinBase.dx, pinBase.dy - pinH + headR),
      headR * 0.42,
      Paint()..color = AppColors.white,
    );
  }

  @override
  bool shouldRepaint(_LaffahLoaderPainter old) =>
      old.phase != phase || old.pinColor != pinColor;
}

/// Full-screen blocking overlay shown while the AI is computing
/// the optimized route.
///
/// Each run gets a different little show: the overlay cycles through
/// the [FunOptimizationAnimation] variants, never repeating the one
/// from the previous run.
class AppLoadingOverlay extends StatefulWidget {
  final String message;
  const AppLoadingOverlay({super.key, required this.message});

  @override
  State<AppLoadingOverlay> createState() => _AppLoadingOverlayState();
}

class _AppLoadingOverlayState extends State<AppLoadingOverlay> {
  /// Variant shown by the previous overlay (across instances), so
  /// two consecutive optimizations never show the same animation.
  static int? _lastVariant;
  static final math.Random _rng = math.Random();

  late final int _variant;

  @override
  void initState() {
    super.initState();
    int v;
    do {
      v = _rng.nextInt(FunOptimizationAnimation.variantCount);
    } while (v == _lastVariant);
    _lastVariant = v;
    _variant = v;
  }

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
                FunOptimizationAnimation(variant: _variant, size: 120),
                const SizedBox(height: 18),
                Text(
                  widget.message,
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
