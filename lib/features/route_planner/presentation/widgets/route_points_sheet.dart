import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../domain/entities/route_point.dart';
import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';
import 'optimize_route_button.dart';
import 'point_actions_sheet.dart';

part 'route_points_sheet_widgets.dart';

class RoutePointsSheet extends StatelessWidget {
  /// Opens the per-point add-method chooser (type an address / pick on the
  /// map / from WhatsApp). The single entry point for adding another stop,
  /// docked at the top of the sheet so the map stays as clear as possible.
  final VoidCallback? onAddPoint;

  const RoutePointsSheet({super.key, this.onAddPoint});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) =>
          a.points != b.points ||
          a.status != b.status ||
          a.errorMessage != b.errorMessage ||
          a.isOffline != b.isOffline ||
          a.draftRestored != b.draftRestored,
      builder: (context, state) {
        final cubit = context.read<RoutePlannerCubit>();

        // Location-blocked warnings get a one-tap "Enable location"
        // action; other warnings (e.g. min-two-points) don't.
        final isLocationIssue =
            state.errorMessage == AppStrings.errLocationServiceDisabled ||
            state.errorMessage == AppStrings.errLocationPermissionDenied;

        // No title / count header: the add controls below make the
        // sheet's purpose obvious and the empty state has its own hint,
        // so dropping the title row (and the big empty gutter beside it)
        // hands that vertical space back to the map. Only the drag handle
        // stays.
        return AppSheetContainer(
          contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Add another stop ─────────────────────────────────────
              //    A single CTA that opens the same add-method chooser used
              //    everywhere (type an address / pick on the map / WhatsApp),
              //    so every point is added the same way.
              if (onAddPoint != null) ...[
                _AddStopCta(onTap: onAddPoint),
                const SizedBox(height: 14),
              ],

              // Offline first — it explains why a sync/optimize may wait.
              if (state.isOffline) ...[
                const _OfflineBanner(),
                const SizedBox(height: 10),
              ] else if (state.draftRestored && state.hasPoints) ...[
                const _DraftRestoredHint(),
                const SizedBox(height: 10),
              ],

              if (state.errorMessage != null &&
                  state.status != RoutePlannerStatus.optimizedFailure) ...[
                _MessageBanner(
                  icon: Iconsax.info_circle,
                  color: AppColors.warning,
                  message: state.errorMessage!,
                  actionLabel: isLocationIssue
                      ? AppStrings.enableLocationCta
                      : null,
                  actionIcon: Iconsax.location,
                  onAction: isLocationIssue
                      ? cubit.resolveLocationAccess
                      : null,
                ),
                const SizedBox(height: 10),
              ],

              // Compact grid — points laid out a couple per row to keep the
              // sheet small. Tapping a cell opens its full address + actions
              // (rename / move / optional / delete) through the shared
              // showPointActions sheet. Ordering is owned by the optimizer
              // (#6), so cells aren't reorderable. (The empty state lives in
              // the screen-level AddOptionsHost, so the sheet always has at
              // least one point here.)
              const SizedBox(height: 6),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: state.points.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisExtent: 54,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, i) {
                  final p = state.points[i];
                  return _PointGridCell(
                    key: ValueKey(p.id),
                    point: p,
                    index: i + 1,
                    onTap: () => showPointActions(context, p),
                  );
                },
              ),
              const SizedBox(height: 6),

              if (state.errorMessage != null &&
                  state.status == RoutePlannerStatus.optimizedFailure) ...[
                const SizedBox(height: 10),
                _MessageBanner(
                  icon: Iconsax.info_circle,
                  color: AppColors.danger,
                  message: state.errorMessage!,
                ),
              ],
              const SizedBox(height: 14),
              _ReadinessBanner(pointsCount: state.routableCount),
              const SizedBox(height: 10),
              OptimizeRouteButton(
                onPressed: cubit.optimize,
                enabled: state.canOptimize,
                loading: state.isOptimizing,
              ),

              // Destructive escape hatch — only once there's something to
              // clear, kept visually below the primary "optimise" CTA.
              if (state.hasPoints) ...[
                const SizedBox(height: 10),
                _ClearAllButton(onPressed: () => confirmClearAll(context)),
              ],
            ],
          ),
        );
      },
    );
  }

}
