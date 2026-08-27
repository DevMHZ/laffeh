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
                // Just the label in the cell — the full address is one tap
                // away in showPointActions. A stop with an arrival time
                // gives up its second label line to show the deadline,
                // which is the thing the user is scanning for.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        point.label,
                        style: AppTextStyles.titleSm,
                        maxLines: point.hasTimeWindow ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (point.hasTimeWindow) _CellTimeLine(point: point),
                    ],
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

/// The "be there by 15:30" line inside a grid cell. Turns red once an
/// optimization has shown the stop can't be reached in time.
class _CellTimeLine extends StatelessWidget {
  final RoutePoint point;

  const _CellTimeLine({required this.point});

  @override
  Widget build(BuildContext context) {
    final missed = point.timeWindowMissed;
    final color = missed ? AppColors.danger : AppColors.info;
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Row(
        children: [
          Icon(
            missed ? Iconsax.warning_2 : Iconsax.clock,
            size: 10,
            color: color,
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              formatMinuteOfDay(context, point.timeWindow!.endMinuteOfDay),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySm.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
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

/// Where the trip starts, and the one tap that changes it.
///
/// The planner's twin of the navigator card's "From ·" line, and deliberately
/// the same sentence in both: a driver who learns the assumption on a
/// one-stop trip should find it in the same words when they build a round.
class _StartFromRow extends StatelessWidget {
  /// The departure the driver named. Null — the usual case — means the trip
  /// still starts wherever they happen to be.
  final RoutePoint? from;
  final VoidCallback onTap;

  const _StartFromRow({required this.from, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final chosen = from;
    final named = chosen?.address?.trim();
    final label = chosen == null
        ? AppStrings.currentLocationLabel
        : (named != null && named.isNotEmpty)
        ? named
        : AppStrings.departure;

    return Material(
      color: AppColors.surfaceAlt.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(
                chosen == null ? Icons.my_location_rounded : Iconsax.flag,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Text('${AppStrings.fromLabel} · ', style: AppTextStyles.mutedSm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleSm,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Iconsax.edit_2, size: 16, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// When the trip starts — the anchor every stop's arrival window is
/// measured from, since the solver only thinks in minutes-after-departure.
///
/// Only shown once at least one stop has a time window; before that the
/// departure clock changes nothing and would just be another control to
/// ignore. Defaults to "Now"; tapping picks a time, and a set time can be
/// handed back to "Now" with the reset button.
class _DepartureRow extends StatelessWidget {
  final DateTime? departureAt;
  final ValueChanged<DateTime?> onChanged;

  const _DepartureRow({required this.departureAt, required this.onChanged});

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final base = departureAt ?? now;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: base.hour, minute: base.minute),
    );
    if (picked == null) return;

    var departure = DateTime(
      now.year,
      now.month,
      now.day,
      picked.hour,
      picked.minute,
    );
    // A time that has already gone by today means tomorrow's trip.
    if (departure.isBefore(now)) {
      departure = departure.add(const Duration(days: 1));
    }
    onChanged(departure);
  }

  @override
  Widget build(BuildContext context) {
    final isNow = departureAt == null;
    final value = isNow
        ? AppStrings.departureNow
        : TimeOfDay.fromDateTime(departureAt!).format(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(Iconsax.timer_start, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.departureTimeLabel,
                  style: AppTextStyles.titleSm,
                ),
                Text(AppStrings.departureHint, style: AppTextStyles.mutedSm),
              ],
            ),
          ),
          if (!isNow)
            IconButton(
              tooltip: AppStrings.departureNow,
              visualDensity: VisualDensity.compact,
              onPressed: () {
                HapticFeedback.selectionClick();
                onChanged(null);
              },
              icon: Icon(
                Iconsax.refresh_circle,
                size: 18,
                color: AppColors.textMuted,
              ),
            ),
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              _pick(context);
            },
            child: Text(
              value,
              style: AppTextStyles.titleSm.copyWith(color: AppColors.primary),
            ),
          ),
        ],
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
          Icon(Iconsax.wifi_square, color: AppColors.asphalt, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.offlineTitle,
                  style: AppTextStyles.titleSm.copyWith(
                    color: AppColors.asphalt,
                  ),
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
        Icon(Iconsax.refresh_circle, color: AppColors.primary, size: 16),
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
                Icon(Iconsax.trash, color: AppColors.danger, size: 18),
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
///
/// Goes through [AppDialog] like every other decision in the app: a hand-made
/// AlertDialog here meant the one moment a driver can lose their whole trip
/// was also the one moment the app stopped looking like itself.
Future<void> confirmClearAll(BuildContext context) async {
  final cubit = context.read<RoutePlannerCubit>();
  final confirmed = await AppDialog.confirm(
    context: context,
    title: AppStrings.clearAll,
    message: AppStrings.clearRouteConfirm,
    icon: Iconsax.trash,
    tone: AppDialogTone.danger,
    confirmLabel: AppStrings.remove,
    confirmIcon: Iconsax.trash,
    destructive: true,
  );
  if (confirmed != true) return;
  HapticFeedback.mediumImpact();
  cubit.clearAll();
}
