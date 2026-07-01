import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum AppButtonVariant { primary, secondary, outlined, danger, ghost }

class AppButton extends StatefulWidget {
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
    this.height = 56,
    // Chunkier default corner so primary CTAs read as easy driver targets.
    this.radius = 18,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  String get label => widget.label;
  VoidCallback? get onPressed => widget.onPressed;
  AppButtonVariant get variant => widget.variant;
  IconData? get icon => widget.icon;
  Widget? get leading => widget.leading;
  bool get loading => widget.loading;
  bool get expand => widget.expand;
  double get height => widget.height;
  double get radius => widget.radius;

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

    final button = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: style.shadow == null || disabled
            ? null
            : [
                BoxShadow(
                  color: style.shadow!,
                  blurRadius: _pressed ? 6 : 14,
                  offset: Offset(0, _pressed ? 2 : 6),
                ),
              ],
      ),
      child: Material(
        color: style.background,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: disabled
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onPressed?.call();
                },
          onHighlightChanged: (v) => setState(() => _pressed = v),
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 18),
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
      ),
    );

    // Press-shrink micro-interaction: the whole button gives slightly
    // under the finger, then springs back.
    final animated = AnimatedScale(
      scale: _pressed && !disabled ? 0.965 : 1.0,
      duration: const Duration(milliseconds: 110),
      curve: Curves.easeOut,
      child: button,
    );

    return expand
        ? SizedBox(width: double.infinity, child: animated)
        : animated;
  }

  _ButtonStyle _styleFor(AppButtonVariant v, {required bool disabled}) {
    switch (v) {
      case AppButtonVariant.primary:
        return _ButtonStyle(
          background: disabled
              ? AppColors.primary.withValues(alpha: 0.55)
              : AppColors.primary,
          foreground: AppColors.white,
          shadow: AppColors.primary.withValues(alpha: 0.30),
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
          background: disabled
              ? AppColors.danger.withValues(alpha: 0.55)
              : AppColors.danger,
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
  final Color? shadow;
  const _ButtonStyle({
    required this.background,
    required this.foreground,
    this.border,
    this.shadow,
  });
}
