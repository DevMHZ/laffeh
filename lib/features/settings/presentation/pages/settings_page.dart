import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/afdal_logo.dart';
import '../../../../core/widgets/app_section_card.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 32),
        children: [
          // Brand block
          Center(child: AfdalLogo.full(height: 64)),
          const SizedBox(height: 14),
          Center(
            child: Column(
              children: [
                Text(AppStrings.appName, style: AppTextStyles.h2),
                const SizedBox(height: 2),
                Text(AppStrings.appTagline, style: AppTextStyles.muted),
                const SizedBox(height: 4),
                Text(
                  '${AppStrings.poweredBy} Afdal',
                  style: AppTextStyles.mutedSm,
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),

          AppSectionCard(
            title: AppStrings.about,
            titleIcon: Iconsax.info_circle,
            child: Text(
              AppStrings.aboutDescription,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 14),

          const _LanguageCard(),
          const SizedBox(height: 14),

          _WebsiteCard(onTap: () => _openWebsite(context)),
        ],
      ),
    );
  }

  Future<void> _openWebsite(BuildContext context) async {
    final uri = Uri.parse(AppStrings.afdalWebsiteUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppStrings.websiteOpenFailed(AppStrings.afdalWebsiteUrl),
          ),
        ),
      );
    }
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard();

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: AppStrings.language,
      titleIcon: Iconsax.translate,
      child: DropdownButtonFormField<String>(
        initialValue: AppStrings.languageCode,
        icon: const Icon(Iconsax.arrow_down_1, size: 18),
        decoration: const InputDecoration(contentPadding: EdgeInsets.all(14)),
        items: [
          DropdownMenuItem(
            value: 'en',
            child: Text(AppStrings.languageEnglish),
          ),
          DropdownMenuItem(value: 'ar', child: Text(AppStrings.languageArabic)),
          DropdownMenuItem(value: 'fr', child: Text(AppStrings.languageFrench)),
        ],
        onChanged: (code) async {
          if (code == null) return;
          AppStrings.setLocale(Locale(code));
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(AppStrings.localeStorageKey, code);
        },
      ),
    );
  }
}

class _WebsiteCard extends StatelessWidget {
  final VoidCallback onTap;
  const _WebsiteCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Iconsax.global_search,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.officialWebsite,
                      style: AppTextStyles.titleMd,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppStrings.afdalWebsiteUrl,
                      style: AppTextStyles.muted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
