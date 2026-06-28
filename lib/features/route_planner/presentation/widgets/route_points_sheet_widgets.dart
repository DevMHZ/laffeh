part of 'route_points_sheet.dart';

/// One point in the planning grid: a numbered badge, the label, and a
/// short location line. Tapping opens [showPointActions] for the full
/// address plus rename / move / optional / delete. A deactivated optional
/// point reads as faded.
class _PointGridCell extends StatelessWidget {
  final RoutePoint point;
  final int index;
  final VoidCallback onTap;

  const _PointGridCell({
    super.key,
    required this.point,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dimmed = point.isDeactivated;
    final color = point.isDepot
        ? AppColors.primary
        : point.optional
        ? AppColors.optional
        : AppColors.info;
    final icon = point.isDepot
        ? Iconsax.flag
        : point.optional
        ? Iconsax.star_1
        : Iconsax.location;

    return Opacity(
      opacity: dimmed ? 0.55 : 1.0,
      child: Material(
        color: AppColors.surfaceAlt.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: point.optional && !dimmed
                    ? AppColors.optional.withValues(alpha: 0.35)
                    : AppColors.white.withValues(alpha: 0.72),
              ),
            ),
            child: Row(
              children: [
                _CellBadge(
                  color: dimmed ? AppColors.optionalOff : color,
                  icon: icon,
                  index: index,
                ),
                const SizedBox(width: 7),
                // Just the label in the cell (2 lines max) — the full
                // address is one tap away in showPointActions.
                Expanded(
                  child: Text(
                    point.label,
                    style: AppTextStyles.titleSm,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

/// Small round icon badge with the point's order number tucked at its
/// corner — the grid-cell counterpart of the list tile's leading avatar.
class _CellBadge extends StatelessWidget {
  final Color color;
  final IconData icon;
  final int index;

  const _CellBadge({
    required this.color,
    required this.icon,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 16),
        ),
        Positioned(
          bottom: -3,
          right: -3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '$index',
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// All the "add a point" paths on one line, docked at the top of the
/// planning sheet so nothing floats over the map. Mirrors the three options
/// the empty state offers (RouteAddOptionsPanel): manual, paste/CSV, WhatsApp.
///
/// Layout: a compact paste-or-import button, then the emphasised "Add stop
/// here" CTA expanded in the centre (the hero — asphalt until a departure is
/// set, brand green afterwards, matching the centre pin), then a compact
/// WhatsApp button.
class _AddControlsRow extends StatelessWidget {
  final bool hasDepot;
  final VoidCallback? onAddHere;
  final VoidCallback? onShowImport;
  final VoidCallback? onOpenWhatsapp;

  const _AddControlsRow({
    required this.hasDepot,
    this.onAddHere,
    this.onShowImport,
    this.onOpenWhatsapp,
  });

  @override
  Widget build(BuildContext context) {
    final color = hasDepot ? AppColors.primary : AppColors.asphalt;
    return Row(
      children: [
        if (onShowImport != null) ...[
          _SquareIconButton(
            icon: Iconsax.document_upload,
            background: AppColors.surfaceAlt,
            foreground: AppColors.info,
            tooltip: AppStrings.addOptImportTitle,
            onTap: onShowImport,
          ),
          const SizedBox(width: 8),
        ],
        // The hero: expanded so it dominates the centre of the row.
        if (onAddHere != null)
          Expanded(
            child: _AddHereCta(
              color: color,
              icon: hasDepot ? Iconsax.location_add : Iconsax.flag,
              label: hasDepot
                  ? AppStrings.addStopHere
                  : AppStrings.setDepartureHere,
              onTap: onAddHere,
            ),
          )
        else
          const Spacer(),
        if (onOpenWhatsapp != null) ...[
          const SizedBox(width: 8),
          _SquareIconButton(
            icon: Iconsax.message,
            iconWidget: const WhatsappGlyph(
              size: 22,
              color: AppColors.primary,
            ),
            background: AppColors.primarySoft,
            foreground: AppColors.primary,
            tooltip: AppStrings.addOptWhatsappTitle,
            onTap: onOpenWhatsapp,
          ),
        ],
      ],
    );
  }
}

/// Compact 52×52 icon button for the secondary add paths (paste / CSV).
/// Icon-only with a tooltip so the row stays tight and the centre CTA
/// keeps the spotlight.
class _SquareIconButton extends StatelessWidget {
  final IconData icon;
  final Widget? iconWidget;
  final Color background;
  final Color foreground;
  final String tooltip;
  final VoidCallback? onTap;

  const _SquareIconButton({
    required this.icon,
    this.iconWidget,
    required this.background,
    required this.foreground,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            child: iconWidget ?? Icon(icon, color: foreground, size: 22),
          ),
        ),
      ),
    );
  }
}

/// Wide, filled call-to-action that drops a point at the map crosshair.
class _AddHereCta extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _AddHereCta({
    required this.color,
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // AnimatedContainer so the colour eases asphalt → green the moment the
    // departure is placed, matching the centre pin's transition.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      height: 52,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.30),
            blurRadius: 14,
            offset: const Offset(0, 6),
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


class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.asphalt.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.asphalt.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.wifi_square, color: AppColors.asphalt, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.offlineTitle,
                  style: AppTextStyles.titleSm.copyWith(color: AppColors.asphalt),
                ),
                Text(
                  AppStrings.offlineBody,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftRestoredHint extends StatelessWidget {
  const _DraftRestoredHint();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Iconsax.refresh_circle, color: AppColors.primary, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            AppStrings.draftRestoredMsg,
            style: AppTextStyles.mutedSm.copyWith(color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class _ReadinessBanner extends StatelessWidget {
  final int pointsCount;

  const _ReadinessBanner({required this.pointsCount});

  @override
  Widget build(BuildContext context) {
    final ready = pointsCount >= 2;
    final color = ready
        ? AppColors.success
        : pointsCount == 0
        ? AppColors.primary
        : AppColors.warning;
    final message = ready
        ? AppStrings.readyToOptimize
        : pointsCount == 0
        ? AppStrings.setDepartureFirst
        : AppStrings.addOneStopToOptimize;
    final icon = ready
        ? Iconsax.tick_circle
        : pointsCount == 0
        ? Iconsax.flag
        : Iconsax.location_add;

    return _MessageBanner(icon: icon, color: color, message: message);
  }
}

class _MessageBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  /// Optional call-to-action (e.g. "Enable location") rendered as a
  /// button under the message — turns a dead-end warning into a one-tap
  /// fix.
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const _MessageBanner({
    required this.icon,
    required this.color,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final hasAction = onAction != null && actionLabel != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyles.bodySm.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (hasAction) ...[
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Material(
                color: color,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onAction!();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          actionIcon ?? Iconsax.location,
                          color: AppColors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          actionLabel!,
                          style: AppTextStyles.titleSm.copyWith(
                            color: AppColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Destructive "wipe everything and start over" action, shown below the
/// optimise CTA once at least one point exists. Visually subordinate to the
/// green primary CTA (outlined danger) and always confirms first via
/// [confirmClearAll], so a stray tap can't lose the trip.
class _ClearAllButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _ClearAllButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.mediumImpact();
            onPressed();
          },
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Iconsax.trash, color: AppColors.danger, size: 18),
                const SizedBox(width: 8),
                Text(
                  AppStrings.clearAll,
                  style: AppTextStyles.titleMd.copyWith(
                    color: AppColors.danger,
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

/// Confirms before wiping all points (and the saved draft), then clears.
Future<void> confirmClearAll(BuildContext context) {
  final cubit = context.read<RoutePlannerCubit>();
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(22, 24, 22, 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Iconsax.trash, color: AppColors.danger, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            AppStrings.clearAll,
            style: AppTextStyles.h3,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.clearRouteConfirm,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppStrings.cancel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    HapticFeedback.mediumImpact();
                    cubit.clearAll();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(AppStrings.remove),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
