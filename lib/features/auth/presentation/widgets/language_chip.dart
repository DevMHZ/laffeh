import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Compact language switcher (en / ar / fr) for the auth screens. Persists the
/// choice the same way Settings does, and updates the app live via
/// [AppStrings.setLocale] (no tree teardown → the map stays alive).
class LanguageChip extends StatelessWidget {
  const LanguageChip({super.key});

  static const _labels = {'en': 'English', 'ar': 'العربية', 'fr': 'Français'};

  Future<void> _select(String code) async {
    if (code == AppStrings.languageCode) return;
    AppStrings.setLocale(Locale(code));
    final prefs = sl<SharedPreferences>();
    await prefs.setString(AppStrings.localeStorageKey, code);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: AppStrings.localeNotifier,
      builder: (_, __, ___) {
        final current = AppStrings.languageCode;
        return PopupMenuButton<String>(
          onSelected: _select,
          position: PopupMenuPosition.under,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          itemBuilder: (_) => [
            for (final entry in _labels.entries)
              PopupMenuItem<String>(
                value: entry.key,
                child: Row(
                  children: [
                    if (entry.key == current)
                      Icon(Icons.check, size: 18, color: AppColors.primary)
                    else
                      const SizedBox(width: 18),
                    const SizedBox(width: 10),
                    Text(entry.value, style: AppTextStyles.bodyMd),
                  ],
                ),
              ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.language, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  _labels[current] ?? current,
                  style: AppTextStyles.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
