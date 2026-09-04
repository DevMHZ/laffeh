import 'dart:ui';

import 'map_chrome_blur.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

/// Floating circular action used on top of the map.
class MapActionButton extends StatelessWidget {
  /// Either an icon or a short [label] is drawn, never both. "3D" reads at a
  /// glance where no icon for it does.
  final IconData? icon;
  final String? label;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? iconColor;
  final String? tooltip;
  final double size;

  const MapActionButton({
    super.key,
    this.icon,
    this.label,
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
        child: maybeBlurChrome(sigma: 16, child: Material(
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
                child: label != null
                    ? Center(
                        child: Text(
                          label!,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                            color: disabled
                                ? AppColors.textMuted
                                : (iconColor ?? AppColors.primary),
                          ),
                        ),
                      )
                    : Icon(
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
