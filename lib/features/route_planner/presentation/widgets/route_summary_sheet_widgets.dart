part of 'route_summary_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// The trip's numbers, and the two actions that are not driving.
// ─────────────────────────────────────────────────────────────────────────────

/// Time · distance · stops, in one line.
///
/// This was a card of two labelled tiles — an icon in a tinted square, the
/// value, and a caption under it saying "estimated time" — plus a third
/// number, the stop count, in a chip beside the route-order heading further
/// down. Three numbers, three shapes, and a great deal of air between them on
/// a sheet whose job is to get a driver moving. A clock next to "38 min" does
/// not need a caption saying it is a time.
class _TripStrip extends StatelessWidget {
  final OptimizedRoute route;

  /// Everything the route calls at, the departure and the way home included —
  /// the same count the list below this strip shows.
  final int stops;

  const _TripStrip({required this.route, required this.stops});

  @override
  Widget build(BuildContext context) {
    final m = route.metrics;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _StatCell(
                icon: Iconsax.timer_1,
                color: AppColors.primary,
                value: m.estimatedDurationMinutes == null
                    ? AppStrings.unavailable
                    : MetricFormat.duration(m.estimatedDurationMinutes!),
              ),
            ),
            const _StatRule(),
            Expanded(
              child: _StatCell(
                icon: Iconsax.routing,
                color: AppColors.info,
                value: m.totalDistanceKm == null
                    ? AppStrings.unavailable
                    : MetricFormat.distance(m.totalDistanceKm!),
              ),
            ),
            const _StatRule(),
            Expanded(
              child: _StatCell(
                icon: Iconsax.location,
                color: AppColors.accent,
                value: AppStrings.pointsCount(stops),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _StatCell({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.titleSm,
          ),
        ),
      ],
    );
  }
}

class _StatRule extends StatelessWidget {
  const _StatRule();

  @override
  Widget build(BuildContext context) =>
      VerticalDivider(width: 1, thickness: 1, color: AppColors.border);
}

/// Preview, and open-in-Maps: real wants, neither of them this screen's job.
///
/// Both used to be full-width buttons in the app's secondary green, one of
/// them sitting above "start driving" — which is how a rehearsal of the trip
/// came to be the thing drivers tapped. Half width, side by side, and grey
/// enough that the only filled control in the sheet is the one that starts
/// the trip.
class _SecondaryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _SecondaryAction({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt,
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
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleSm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StartFreshButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _StartFreshButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.danger.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.mediumImpact();
          onPressed();
        },
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.danger.withValues(alpha: 0.45),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.trash, color: AppColors.danger, size: 19),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  AppStrings.startFresh,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMd.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact icon + label tile for tertiary actions (Save / CSV).
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionTile({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 21, color: AppColors.textPrimary),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.mutedSm.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Read-only full-width row used in the summary sheet's route sequence — one
/// per line for clear order reading. Shows the order badge, the label, and the
/// address when known. No tap action — the route is already optimized.
class _SummaryGridCell extends StatelessWidget {
  final RoutePoint point;
  final int index;
  final Color color;
  final IconData icon;

  /// Departure clock (minutes since midnight) the route was solved for —
  /// the origin the stop's ETA is offset from.
  final int departureMinute;

  /// Set on the last row only, where tapping changes how the day ends.
  final VoidCallback? onTap;

  const _SummaryGridCell({
    super.key,
    required this.point,
    required this.index,
    required this.color,
    required this.icon,
    required this.departureMinute,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final address = point.address?.trim();
    final cell = Opacity(
      opacity: point.isDeactivated ? 0.55 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: point.optional && !point.isDeactivated
                ? AppColors.optional.withValues(alpha: 0.35)
                : AppColors.white.withValues(alpha: 0.72),
          ),
        ),
        child: Row(
          children: [
            _SummaryCellBadge(color: color, icon: icon, index: index),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    point.label,
                    style: AppTextStyles.titleSm,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (address != null && address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      address,
                      style: AppTextStyles.mutedSm,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            _StopEta(point: point, departureMinute: departureMinute),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(
                Iconsax.arrow_right_3,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return cell;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: cell,
      ),
    );
  }
}

/// Trailing arrival column for a stop in the optimised sequence.
///
/// Shows the projected arrival clock (computed from the road legs — the
/// backend's own `arrival_time` is always 0) and, for a stop the user gave
/// a deadline, whether that deadline holds.
class _StopEta extends StatelessWidget {
  final RoutePoint point;
  final int departureMinute;

  const _StopEta({required this.point, required this.departureMinute});

  @override
  Widget build(BuildContext context) {
    final eta = point.etaMinutesFromDeparture;
    final window = point.timeWindow;
    if (eta == null && window == null) return const SizedBox.shrink();

    // No window, nothing to miss — a stop the user never gave a time to
    // must never be coloured late (see RoutePoint.timeWindowMissed).
    final missed = window != null && point.timeWindowMissed;
    final tone = missed
        ? AppColors.danger
        : window != null
        ? AppColors.primary
        : AppColors.textMuted;

    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Projected arrival. Labelled once a deadline exists, so it can
          // never be mistaken for the time the user asked for.
          if (eta != null)
            _EtaLine(
              label: window == null ? null : AppStrings.expectedArrival,
              value: formatMinuteOfDay(
                context,
                StopTimeWindow.clockFromRelative(departureMinute, eta),
              ),
              color: tone,
              emphasised: true,
            ),

          // The time the user actually asked for. Always shown when a
          // deadline is set — a late stop needs it *most*, since "you'd
          // arrive at 1:07" means nothing without "you wanted 12:30".
          if (window != null) ...[
            const SizedBox(height: 1),
            _EtaLine(
              label: AppStrings.requiredArrival,
              value: formatMinuteOfDay(context, window.endMinuteOfDay),
              color: missed ? AppColors.textSecondary : tone,
              icon: missed ? null : Iconsax.clock,
            ),
          ],

          // How far past it we land — the size of the problem.
          if (missed) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Iconsax.warning_2, size: 10, color: AppColors.danger),
                const SizedBox(width: 3),
                Text(
                  point.latenessMinutes != null
                      ? AppStrings.lateByMinutes(point.latenessMinutes!)
                      : AppStrings.timeWindowMissedBadge,
                  style: AppTextStyles.bodySm.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One "label · time" line in a stop's trailing arrival column.
class _EtaLine extends StatelessWidget {
  final String? label;
  final String value;
  final Color color;
  final IconData? icon;
  final bool emphasised;

  const _EtaLine({
    required this.value,
    required this.color,
    this.label,
    this.icon,
    this.emphasised = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
        ],
        if (label != null) ...[
          Text(
            label!,
            style: AppTextStyles.bodySm.copyWith(
              fontSize: 9,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 4),
        ],
        Text(
          value,
          style: emphasised
              ? AppTextStyles.titleSm.copyWith(color: color)
              : AppTextStyles.bodySm.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
        ),
      ],
    );
  }
}

class _SummaryCellBadge extends StatelessWidget {
  final Color color;
  final IconData icon;
  final int index;

  const _SummaryCellBadge({
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

/// Closing row for an open route.
///
/// An open route has no terminal point, so there is no cell to hang the
/// "where does the day end" choice off. This states the outcome instead, and
/// stays tappable so the choice is never a one-way door.
class _OpenFinishRow extends StatelessWidget {
  final String lastStopLabel;
  final VoidCallback onTap;

  const _OpenFinishRow({required this.lastStopLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(
                Iconsax.location_tick,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppStrings.finishEndsAt(lastStopLabel),
                  style: AppTextStyles.mutedSm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Iconsax.arrow_right_3,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
