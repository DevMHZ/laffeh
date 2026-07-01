import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/driver_palette.dart';
import '../../../../core/theme/vehicle_kind.dart';
import '../../../../core/theme/vehicle_prefs.dart';
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

          const _ThemeCard(),
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

/// "Appearance" card: two independently-collapsible sections (driver theme,
/// vehicle icon), both collapsed by default so Settings stays compact as
/// more options get added here later.
class _ThemeCard extends StatelessWidget {
  const _ThemeCard();

  @override
  Widget build(BuildContext context) {
    return const AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ThemeSection(),
          SizedBox(height: 14),
          Divider(height: 1),
          SizedBox(height: 14),
          _VehicleSection(),
        ],
      ),
    );
  }
}

/// Driver theme picker. Each tile previews its OWN palette (its surface,
/// text and a few accent swatches) regardless of the active theme, and
/// applies it live on tap via [AppTheme.setPalette].
class _ThemeSection extends StatefulWidget {
  const _ThemeSection();

  @override
  State<_ThemeSection> createState() => _ThemeSectionState();
}

class _ThemeSectionState extends State<_ThemeSection> {
  static const _names = <String, String>{
    'laffah': 'Laffah Leaf',
    'midnight': 'Midnight',
    'amberDusk': 'Amber Dusk',
    'graphiteEv': 'Graphite EV',
    'daylight': 'Daylight',
  };

  bool _expanded = false;

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DriverPalette>(
      valueListenable: AppTheme.notifier,
      builder: (context, active, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CollapsibleHeader(
              icon: Icons.palette_outlined,
              title: AppStrings.appearance,
              valueLabel: _names[active.id] ?? active.id,
              expanded: _expanded,
              onTap: _toggle,
            ),
            _CollapsibleBody(
              expanded: _expanded,
              child: Column(
                children: [
                  for (final palette in DriverPalette.all) ...[
                    if (palette != DriverPalette.all.first)
                      const SizedBox(height: 10),
                    _ThemeTile(
                      palette: palette,
                      name: _names[palette.id] ?? palette.id,
                      selected: palette.id == active.id,
                      onTap: () => AppTheme.setPalette(palette),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Playback/drive vehicle icon picker. Each tile previews the actual
/// top-down painter (rotated 45° so it visibly reads as facing forward),
/// and applies it live on tap via [VehiclePrefs.setVehicle].
class _VehicleSection extends StatefulWidget {
  const _VehicleSection();

  @override
  State<_VehicleSection> createState() => _VehicleSectionState();
}

class _VehicleSectionState extends State<_VehicleSection> {
  bool _expanded = false;

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
  }

  static String _nameFor(VehicleKind kind) => switch (kind) {
    VehicleKind.vwBus => AppStrings.vehicleVwBus,
    VehicleKind.vespa => AppStrings.vehicleVespa,
  };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VehicleKind>(
      valueListenable: VehiclePrefs.notifier,
      builder: (context, active, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CollapsibleHeader(
              icon: Iconsax.car,
              title: AppStrings.vehicleIcon,
              valueLabel: _nameFor(active),
              expanded: _expanded,
              onTap: _toggle,
            ),
            _CollapsibleBody(
              expanded: _expanded,
              child: Column(
                children: [
                  for (final kind in VehicleKind.values) ...[
                    if (kind != VehicleKind.values.first)
                      const SizedBox(height: 10),
                    _VehicleTile(
                      kind: kind,
                      name: _nameFor(kind),
                      selected: kind == active,
                      onTap: () => VehiclePrefs.setVehicle(kind),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Shared tappable header row for a collapsible Settings sub-section: an
/// icon, a title, the current value, and a chevron that rotates on expand.
class _CollapsibleHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool expanded;
  final String valueLabel;
  final VoidCallback onTap;

  const _CollapsibleHeader({
    required this.icon,
    required this.title,
    required this.expanded,
    required this.valueLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: AppTextStyles.titleMd)),
            Text(
              valueLabel,
              style: AppTextStyles.mutedSm.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared expand/collapse animation for a Settings sub-section's option
/// list, so every card in this file grows/shrinks identically.
class _CollapsibleBody extends StatelessWidget {
  final bool expanded;
  final Widget child;

  const _CollapsibleBody({required this.expanded, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 220),
      sizeCurve: Curves.easeOutCubic,
      crossFadeState: expanded
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      firstChild: const SizedBox(width: double.infinity),
      secondChild: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: child,
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final DriverPalette palette;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.palette,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? palette.primary : palette.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Mini live preview of the palette.
              Container(
                width: 60,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _dot(palette.primary),
                    const SizedBox(width: 4),
                    _dot(palette.accent),
                    const SizedBox(width: 4),
                    _dot(palette.routeReturn),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: AppTextStyles.titleMd.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      palette.isDark ? 'Dark' : 'Light',
                      style: AppTextStyles.mutedSm.copyWith(
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedScale(
                scale: selected ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: palette.primary,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot(Color c) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );
}

class _VehicleTile extends StatelessWidget {
  final VehicleKind kind;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _VehicleTile({
    required this.kind,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Live preview of the vehicle's actual top-down painter,
              // tilted so it visibly reads as facing forward.
              Container(
                width: 60,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Transform.rotate(
                  angle: -math.pi / 4,
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CustomPaint(painter: kind.painter()),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  name,
                  style: AppTextStyles.titleMd.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              AnimatedScale(
                scale: selected ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 22,
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
                child: Icon(
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
