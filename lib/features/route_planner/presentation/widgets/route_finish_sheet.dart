import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/route_finish.dart';
import '../cubit/route_planner_cubit.dart';
import '../pages/route_planner_actions.dart';

/// Lets the driver say where their day ends.
///
/// Three choices, because that is all there are: back where you started, stop
/// at the last stop, or somewhere of your own. Picking the third opens the
/// same place search the rest of the planner uses, so there is one way to name
/// a place in this app.
///
/// Returns the chosen finish, or null when the sheet is dismissed unchanged.
Future<RouteFinish?> showRouteFinishSheet(
  BuildContext context,
  RoutePlannerCubit cubit, {
  required RouteFinish current,
}) {
  return showModalBottomSheet<RouteFinish>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _RouteFinishBody(cubit: cubit, current: current),
  );
}

class _RouteFinishBody extends StatelessWidget {
  final RoutePlannerCubit cubit;
  final RouteFinish current;

  const _RouteFinishBody({required this.cubit, required this.current});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.endOfDay, style: AppTextStyles.titleMd),
            const SizedBox(height: 12),
            _Option(
              // Home for the round trip (it ends at the departure, which now
              // wears a house), the flag for a finish of the driver's own.
              icon: Iconsax.home_2,
              title: AppStrings.finishRoundTrip,
              subtitle: AppStrings.finishRoundTripHint,
              selected: current.mode == RouteEndMode.depot,
              onTap: () =>
                  Navigator.of(context).pop(const RouteFinish.depot()),
            ),
            const SizedBox(height: 8),
            _Option(
              icon: Iconsax.location_tick,
              title: AppStrings.finishOpen,
              subtitle: AppStrings.finishOpenHint,
              selected: current.mode == RouteEndMode.open,
              onTap: () => Navigator.of(context).pop(const RouteFinish.open()),
            ),
            const SizedBox(height: 8),
            _Option(
              icon: Iconsax.flag,
              title: AppStrings.finishCustom,
              // Once a place is chosen, show it instead of the generic hint:
              // the row then answers "finish where?" on its own.
              subtitle: current.mode == RouteEndMode.custom &&
                      current.label?.isNotEmpty == true
                  ? current.label!
                  : AppStrings.finishCustomHint,
              selected: current.mode == RouteEndMode.custom,
              trailing: Text(
                AppStrings.finishPickPlace,
                style: AppTextStyles.mutedSm.copyWith(
                  color: AppColors.primary,
                ),
              ),
              // Hands off to the full place picker: typing an address, the
              // map, Google Maps and WhatsApp, the same four ways any other
              // place in this app can be named. That picker sets the finish
              // itself, so this sheet just steps out of the way.
              onTap: () {
                Navigator.of(context).pop();
                RoutePlannerActions.showFinishPlacePicker(context, cubit);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final Widget? trailing;
  final VoidCallback onTap;

  const _Option({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
                        color: selected ? AppColors.primary : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.mutedSm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(Iconsax.tick_circle,
                    size: 20, color: AppColors.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
