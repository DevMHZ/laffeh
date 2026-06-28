import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';
import '../widgets/aim_aligned_reticle.dart';
import '../widgets/center_pin_widget.dart';
import '../widgets/glass_panel.dart';
import '../widgets/route_map_view.dart';

/// Full-screen "move a point" flow. While a point is being repositioned the
/// sheet / top-bar hide and this takes over: a reticle marks where the point
/// will land, a banner explains the gesture, and Save / Cancel commit or
/// discard the move.
class MovePointHost extends StatelessWidget {
  final GlobalKey<RouteMapViewState> mapKey;
  const MovePointHost({super.key, required this.mapKey});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) =>
          a.movingPointId != b.movingPointId || a.points != b.points,
      builder: (context, state) {
        final id = state.movingPointId;
        if (id == null) return const SizedBox.shrink();
        final cubit = context.read<RoutePlannerCubit>();
        final matches = state.points.where((p) => p.id == id).toList();
        final label = matches.isEmpty ? null : matches.first.label;

        Future<void> save() async {
          final mapState = mapKey.currentState;
          if (mapState == null) {
            cubit.cancelMovePoint();
            return;
          }
          final center = await mapState.resolveCenter();
          cubit.commitMovePoint(center);
        }

        return Stack(
          children: [
            // Reticle pinned to the true drop point, same as when adding.
            AimAlignedReticle(
              mapKey: mapKey,
              child: const IgnorePointer(
                child: CenterPinWidget(color: AppColors.info),
              ),
            ),
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
                        const Icon(
                          Iconsax.gps,
                          color: AppColors.info,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                label == null
                                    ? AppStrings.movePointTitle
                                    : '${AppStrings.movePointTitle} · $label',
                                style: AppTextStyles.titleSm,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                AppStrings.movePointHint,
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
                      onTap: cubit.cancelMovePoint,
                    ),
                    const SizedBox(width: 10),
                    MoveActionPill(
                      color: AppColors.primary,
                      foreground: AppColors.white,
                      icon: Iconsax.tick_circle,
                      label: AppStrings.saveLocation,
                      onTap: save,
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

class MoveActionPill extends StatelessWidget {
  final Color color;
  final Color foreground;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const MoveActionPill({
    super.key,
    required this.color,
    required this.foreground,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(99),
      elevation: 4,
      shadowColor: AppColors.shadow,
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.titleMd.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
