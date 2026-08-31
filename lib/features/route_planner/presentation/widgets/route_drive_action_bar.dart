import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// "Start driving", pinned to the foot of the finished-route sheet.
///
/// A solved route has exactly one thing to do with it, and drivers were not
/// doing it. It used to be the middle of three stacked full-width buttons —
/// preview, drive, open in Maps — and preview sat *above* it, so the first
/// green thing a thumb met on a sheet that had just appeared was a rehearsal
/// of the trip rather than the trip. Reports were of drivers previewing the
/// route and then leaving the app to navigate somewhere else entirely.
///
/// Three things fix that, and they are all about rank rather than wording:
/// the action leaves the scrolling column so it is on screen at every drag
/// position, it is the only filled control in the sheet, and preview drops to
/// a quiet half-width button beside "open in Maps". It also lands where the
/// same app already puts its one primary action — see [RoutePlanActionBar],
/// which pins "optimize" for exactly the reason.
class RouteDriveActionBar extends StatelessWidget {
  final VoidCallback onDrive;

  /// DEBUG ONLY: long-press starts the synthetic drive simulator instead of a
  /// real GPS trip. Null in release builds.
  final VoidCallback? onDebugLongPress;

  const RouteDriveActionBar({
    super.key,
    required this.onDrive,
    this.onDebugLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final arrowIcon = Directionality.of(context) == TextDirection.rtl
        ? Icons.arrow_back_rounded
        : Icons.arrow_forward_rounded;

    return DecoratedBox(
      // Only a hairline: the bar shares the sheet's surface, so anything
      // heavier would read as a second sheet stacked on the first.
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 10 + safeBottom),
        child: Material(
          borderRadius: BorderRadius.circular(16),
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              onDrive();
            },
            onLongPress: onDebugLongPress == null
                ? null
                : () {
                    HapticFeedback.heavyImpact();
                    onDebugLongPress!();
                  },
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [AppColors.accent, AppColors.accentDark],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.30),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Iconsax.play,
                      color: AppColors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppStrings.startNavigation,
                          style: AppTextStyles.titleLg.copyWith(
                            color: AppColors.white,
                          ),
                        ),
                        // The line that says which of the two green buttons
                        // this is: the one that follows the driver's real
                        // position, not the one that plays the route back.
                        Text(
                          AppStrings.navigationSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySm.copyWith(
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(arrowIcon, color: AppColors.white, size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
