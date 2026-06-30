import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';
import '../widgets/glass_panel.dart';
import '../widgets/route_map_view.dart';
import 'route_planner_move_overlay.dart';

/// Full-screen "pick on the map" flow, reached from the add-a-point chooser.
/// While active the sheet / empty-state card hide and this takes over: the
/// shared centre crosshair ([CenterPin]) marks the drop point, a banner
/// explains the gesture, and Cancel / Confirm discard or drop the point.
///
/// Mirrors [MovePointHost] but for placing a *new* point rather than moving an
/// existing one.
class ManualPlacementHost extends StatelessWidget {
  final GlobalKey<RouteMapViewState> mapKey;
  const ManualPlacementHost({super.key, required this.mapKey});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) =>
          a.manualPlacement != b.manualPlacement ||
          a.points.isEmpty != b.points.isEmpty,
      builder: (context, state) {
        if (!state.manualPlacement) return const SizedBox.shrink();
        final cubit = context.read<RoutePlannerCubit>();
        final isFirst = state.points.isEmpty;

        Future<void> confirm() async {
          final mapState = mapKey.currentState;
          if (mapState == null) {
            cubit.cancelManualPlacement();
            return;
          }
          final center = await mapState.resolveCenter();
          cubit.addPoint(center);
          cubit.cancelManualPlacement();
        }

        return Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: GlassPanel(
                    radius: 18,
                    child: Row(
                      children: [
                        Icon(
                          isFirst ? Iconsax.flag : Iconsax.location_add,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isFirst
                                    ? AppStrings.setDepartureHere
                                    : AppStrings.addStopHere,
                                style: AppTextStyles.titleSm,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                AppStrings.placePointHint,
                                style: AppTextStyles.mutedSm,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + 24,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MoveActionPill(
                      color: AppColors.surface,
                      foreground: AppColors.textSecondary,
                      icon: Iconsax.close_circle,
                      label: AppStrings.cancel,
                      onTap: cubit.cancelManualPlacement,
                    ),
                    const SizedBox(width: 10),
                    MoveActionPill(
                      color: AppColors.primary,
                      foreground: AppColors.white,
                      icon: Iconsax.tick_circle,
                      label: isFirst
                          ? AppStrings.setDepartureHere
                          : AppStrings.addStopHere,
                      onTap: confirm,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
