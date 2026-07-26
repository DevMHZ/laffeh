import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Shared chrome for every auth input: an optional label, a focus/error aware
/// rounded container, and an animated inline error line underneath.
///
/// Inputs live *inside* the container and draw no border of their own, so a
/// composite control (country selector + phone number) reads as one field
/// instead of two competing boxes.
class AuthFieldShell extends StatelessWidget {
  const AuthFieldShell({
    super.key,
    required this.child,
    this.label,
    this.errorText,
    this.focused = false,
    this.height = 56,
  });

  final Widget child;
  final String? label;
  final String? errorText;
  final bool focused;
  final double height;

  static const BorderRadius radius = BorderRadius.all(Radius.circular(16));

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    final borderColor = hasError
        ? AppColors.danger
        : focused
        ? AppColors.primary
        : AppColors.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTextStyles.titleSm.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: focused ? AppColors.surface : AppColors.surfaceAlt,
            borderRadius: radius,
            border: Border.all(
              color: borderColor,
              width: focused || hasError ? 1.4 : 1,
            ),
            boxShadow: focused
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
        AuthFieldError(text: errorText),
      ],
    );
  }
}

/// A single-line field error that grows/shrinks instead of popping the layout.
class AuthFieldError extends StatelessWidget {
  const AuthFieldError({super.key, this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: text == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsetsDirectional.only(start: 4, top: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, size: 14, color: AppColors.danger),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      text!,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Borderless [InputDecoration] for text inputs hosted by [AuthFieldShell] —
/// the shell owns the fill, border and focus ring.
InputDecoration authInnerDecoration({String? hint}) => InputDecoration(
  hintText: hint,
  filled: false,
  isDense: true,
  contentPadding: EdgeInsets.zero,
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  errorBorder: InputBorder.none,
  focusedErrorBorder: InputBorder.none,
  disabledBorder: InputBorder.none,
  hintStyle: AppTextStyles.bodyMd.copyWith(color: AppColors.hint),
);
