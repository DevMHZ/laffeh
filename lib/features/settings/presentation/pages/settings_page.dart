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
import '../../../../core/widgets/app_chevron.dart';
import '../../../../core/widgets/app_section_card.dart';
import '../../../../core/widgets/legal_links_sheet.dart';
import '../../../../core/widgets/offline_area_section.dart';
import '../../../../core/widgets/vehicle_turntable.dart';
import '../widgets/account_section.dart';

class SettingsPage extends StatelessWidget {
  /// Picks a spreadsheet of stops for the trip behind this page, and reports
  /// how many landed. Null when Settings is opened from anywhere without a
  /// route to import into — the row simply isn't there.
  ///
  /// The work belongs to the planner, not to Settings: the callback is
  /// supplied by the screen that pushed this one, so the import runs with the
  /// planner's context and cubit. Settings only decides where the row sits
  /// and what happens after.
  final Future<int> Function()? onImportCsv;

  const SettingsPage({super.key, this.onImportCsv});

  @override
  Widget build(BuildContext context) {
    // Rebuild the whole page in place the instant the language or
    // appearance changes, so the selection applies immediately instead of
    // only after leaving and reopening Settings. The app no longer re-keys
    // on locale (that used to crash the native map), so a pushed route like
    // this one has to listen for the change itself — its text is read from
    // AppStrings/AppColors, which don't trigger a rebuild on their own.
    return AnimatedBuilder(
      animation: Listenable.merge([
        AppStrings.localeNotifier,
        AppTheme.notifier,
      ]),
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 32),
        children: [
          // Brand block — Laffah app icon + Afdal "Powered by"
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/laffeh_logo.png',
                width: 88,
                height: 88,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${AppStrings.poweredBy} ', style: AppTextStyles.mutedSm),
                AfdalLogo.compact(height: 24),
              ],
            ),
          ),
          const SizedBox(height: 22),

          _SettingsGroups(
            onAboutUsTap: () => _openWebsite(context),
            onImportCsv: onImportCsv,
          ),
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

/// The settings list, in four labelled groups.
///
/// It used to be one card holding eight unrelated rows: app info, three
/// preferences, the offline map, the account, and two documents, separated
/// only by dividers. Nothing told the eye where one concern ended and the
/// next began, and the least useful row — "About the app" — sat in the most
/// prominent slot on the page.
///
/// The order now follows what a driver actually comes here to do. Their
/// account first, because that is what decides whether their trips are
/// being kept. Then the preferences they set once — language ahead of the
/// rest, since a driver who opened the app in the wrong language cannot
/// read anything else until they find it. The documents last, where
/// read-once material belongs.
///
/// The offline map used to sit second, on the reasoning that it was the one
/// thing here that *did* something and was worth finding before losing
/// signal. It no longer needs finding: the app keeps a square around the
/// driver by itself (see `AutoMapCache`), unasked and unannounced, so what
/// is left on this page is the picker for choosing a *bigger* map
/// deliberately — settings, not an errand. It moved down accordingly.
class _SettingsGroups extends StatelessWidget {
  final VoidCallback onAboutUsTap;
  final Future<int> Function()? onImportCsv;
  const _SettingsGroups({required this.onAboutUsTap, this.onImportCsv});

  @override
  Widget build(BuildContext context) {
    // NB: the section widgets are intentionally NOT const. A parent rebuild
    // (e.g. the page-level refresh on a language/appearance change) can only
    // propagate into children that are fresh instances — const children are
    // canonicalised and skipped, which used to leave every section's text
    // stale until Settings was reopened. `_LegalRow` was const and did
    // exactly that: it still read "Legal" after switching to Arabic.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsGroup(
          label: AppStrings.settingsGroupAccount,
          children: [AccountSection()],
        ),
        _SettingsGroup(
          label: AppStrings.settingsGroupPreferences,
          children: [_LanguageSection(), _ThemeSection(), _VehicleSection()],
        ),
        // The spreadsheet of stops the office keeps. It used to sit on the
        // planning sheet and on the empty map, where it spent its life being
        // scrolled past by the drivers who type addresses one at a time —
        // and where, as a row with a heading and a subtitle, it cost the map
        // more than the feature is worth to most of them. A driver who has a
        // file came looking for this; the rest never have to see it.
        if (onImportCsv != null)
          _SettingsGroup(
            label: AppStrings.settingsGroupTrip,
            children: [_ImportCsvRow(onTap: onImportCsv!)],
          ),
        _SettingsGroup(
          label: AppStrings.settingsGroupMap,
          // Only the hand-picked area. The square the app keeps around the
          // driver used to have a switch here, and the switch was the whole
          // problem: a row explaining a background download invites a
          // decision about something that works better as weather. It is
          // now simply how the app behaves, like a browser cache — always
          // on, never mentioned. The trip corridor lives on the route
          // summary instead, next to the driving it is for; here it spent
          // most of its life saying there was no trip to save.
          children: [OfflineAreaSection()],
        ),
        _SettingsGroup(
          label: AppStrings.settingsGroupAbout,
          children: [
            _AboutSection(),
            _LegalRow(),
            _AboutUsRow(onTap: onAboutUsTap),
          ],
        ),
      ],
    );
  }
}

/// One labelled group: a quiet heading over a card of related rows.
///
/// The heading is what turns a long list into a short one — four things to
/// scan instead of eight — and it carries the dividers, so no caller has to
/// remember to interleave them.
class _SettingsGroup extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _SettingsGroup({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 6, bottom: 8),
            child: Text(
              label,
              style: AppTextStyles.mutedSm.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
          ),
          AppSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) ...[
                    const SizedBox(height: 14),
                    Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 14),
                  ],
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Collapsible About section — shows the app description and a small
/// "Powered by Afdal" badge inside the expanded body.
class _AboutSection extends StatefulWidget {
  const _AboutSection();

  @override
  State<_AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<_AboutSection> {
  bool _expanded = false;

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CollapsibleHeader(
          icon: Iconsax.info_circle,
          title: AppStrings.about,
          valueLabel: '',
          expanded: _expanded,
          onTap: _toggle,
        ),
        _CollapsibleBody(
          expanded: _expanded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.aboutDescription,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${AppStrings.poweredBy} ',
                      style: AppTextStyles.mutedSm,
                    ),
                    AfdalLogo.bare(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Collapsible Language section — collapsed shows the current language,
/// expanded shows the three language tiles.
class _LanguageSection extends StatefulWidget {
  const _LanguageSection();

  @override
  State<_LanguageSection> createState() => _LanguageSectionState();
}

class _LanguageSectionState extends State<_LanguageSection> {
  bool _expanded = false;

  static const _languages = <({String code, String native, String avatar})>[
    (code: 'en', native: 'English', avatar: 'EN'),
    (code: 'ar', native: 'العربية', avatar: 'ع'),
    (code: 'fr', native: 'Français', avatar: 'FR'),
  ];

  static const _names = <String, String>{
    'en': 'English',
    'ar': 'العربية',
    'fr': 'Français',
  };

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
  }

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CollapsibleHeader(
          icon: Iconsax.translate,
          title: AppStrings.language,
          valueLabel: _names[current] ?? current,
          expanded: _expanded,
          onTap: _toggle,
        ),
        _CollapsibleBody(
          expanded: _expanded,
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
        ),
      ],
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
              preview: _PaletteDots(palette: active),
              expanded: _expanded,
              onTap: _toggle,
            ),
            _CollapsibleBody(
              expanded: _expanded,
              // Horizontal swipe picker: one big live-preview card per
              // theme, neighbours peeking — swipe to apply, no scrolling
              // through a vertical list.
              child: _SwipeSelector(
                itemCount: DriverPalette.all.length,
                initialIndex: DriverPalette.all.indexWhere(
                  (p) => p.id == active.id,
                ),
                height: 150,
                viewportFraction: 0.58,
                onSelected: (i) => AppTheme.setPalette(DriverPalette.all[i]),
                itemBuilder: (context, i, isActive) => _ThemePage(
                  palette: DriverPalette.all[i],
                  name:
                      _names[DriverPalette.all[i].id] ??
                      DriverPalette.all[i].id,
                  active: isActive,
                ),
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
    VehicleKind.taxi => AppStrings.vehicleTaxi,
    VehicleKind.vespa => AppStrings.vehicleVespa,
    VehicleKind.camel => AppStrings.vehicleCamel,
    VehicleKind.arrow => AppStrings.vehicleArrow,
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
              // Small static garage thumb of the current pick, boxed so it
              // sits cleanly beside the value label.
              preview: Container(
                width: 30,
                height: 30,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: VehicleTurntable(kind: active, size: 26, animate: false),
              ),
              expanded: _expanded,
              onTap: _toggle,
            ),
            _CollapsibleBody(
              expanded: _expanded,
              // Garage carousel: each vehicle spins on its own showcase
              // stage; swipe left/right to pick. Only mounted while open
              // so turntables never animate unseen.
              child: !_expanded
                  ? const SizedBox.shrink()
                  : _SwipeSelector(
                      itemCount: VehicleKind.values.length,
                      initialIndex: VehicleKind.values.indexOf(active),
                      height: 214,
                      viewportFraction: 0.76,
                      onSelected: (i) =>
                          VehiclePrefs.setVehicle(VehicleKind.values[i]),
                      itemBuilder: (context, i, isActive) => _VehicleStage(
                        kind: VehicleKind.values[i],
                        name: _nameFor(VehicleKind.values[i]),
                        active: isActive,
                      ),
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

  /// Small live preview of the current selection (palette dots, vehicle
  /// thumb…) shown next to the value while collapsed.
  final Widget? preview;

  final VoidCallback onTap;

  const _CollapsibleHeader({
    required this.icon,
    required this.title,
    required this.expanded,
    required this.valueLabel,
    this.preview,
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
            if (preview != null) ...[preview!, const SizedBox(width: 7)],
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

/// Horizontal swipe picker: one big card per option with the neighbours
/// peeking at the sides. Swiping snaps page-by-page and applies the
/// centred option immediately; tapping a peeking card slides to it.
class _SwipeSelector extends StatefulWidget {
  final int itemCount;
  final int initialIndex;
  final double height;
  final double viewportFraction;
  final ValueChanged<int> onSelected;
  final Widget Function(BuildContext context, int index, bool active)
  itemBuilder;

  const _SwipeSelector({
    required this.itemCount,
    required this.initialIndex,
    required this.height,
    required this.viewportFraction,
    required this.onSelected,
    required this.itemBuilder,
  });

  @override
  State<_SwipeSelector> createState() => _SwipeSelectorState();
}

class _SwipeSelectorState extends State<_SwipeSelector> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex.clamp(0, widget.itemCount - 1),
    viewportFraction: widget.viewportFraction,
  );
  late int _current = widget.initialIndex.clamp(0, widget.itemCount - 1);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _jumpTo(int i) {
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.itemCount,
            onPageChanged: (i) {
              HapticFeedback.selectionClick();
              setState(() => _current = i);
              widget.onSelected(i);
            },
            itemBuilder: (context, i) {
              final active = i == _current;
              return GestureDetector(
                onTap: active ? null : () => _jumpTo(i),
                child: AnimatedScale(
                  scale: active ? 1.0 : 0.88,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: active ? 1 : 0.55,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: widget.itemBuilder(context, i, active),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.itemCount; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _current ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _current ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Tiny three-swatch preview of a palette, used in the collapsed header.
class _PaletteDots extends StatelessWidget {
  final DriverPalette palette;
  const _PaletteDots({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(palette.primary),
          const SizedBox(width: 3),
          _dot(palette.accent),
          const SizedBox(width: 3),
          _dot(palette.routeReturn),
        ],
      ),
    );
  }

  Widget _dot(Color c) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );
}

/// One palette card in the appearance carousel — painted entirely in its
/// OWN palette, so every page is a live preview of that theme.
class _ThemePage extends StatelessWidget {
  final DriverPalette palette;
  final String name;
  final bool active;

  const _ThemePage({
    required this.palette,
    required this.name,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? palette.primary : palette.border,
          width: active ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 52,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dot(palette.primary),
                const SizedBox(width: 6),
                _dot(palette.accent),
                const SizedBox(width: 6),
                _dot(palette.routeReturn),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.titleMd.copyWith(color: palette.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            palette.isDark ? 'Dark' : 'Light',
            style: AppTextStyles.mutedSm.copyWith(color: palette.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color c) => Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );
}

/// One vehicle "stage" in the garage carousel: the showcase backdrop with
/// the vehicle orbiting slowly on its map-diorama platter. Only the
/// centred stage animates.
class _VehicleStage extends StatelessWidget {
  final VehicleKind kind;
  final String name;
  final bool active;

  const _VehicleStage({
    required this.kind,
    required this.name,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? AppColors.primary : AppColors.border,
          width: active ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: _ShowcaseStage(kind: kind, animate: active),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.titleSm.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Showroom stage for one vehicle, matching the Laffa Avatars showcase
/// page: a soft sage radial-gradient backdrop with the vehicle spinning
/// slowly on its baked map-diorama platter. Fixed light palette so it
/// reads the same under every app theme.
class _ShowcaseStage extends StatelessWidget {
  final VehicleKind kind;
  final bool animate;

  const _ShowcaseStage({required this.kind, required this.animate});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        // The showcase page sky: warm off-white falling to sage.
        gradient: RadialGradient(
          center: Alignment(0, -1),
          radius: 1.5,
          colors: [Color(0xFFF4F6F1), Color(0xFFE7EBE4), Color(0xFFDEE3DA)],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size =
              math.min(constraints.maxWidth, constraints.maxHeight) - 6;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Soft contact shadow seating the platter on the gradient.
              Align(
                alignment: const Alignment(0, 0.78),
                child: Container(
                  width: size * 0.66,
                  height: size * 0.1,
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      colors: [Color(0x2414231E), Color(0x0014231E)],
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(99)),
                  ),
                ),
              ),
              VehicleTurntable(kind: kind, size: size, animate: animate),
            ],
          );
        },
      ),
    );
  }
}

/// Tappable "About us" row that matches the collapsible-header style of the
/// sections above, so the whole settings block reads as one cohesive list.
/// Opens the published privacy policy / terms / account-deletion guide. Keeping
/// them reachable in-app is a store requirement, not just a nicety.
class _LegalRow extends StatelessWidget {
  const _LegalRow();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => showLegalLinksSheet(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(Iconsax.shield_tick, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppStrings.legalTitle,
                  style: AppTextStyles.titleMd,
                ),
              ),
              const AppChevron(),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Import a CSV file" — the way a whole round arrives at once, with the
/// customer names and phone numbers a pasted list throws away.
///
/// A successful import closes Settings on the driver's behalf: the stops they
/// just added are on the map one screen back, and asking them to find their
/// own way there would be asking them to check the app's work.
class _ImportCsvRow extends StatelessWidget {
  final Future<int> Function() onTap;
  const _ImportCsvRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final navigator = Navigator.of(context);
          final added = await onTap();
          if (added > 0 && navigator.canPop()) navigator.pop();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(Iconsax.document_text, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.importChooserCsv,
                      style: AppTextStyles.titleMd,
                    ),
                    const SizedBox(height: 2),
                    Text(AppStrings.importCsvSub, style: AppTextStyles.mutedSm),
                  ],
                ),
              ),
              const AppChevron(),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutUsRow extends StatelessWidget {
  final VoidCallback onTap;
  const _AboutUsRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(Iconsax.heart, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(AppStrings.aboutUs, style: AppTextStyles.titleMd),
              ),
              Text(
                AppStrings.visitWebsite,
                style: AppTextStyles.mutedSm.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 4),
              const AppChevron(),
            ],
          ),
        ),
      ),
    );
  }
}
