import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

/// Floating circular action used on top of the map.
class MapActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? iconColor;
  final String? tooltip;
  final double size;

  const MapActionButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.iconColor,
    this.tooltip,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Tooltip(
      message: tooltip ?? '',
      child: ClipOval(
        // Shares one backdrop blur pass with the other map chrome via the
        // screen's [BackdropGroup] (graceful standalone fallback otherwise).
        child: BackdropFilter.grouped(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Material(
            color:
                color?.withValues(alpha: 0.94) ??
                AppColors.white.withValues(alpha: 0.92),
            shape: const CircleBorder(),
            elevation: 5,
            shadowColor: AppColors.shadow,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: disabled
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      onPressed?.call();
                    },
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(
                  icon,
                  size: 22,
                  color: disabled
                      ? AppColors.textMuted
                      : (iconColor ?? AppColors.primary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
