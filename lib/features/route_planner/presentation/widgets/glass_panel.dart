import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Frosted-glass container used for the floating map chrome (top bar,
/// move-point banner). Blurs whatever is behind it and draws a translucent
/// surface with a soft border + shadow.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      // `grouped` so this blur shares a single backdrop sampling pass with the
      // other frosted map chrome under the screen's [BackdropGroup]; falls back
      // to a standalone blur when no group is present.
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.60),
              width: 0.8,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
