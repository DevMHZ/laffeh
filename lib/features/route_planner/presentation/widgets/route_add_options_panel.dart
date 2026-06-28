import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/whatsapp_glyph.dart';

/// The empty-state entry point, revealed in stages so the first thing the
/// user sees is a single calm call-to-action over a clean map:
///
///   1. [_PanelView.collapsed] — just an "Add a stop" button.
///   2. [_PanelView.options]   — tap it to reveal the three ways to add
///      (manual / WhatsApp / paste-import) in a frosted card.
///   3. [_PanelView.manual]    — choosing "manual" shows a confirm CTA and
///      asks the host to reveal the map crosshair (via [onBeginManual]).
class RouteAddOptionsPanel extends StatefulWidget {
  /// Drops a point at the map crosshair (same as the sheet's "add here").
  final VoidCallback? onAddHere;

  /// Opens WhatsApp so the user can share a location back to Laffah.
  final VoidCallback? onOpenWhatsapp;

  /// Shows the "how WhatsApp import works" explainer (the `i` button).
  final VoidCallback? onShowWhatsappInfo;

  /// Opens the paste-or-import-CSV chooser.
  final VoidCallback? onShowImport;

  /// Entering / leaving the manual-placement flow — the host forwards these
  /// to the cubit so the centre crosshair shows only while placing.
  final VoidCallback? onBeginManual;
  final VoidCallback? onCancelManual;

  const RouteAddOptionsPanel({
    super.key,
    this.onAddHere,
    this.onOpenWhatsapp,
    this.onShowWhatsappInfo,
    this.onShowImport,
    this.onBeginManual,
    this.onCancelManual,
  });

  @override
  State<RouteAddOptionsPanel> createState() => _RouteAddOptionsPanelState();
}

enum _PanelView { collapsed, options, manual }

class _RouteAddOptionsPanelState extends State<RouteAddOptionsPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  _PanelView _view = _PanelView.collapsed;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  void _showOptions() {
    HapticFeedback.selectionClick();
    _entrance.forward(from: 0);
    setState(() => _view = _PanelView.options);
  }

  void _enterManual() {
    HapticFeedback.selectionClick();
    widget.onBeginManual?.call();
    setState(() => _view = _PanelView.manual);
  }

  void _backToOptions() {
    widget.onCancelManual?.call();
    setState(() => _view = _PanelView.options);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: switch (_view) {
        _PanelView.collapsed => _buildCollapsed(),
        _PanelView.options => _buildOptions(),
        _PanelView.manual => _buildManual(),
      },
    );
  }

  // Just the entry button — deliberately NOT inside the frosted card so an
  // untouched screen reads as a single, calm CTA.
  Widget _buildCollapsed() {
    return _GreenCta(
      key: const ValueKey('collapsed'),
      icon: Iconsax.location_add,
      label: AppStrings.addPointCta,
      onTap: _showOptions,
    );
  }

  Widget _buildOptions() {
    return _frostedCard(
      key: const ValueKey('options'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppStrings.addOptHeader,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleMd,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _staggered(
                  0,
                  _OptionTile(
                    icon: Iconsax.flag,
                    color: AppColors.warning,
                    label: AppStrings.addOptManualTitle,
                    onTap: _enterManual,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _staggered(
                  1,
                  _OptionTile(
                    icon: Iconsax.message,
                    iconWidget: const WhatsappGlyph(
                      size: 24,
                      color: AppColors.primary,
                    ),
                    color: AppColors.primary,
                    label: AppStrings.addOptWhatsappTitle,
                    onTap: widget.onOpenWhatsapp,
                    corner: _InfoButton(onTap: widget.onShowWhatsappInfo),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _staggered(
                  2,
                  _OptionTile(
                    icon: Iconsax.document_upload,
                    color: AppColors.info,
                    label: AppStrings.addOptImportTitle,
                    onTap: widget.onShowImport,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Confirm-placement view: the green CTA drops the departure at the map
  /// crosshair; the back link returns to the three options.
  Widget _buildManual() {
    return _frostedCard(
      key: const ValueKey('manual'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Iconsax.flag, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppStrings.addDepartureHint,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _GreenCta(
            icon: Iconsax.flag,
            label: AppStrings.setDepartureHere,
            onTap: widget.onAddHere,
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _backToOptions,
            icon: const Icon(Iconsax.arrow_left_2, size: 16),
            label: Text(AppStrings.addOptManualBack),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// The frosted, blurred card that backs the options / manual views. Uses
  /// `BackdropFilter.grouped` so it joins the page's single backdrop pass
  /// ([BackdropGroup] in the planner page) instead of sampling on its own.
  Widget _frostedCard({required Key key, required Widget child}) {
    return DecoratedBox(
      key: key,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter.grouped(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.white.withValues(alpha: 0.65),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  Widget _staggered(int index, Widget child) {
    final start = index * 0.16;
    final anim = CurvedAnimation(
      parent: _entrance,
      curve: Interval(
        start,
        (start + 0.6).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (context, inner) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, (1 - anim.value) * 14),
          child: inner,
        ),
      ),
      child: child,
    );
  }
}

/// One compact option: a colored icon badge over a short label. Tappable;
/// an optional [corner] widget (the WhatsApp info button) floats at the top.
class _OptionTile extends StatelessWidget {
  final IconData icon;

  /// When set, rendered in the badge instead of [icon] — used for the real
  /// WhatsApp logo glyph.
  final Widget? iconWidget;
  final Color color;
  final String label;
  final VoidCallback? onTap;
  final Widget? corner;

  const _OptionTile({
    required this.icon,
    this.iconWidget,
    required this.color,
    required this.label,
    this.onTap,
    this.corner,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    onTap!();
                  },
            // Fixed height + a reserved 2-line label slot so every tile's
            // icon and text sit at the exact same level, whether the label
            // wraps to one line or two.
            child: Container(
              height: 108,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.white.withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: iconWidget ?? Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 32,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleSm.copyWith(height: 1.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (corner != null)
            PositionedDirectional(top: 4, start: 4, child: corner!),
        ],
      ),
    );
  }
}

/// The small "i" affordance on the WhatsApp tile — opens the explainer
/// without triggering the tile's own tap.
class _InfoButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _InfoButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: AppStrings.onbImportTitle,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: const SizedBox(
            width: 30,
            height: 30,
            child: Icon(
              Iconsax.info_circle,
              size: 16,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Wide green call-to-action — the collapsed "add a stop" entry and the
/// manual-mode "set departure here" confirm both use it.
class _GreenCta extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _GreenCta({super.key, required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.30),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onTap!();
                },
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppColors.white, size: 20),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.button.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
