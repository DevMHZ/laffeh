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
import '../../../../core/widgets/vehicle_turntable.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
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
                Text(
                  '${AppStrings.poweredBy} ',
                  style: AppTextStyles.mutedSm,
                ),
                AfdalLogo.compact(height: 24),
              ],
            ),
          ),
          const SizedBox(height: 22),

          _SettingsCard(onAboutUsTap: () => _openWebsite(context)),
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

/// Single card bundling all collapsible settings (About, Appearance,
/// Vehicle Icon, Language, About us) so they stick together as one block.
class _SettingsCard extends StatelessWidget {
  final VoidCallback onAboutUsTap;
  const _SettingsCard({required this.onAboutUsTap});

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AboutSection(),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          const _ThemeSection(),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          const _VehicleSection(),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          const _LanguageSection(),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          _AboutUsRow(onTap: onAboutUsTap),
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
                  name: _names[DriverPalette.all[i].id] ??
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
                child: VehicleTurntable(
                  kind: active,
                  size: 26,
                  animate: false,
                ),
              ),
              expanded: _expanded,
              onTap: _toggle,
            ),
            _CollapsibleBody(
              expanded: _expanded,
              // Garage carousel: each vehicle spins on its own street
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

/// One vehicle "stage" in the garage carousel: a playful little street —
/// sky, sun, clouds, a bus-stop sign and a dashed road — with the vehicle
/// spinning on the asphalt. Only the centred stage animates.
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
          Expanded(child: _StreetScene(kind: kind, animate: active)),
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

/// The little street the vehicle spins on: fixed daylight artwork (sky,
/// sun, clouds, a distant skyline, a tree, a bus shelter and dashed
/// asphalt) so it reads the same under every app theme.
class _StreetScene extends StatelessWidget {
  final VehicleKind kind;
  final bool animate;

  const _StreetScene({required this.kind, required this.animate});

  static const double _roadHeight = 48;
  static const double _sidewalkHeight = 8;
  static const double _groundTop = _roadHeight + _sidewalkHeight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Sky — cool above, warm at the horizon.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFB7E0F8),
                Color(0xFFE3F4FE),
                Color(0xFFFFF2D9),
              ],
              stops: [0.0, 0.62, 1.0],
            ),
          ),
        ),
        // Sun with a soft glow.
        PositionedDirectional(
          top: 10,
          start: 14,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD66B),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD66B).withValues(alpha: 0.55),
                  blurRadius: 14,
                ),
              ],
            ),
          ),
        ),
        // Clouds.
        const PositionedDirectional(top: 14, end: 30, child: _Cloud(width: 42)),
        const PositionedDirectional(top: 32, end: 86, child: _Cloud(width: 26)),
        const PositionedDirectional(top: 40, start: 52, child: _Cloud(width: 32)),
        // Distant skyline sitting on the sidewalk.
        Positioned(
          left: 0,
          right: 0,
          bottom: _groundTop - 1,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _Building(width: 30, height: 34, color: Color(0xFFA9BFCE)),
              _Building(width: 24, height: 48, color: Color(0xFF97AFC0), lit: true),
              _Building(width: 34, height: 28, color: Color(0xFFB3C8D5)),
              _Building(width: 22, height: 42, color: Color(0xFF9DB4C4), lit: true),
              _Building(width: 28, height: 32, color: Color(0xFFA9BFCE)),
            ],
          ),
        ),
        // Sidewalk + asphalt.
        Positioned(
          left: 0,
          right: 0,
          bottom: _roadHeight,
          height: _sidewalkHeight,
          child: const ColoredBox(color: Color(0xFFCBD5DA)),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: _roadHeight,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF525A61), Color(0xFF41484E)],
              ),
            ),
          ),
        ),
        // Road edge line + dashed centre line.
        Positioned(
          left: 0,
          right: 0,
          bottom: _roadHeight - 3,
          height: 2,
          child: const ColoredBox(color: Colors.white38),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: _roadHeight / 2 - 2,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < 6; i++)
                const SizedBox(
                  width: 16,
                  height: 3,
                  child: ColoredBox(color: Colors.white70),
                ),
            ],
          ),
        ),
        // Tree on the near corner.
        const PositionedDirectional(
          bottom: _groundTop - 4,
          start: 16,
          child: _Tree(),
        ),
        // Bus shelter on the far corner.
        const PositionedDirectional(
          bottom: _groundTop - 4,
          end: 14,
          child: _BusShelter(),
        ),
        // Ground shadow + the spinning vehicle, wheels on the asphalt.
        Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 86,
              height: 10,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.all(Radius.elliptical(43, 5)),
                color: Color(0x2E000000),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 4,
          left: 0,
          right: 0,
          child: Center(
            child: VehicleTurntable(kind: kind, size: 118, animate: animate),
          ),
        ),
      ],
    );
  }
}

/// Soft rounded cloud blob for the street scene.
class _Cloud extends StatelessWidget {
  final double width;
  const _Cloud({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * 0.42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

/// Distant building silhouette; [lit] sprinkles a few window lights.
class _Building extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final bool lit;

  const _Building({
    required this.width,
    required this.height,
    required this.color,
    this.lit = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
      child: !lit
          ? null
          : Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var r = 0; r < 3; r++)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (var c = 0; c < 2; c++)
                        Container(
                          width: 4,
                          height: 5,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                    ],
                  ),
              ],
            ),
    );
  }
}

/// Round little sidewalk tree.
class _Tree extends StatelessWidget {
  const _Tree();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 30,
          height: 28,
          decoration: const BoxDecoration(
            color: Color(0xFF6FBF73),
            shape: BoxShape.circle,
          ),
        ),
        Container(width: 5, height: 14, color: const Color(0xFF8B6B4A)),
      ],
    );
  }
}

/// Tiny bus shelter: roof on two posts with the bus sign beside it.
class _BusShelter extends StatelessWidget {
  const _BusShelter();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 46,
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFF2F7DD1),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        SizedBox(
          width: 40,
          height: 24,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(width: 3, color: const Color(0xFF8A9299)),
              Container(
                margin: const EdgeInsets.only(top: 3),
                width: 18,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xFF2F7DD1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.white, width: 1.4),
                ),
                child: const Icon(
                  Icons.directions_bus_rounded,
                  size: 10,
                  color: Colors.white,
                ),
              ),
              Container(width: 3, color: const Color(0xFF8A9299)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tappable "About us" row that matches the collapsible-header style of the
/// sections above, so the whole settings block reads as one cohesive list.
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
              Icon(
                Icons.chevron_left_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
