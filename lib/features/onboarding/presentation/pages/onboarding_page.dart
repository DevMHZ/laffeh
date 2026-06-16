import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/location_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../route_planner/presentation/pages/route_planner_page.dart';
import '../widgets/onboarding_mock.dart';

/// First-run walkthrough: language, what the app does, the WhatsApp /
/// CSV import trick, and the location permission. Shown once (gated by
/// [AppStrings.onboardingDoneKey]); the visuals are animated Flutter
/// mock-ups so they translate with the rest of the UI.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pc = PageController();
  int _index = 0;
  bool _finishing = false;

  static const int _slideCount = 4;
  int get _last => _slideCount - 1;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    final prefs = sl<SharedPreferences>();
    await prefs.setBool(AppStrings.onboardingDoneKey, true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (_, __, ___) => const RoutePlannerPage(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  void _next() {
    if (_index >= _last) {
      _finish();
      return;
    }
    _pc.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    _pc.previousPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _allowLocationThenFinish() async {
    // Fires the OS permission prompt; we proceed either way.
    try {
      await LocationUtils.getCurrentLatLng();
    } catch (_) {}
    await _finish();
  }

  Future<void> _setLanguage(String code) async {
    if (code == AppStrings.languageCode) return;
    AppStrings.setLocale(Locale(code));
    final prefs = sl<SharedPreferences>();
    await prefs.setString(AppStrings.localeStorageKey, code);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip (hidden on the last slide, which has its own actions).
            SizedBox(
              height: 44,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _index < _last ? 1 : 0,
                  child: TextButton(
                    onPressed: _index < _last ? _finish : null,
                    child: Text(
                      AppStrings.onbSkip,
                      style: AppTextStyles.titleSm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pc,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  _OnbSlide(
                    visual: const OnbWelcomeArt(),
                    title: AppStrings.onbWelcomeTitle,
                    body: AppStrings.onbWelcomeBody,
                    extra: _languageChips(),
                  ),
                  _OnbSlide(
                    visual: _phone(const OnbPlanDemo()),
                    title: AppStrings.onbPlanTitle,
                    body: AppStrings.onbPlanBody,
                  ),
                  _OnbSlide(
                    visual: _phone(const OnbWhatsappDemo()),
                    title: AppStrings.onbImportTitle,
                    body: AppStrings.onbImportBody,
                    extra: _importTags(),
                  ),
                  _OnbSlide(
                    visual: _phone(const OnbLocationDemo()),
                    title: AppStrings.onbLocationTitle,
                    body: AppStrings.onbLocationBody,
                  ),
                ],
              ),
            ),
            _dots(),
            _bottomArea(),
          ],
        ),
      ),
    );
  }

  Widget _phone(Widget screen) {
    return FittedBox(
      fit: BoxFit.contain,
      child: OnbPhoneFrame(child: screen),
    );
  }

  Widget _dots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_slideCount, (i) {
        final active = i == _index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.borderStrong,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _bottomArea() {
    if (_index == _last) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(
              label: AppStrings.onbAllowLocation,
              icon: Icons.my_location_rounded,
              height: 54,
              onPressed: _allowLocationThenFinish,
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: _finish,
              child: Text(
                AppStrings.onbMaybeLater,
                style: AppTextStyles.titleSm.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 22),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: _index > 0
                ? TextButton(
                    onPressed: _back,
                    child: Text(
                      AppStrings.onbBack,
                      style: AppTextStyles.titleSm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : null,
          ),
          const Spacer(),
          SizedBox(
            width: 150,
            child: AppButton(
              label: AppStrings.onbNext,
              icon: Icons.arrow_forward_rounded,
              height: 52,
              onPressed: _next,
            ),
          ),
        ],
      ),
    );
  }

  Widget _languageChips() {
    final current = AppStrings.languageCode;
    final langs = <(String, String)>[
      ('en', AppStrings.languageEnglish),
      ('ar', AppStrings.languageArabic),
      ('fr', AppStrings.languageFrench),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppStrings.onbLanguageLabel,
          style: AppTextStyles.mutedSm.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (final (code, label) in langs)
              _LangChip(
                label: label,
                selected: code == current,
                onTap: () => _setLanguage(code),
              ),
          ],
        ),
      ],
    );
  }

  Widget _importTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _Tag(
          icon: Icons.chat_bubble_rounded,
          label: AppStrings.onbImportWhatsappTag,
        ),
        _Tag(
          icon: Icons.upload_file_rounded,
          label: AppStrings.onbImportCsvTag,
        ),
      ],
    );
  }
}

class _OnbSlide extends StatelessWidget {
  final Widget visual;
  final String title;
  final String body;
  final Widget? extra;

  const _OnbSlide({
    required this.visual,
    required this.title,
    required this.body,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Expanded(child: Center(child: visual)),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: AppTextStyles.h2),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          if (extra != null) ...[const SizedBox(height: 20), extra!],
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: 1.4,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        key: ValueKey('selected'),
                        color: AppColors.white,
                        size: 15,
                      )
                    : const SizedBox.shrink(key: ValueKey('unselected')),
              ),
              if (selected) const SizedBox(width: 5),
              Text(
                label,
                style: AppTextStyles.titleSm.copyWith(
                  color: selected ? AppColors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Tag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.titleSm.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
