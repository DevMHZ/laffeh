import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/support_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/whatsapp_glyph.dart';

/// Since phone-only auth has no automatic recovery channel, "forgot password"
/// opens WhatsApp support with a prefilled message.
///
/// Structured as a separate entry point so a real recovery flow (e.g. OTP) can
/// replace it later without touching the sign-in screen.
Future<void> showForgotPasswordSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => const _ForgotPasswordSheet(),
  );
}

class _ForgotPasswordSheet extends StatelessWidget {
  const _ForgotPasswordSheet();

  Future<void> _contactSupport(BuildContext context) async {
    final uri = SupportConfig.whatsappUri(
      message: AppStrings.whatsappForgotMessage,
    );
    Navigator.of(context).pop();
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
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
            ),
            Text(
              AppStrings.forgotPasswordTitle,
              style: AppTextStyles.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.forgotPasswordBody,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AppButton(
              label: AppStrings.contactSupport,
              leading: const WhatsappGlyph(size: 22, color: AppColors.white),
              onPressed: () => _contactSupport(context),
            ),
          ],
        ),
      ),
    );
  }
}
