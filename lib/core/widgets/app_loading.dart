import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Inline circular loader (used inside cards / sheets).
class AppLoading extends StatelessWidget {
  final double size;
  final Color? color;
  final String? label;

  const AppLoading({
    super.key,
    this.size = 28,
    this.color,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 2.6,
            valueColor: AlwaysStoppedAnimation(color ?? AppColors.primary),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 10),
          Text(label!, style: AppTextStyles.bodyMd),
        ],
      ],
    );
  }
}

/// Full-screen blocking overlay shown while the AI is computing
/// the optimized route.
class AppLoadingOverlay extends StatelessWidget {
  final String message;
  const AppLoadingOverlay({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withOpacity(0.35),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLoading(size: 38),
                const SizedBox(height: 14),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleMd,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
