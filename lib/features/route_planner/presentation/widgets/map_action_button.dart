import 'package:flutter/material.dart';

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
      child: Material(
        color: color ?? AppColors.white,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: AppColors.shadow,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: disabled ? null : onPressed,
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
    );
  }
}
