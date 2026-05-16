import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Card-style container with optional title row.
///
/// Used for metric cards, info blocks, and similar surfaces.
class AppSectionCard extends StatelessWidget {
  final String? title;
  final IconData? titleIcon;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;
  final Color? background;
  final BorderRadius? borderRadius;

  const AppSectionCard({
    super.key,
    this.title,
    this.titleIcon,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.background,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? AppColors.surface,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (titleIcon != null) ...[
                  Icon(titleIcon, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(title!, style: AppTextStyles.titleMd),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}
