import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../profile/presentation/pages/account_onboarding_page.dart';

/// A light, recurring reminder to create an account, shown to users who chose
/// to skip. Non-intrusive: a bottom sheet on entry, spaced out by launch count,
/// at most once per app session, and never for signed-in users.
class AccountNudge {
  AccountNudge._();

  static bool _shownThisSession = false;

  /// Call on reaching the planner. Increments the launch counter and, when the
  /// spacing is right, shows the nudge sheet.
  static Future<void> maybePrompt(
    BuildContext context, {
    required bool isAuthenticated,
  }) async {
    if (isAuthenticated || _shownThisSession) return;

    final prefs = sl<SharedPreferences>();
    final launches = (prefs.getInt(AppStrings.nudgeLaunchesKey) ?? 0) + 1;
    await prefs.setInt(AppStrings.nudgeLaunchesKey, launches);

    // Show on the 2nd launch, then every 3rd (2, 5, 8, …). Skips the very
    // first run so the welcome screen isn't immediately echoed.
    if (launches < 2 || (launches - 2) % 3 != 0) return;

    _shownThisSession = true;
    if (!context.mounted) return;
    await _show(context);
  }

  static Future<void> _show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
                alignment: Alignment.center,
              ),
              Icon(
                Icons.person_add_alt_1_outlined,
                size: 44,
                color: AppColors.primary,
              ),
              const SizedBox(height: 14),
              Text(
                AppStrings.nudgeTitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.h3,
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.nudgeBody,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 22),
              AppButton(
                label: AppStrings.welcomeCreateAccount,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AccountOnboardingPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text(
                  AppStrings.nudgeLater,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
