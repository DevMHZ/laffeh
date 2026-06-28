import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  static const _languages = <({String code, String native, String avatar})>[
    (code: 'en', native: 'English', avatar: 'EN'),
    (code: 'ar', native: 'العربية', avatar: 'ع'),
    (code: 'fr', native: 'Français', avatar: 'FR'),
  ];

  Future<void> _select(String code) async {
    if (code == AppStrings.languageCode) return;
    HapticFeedback.selectionClick();
    AppStrings.setLocale(Locale(code));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppStrings.localeStorageKey, code);
  }

  @override
  Widget build(BuildContext context) {
    final current = AppStrings.languageCode;
    return AppSectionCard(
      title: AppStrings.language,
      titleIcon: Iconsax.translate,
      // Three compact tiles in one row — quicker to scan and far less
      // vertical weight than a stacked list of radio rows.
      child: Row(
        children: [
          for (final lang in _languages) ...[
            if (lang != _languages.first) const SizedBox(width: 10),
            Expanded(
              child: _LanguageTile(
                avatar: lang.avatar,
                native: lang.native,
                selected: lang.code == current,
                onTap: () => _select(lang.code),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final String avatar;
  final String native;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageTile({
    required this.avatar,
    required this.native,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.10)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      avatar,
                      style: AppTextStyles.titleMd.copyWith(
                        color: selected ? AppColors.white : AppColors.primary,
                      ),
                    ),
                  ),
                  if (selected)
                    PositionedDirectional(
                      end: -5,
                      top: -5,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 11,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                native,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.titleSm.copyWith(
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
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
