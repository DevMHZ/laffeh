import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// The empty-state entry point: a single calm "Add a stop" call-to-action
/// over a clean map. Tapping it opens the per-point add-method chooser
/// (type an address / pick on the map / from WhatsApp) — the same chooser
/// used for every subsequent stop, so adding a point always works the
/// same way.
class RouteAddOptionsPanel extends StatelessWidget {
  /// Opens the add-method chooser.
  final VoidCallback? onTap;

  const RouteAddOptionsPanel({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return _GreenCta(
      icon: Iconsax.location_add,
      label: AppStrings.addPointCta,
      onTap: onTap,
    );
  }
}

/// Wide green call-to-action — the empty-state "add a stop" entry.
class _GreenCta extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _GreenCta({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.30),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onTap!();
                },
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.white, size: 20),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.button.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
