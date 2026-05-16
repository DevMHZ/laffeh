import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum AppButtonVariant { primary, secondary, outlined, danger, ghost }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final Widget? leading;
  final bool loading;
  final bool expand;
  final double height;
  final double radius;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.leading,
    this.loading = false,
    this.expand = true,
    this.height = 54,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final style = _styleFor(variant, disabled: disabled);

    final child = loading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation(style.foreground),
            ),
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 10),
              ] else if (icon != null) ...[
                Icon(icon, size: 20, color: style.foreground),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.button.copyWith(color: style.foreground),
                ),
              ),
            ],
          );

    final button = Material(
      color: style.background,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: style.border == null
                ? null
                : Border.all(color: style.border!, width: 1.2),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }

  _ButtonStyle _styleFor(AppButtonVariant v, {required bool disabled}) {
    switch (v) {
      case AppButtonVariant.primary:
        return _ButtonStyle(
          background:
              disabled ? AppColors.primary.withOpacity(0.55) : AppColors.primary,
          foreground: AppColors.white,
        );
      case AppButtonVariant.secondary:
        return _ButtonStyle(
          background: AppColors.primarySoft,
          foreground: AppColors.primary,
        );
      case AppButtonVariant.outlined:
        return _ButtonStyle(
          background: Colors.transparent,
          foreground: AppColors.primary,
          border: AppColors.primary,
        );
      case AppButtonVariant.danger:
        return _ButtonStyle(
          background:
              disabled ? AppColors.danger.withOpacity(0.55) : AppColors.danger,
          foreground: AppColors.white,
        );
      case AppButtonVariant.ghost:
        return _ButtonStyle(
          background: AppColors.surfaceAlt,
          foreground: AppColors.textPrimary,
        );
    }
  }
}

class _ButtonStyle {
  final Color background;
  final Color foreground;
  final Color? border;
  const _ButtonStyle({
    required this.background,
    required this.foreground,
    this.border,
  });
}
