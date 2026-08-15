import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/services/registration_gate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/legal_links_sheet.dart';
import '../../../profile/presentation/pages/account_onboarding_page.dart';
import '../../../route_planner/presentation/pages/route_planner_page.dart';
import '../widgets/language_chip.dart';
import 'sign_in_page.dart';

/// First-run entry after the walkthrough, and the wall a skipped user hits once
/// their trial is up.
///
/// Login is optional *for a while*: "Skip for now" drops straight into the
/// planner and starts a [RegistrationGate] clock. When that clock runs out the
/// same screen comes back with [registrationRequired] set — same two calls to
/// action, no way past them.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, this.registrationRequired = false});

  /// True once the grace period expired: the skip option is gone and the copy
  /// explains why the user is back here.
  final bool registrationRequired;

  Future<void> _skip(BuildContext context) async {
    final prefs = sl<SharedPreferences>();
    await prefs.setBool(AppStrings.welcomeSeenKey, true);
    // Starts the trial clock (first skip only) — this is the moment the user
    // chose to go on without an account.
    await sl<RegistrationGate>().markSkipped();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RoutePlannerPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Nothing behind this screen once an account is required, so the system
    // back gesture must not pop it into an empty stack.
    return PopScope(
      canPop: !registrationRequired,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: const LanguageChip(),
                  ),
                ),
                const Spacer(flex: 2),
                Image.asset(
                  'assets/laffeh_logo.png',
                  height: 120,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.map_outlined,
                    size: 96,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  registrationRequired
                      ? AppStrings.registrationRequiredTitle
                      : AppStrings.welcomeTitle,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h1,
                ),
                const SizedBox(height: 12),
                Text(
                  registrationRequired
                      ? AppStrings.registrationRequiredBody
                      : AppStrings.welcomeBody,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(flex: 3),
                AppButton(
                  label: AppStrings.welcomeCreateAccount,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AccountOnboardingPage(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: registrationRequired
                      ? AppStrings.welcomeSignInInstead
                      : AppStrings.welcomeHaveAccount,
                  variant: AppButtonVariant.outlined,
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const SignInPage())),
                ),
                const SizedBox(height: 14),
                if (registrationRequired)
                  // The skip is gone, so this slot explains the cost instead of
                  // leaving a hole where the third option used to be.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      AppStrings.registrationRequiredNote,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  )
                else
                  // Skipping is a real option here (login is optional for now),
                  // so it stays a visible target — just quieter than the two
                  // CTAs above.
                  TextButton(
                    onPressed: () => _skip(context),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: Text(
                      AppStrings.welcomeSkip,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(height: 2),
                TextButton(
                  onPressed: () => showLegalLinksSheet(context),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    AppStrings.termsAndPrivacy,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.textMuted,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
