import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';

class AppErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData? icon;
  final EdgeInsets padding;

  const AppErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.icon,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon ?? Iconsax.warning_2,
              color: AppColors.danger,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleMd,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            AppButton(
              label: AppStrings.retry,
              icon: Iconsax.refresh,
              expand: false,
              variant: AppButtonVariant.outlined,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}
