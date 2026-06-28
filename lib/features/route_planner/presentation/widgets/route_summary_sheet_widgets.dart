part of 'route_summary_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Compact metrics row — replaces the old GridView card layout.
// One thin bar with icon + value + label for each metric, separated by a line.
// ─────────────────────────────────────────────────────────────────────────────

class _InlineMetrics extends StatelessWidget {
  final OptimizedRoute route;
  const _InlineMetrics({required this.route});

  @override
  Widget build(BuildContext context) {
    final m = route.metrics;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _MetricItem(
              icon: Iconsax.timer_1,
              label: AppStrings.estimatedTime,
              value: m.estimatedDurationMinutes == null
                  ? AppStrings.unavailable
                  : MetricFormat.duration(m.estimatedDurationMinutes!),
              color: AppColors.primary,
            ),
          ),
          Container(width: 1, height: 32, color: AppColors.border),
          Expanded(
            child: _MetricItem(
              icon: Iconsax.routing,
              label: AppStrings.totalDistance,
              value: m.totalDistanceKm == null
                  ? AppStrings.unavailable
                  : MetricFormat.distance(m.totalDistanceKm!),
              color: AppColors.info,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 9),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: AppTextStyles.titleMd),
            Text(label, style: AppTextStyles.mutedSm),
          ],
        ),
      ],
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
              const Icon(Iconsax.trash, color: AppColors.danger, size: 19),
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

class _StartNavigationButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _StartNavigationButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final arrowIcon = Directionality.of(context) == TextDirection.rtl
        ? Icons.arrow_back_rounded
        : Icons.arrow_forward_rounded;

    return Material(
      borderRadius: BorderRadius.circular(16),
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [AppColors.accent, AppColors.accentDark],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.30),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Iconsax.play,
                  color: AppColors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.startNavigation,
                      style: AppTextStyles.titleLg.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppStrings.navigationSubtitle,
                      style: AppTextStyles.bodySm.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(arrowIcon, color: AppColors.white, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// Read-only grid cell used in the summary sheet's route sequence.
/// Same visual style as the planning sheet's _PointGridCell, but
/// no tap action — the route is already optimized.
class _SummaryGridCell extends StatelessWidget {
  final RoutePoint point;
  final int index;
  final Color color;
  final IconData icon;

  const _SummaryGridCell({
    super.key,
    required this.point,
    required this.index,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: point.isDeactivated ? 0.55 : 1.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
            const SizedBox(width: 7),
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
