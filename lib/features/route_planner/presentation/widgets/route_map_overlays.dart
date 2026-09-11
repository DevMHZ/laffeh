import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Small circular "return to my location" FAB shown on the map once the
/// user pans away from their current position. Icon-only (with a tooltip)
/// so it stays out of the way until needed.
class LocateFab extends StatelessWidget {
  final VoidCallback onTap;
  const LocateFab({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: AppStrings.yourLocation,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: AppColors.shadow,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(Iconsax.gps, color: AppColors.primary, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Pill button used for "reset view" / recenter actions on the map.
class RecenterButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  const RecenterButton({
    super.key,
    required this.onTap,
    this.icon = Iconsax.gps,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: AppColors.white.withValues(alpha: 0.85),
              width: 1.4,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.white, size: 18),
              const SizedBox(width: 7),
              Text(
                label,
                style: AppTextStyles.titleSm.copyWith(color: AppColors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
