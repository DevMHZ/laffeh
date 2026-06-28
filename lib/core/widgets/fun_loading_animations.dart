import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

part 'fun_loading_animations_widgets.dart';

/// A little show while the AI optimizes the route.
///
/// Four hand-painted variants, one per optimization run (the caller
/// rotates [variant]):
///   0. **Route scan** — dots on a radar ring get traced into a route.
///   1. **Pin shuffle** — the optimizer literally re-orders the stops:
///      pins keep swapping places until they're "sorted".
///   2. **Loop drive** — a tiny car laps the laffeh road-loop.
///   3. **Drop & connect** — pins drop onto a mini map, the best path
///      draws itself through them, stamp of approval, repeat.
class FunOptimizationAnimation extends StatelessWidget {
  static const int variantCount = 3;

  /// 0..[variantCount]-1; values outside are wrapped.
  final int variant;
  final double size;

  const FunOptimizationAnimation({
    super.key,
    required this.variant,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    final child = switch (variant % variantCount) {
      0 => const _PinShuffle(),
      1 => const _LoopDrive(),
      _ => const _DropAndConnect(),
    };
    return SizedBox(width: size, height: size, child: child);
  }
}

// ─────────────────────────────────────────────────────────────────
// Shared bits
// ─────────────────────────────────────────────────────────────────

/// Draws a map pin with its tip at the canvas origin.
void _paintPin(Canvas canvas, Color color, double h) {
  final r = h * 0.36;
  final body = Path()
    ..moveTo(0, 0)
    ..quadraticBezierTo(-r * 1.15, -h * 0.45, -r, -h + r)
    ..arcTo(
      Rect.fromCircle(center: Offset(0, -h + r), radius: r),
      math.pi,
      math.pi,
      false,
    )
    ..quadraticBezierTo(r * 1.15, -h * 0.45, 0, 0)
    ..close();

  canvas.drawPath(
    body.shift(const Offset(0, 1.5)),
    Paint()..color = AppColors.asphaltDark.withValues(alpha: 0.18),
  );
  canvas.drawPath(body, Paint()..color = color);
  canvas.drawPath(
    body,
    Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6,
  );
  canvas.drawCircle(
    Offset(0, -h + r),
    r * 0.42,
    Paint()..color = AppColors.white,
  );
}
