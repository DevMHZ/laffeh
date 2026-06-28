import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';
import '../widgets/glass_panel.dart';
import 'route_planner_actions.dart';

/// Floating top bar: saved-routes button, the Stops→Route→Drive stepper,
/// and the settings button. Hidden during preview / drive / move-a-point.
class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) =>
          a.simulationActive != b.simulationActive ||
          a.navigationActive != b.navigationActive ||
          a.optimizedRoute != b.optimizedRoute ||
          a.movingPointId != b.movingPointId ||
          a.points.isEmpty != b.points.isEmpty,
      builder: (context, state) {
        if (state.simulationActive ||
            state.navigationActive ||
            state.movingPointId != null) {
          return const SizedBox.shrink();
        }
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Row(
                children: [
                  GlassPanel(
                    padding: EdgeInsets.zero,
                    radius: 22,
                    child: TopIconButton(
                      tooltip: AppStrings.savedRoutes,
                      icon: Iconsax.archive_book,
                      onPressed: () =>
                          RoutePlannerActions.openSavedRoutes(context),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      // Hidden on the empty first screen, then pops in once
                      // the first point lands.
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(scale: anim, child: child),
                        ),
                        child: (state.hasPoints || state.hasOptimizedRoute)
                            ? StepIndicator(
                                step: state.hasOptimizedRoute ? 1 : 0,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  GlassPanel(
                    padding: EdgeInsets.zero,
                    radius: 22,
                    child: TopIconButton(
                      tooltip: AppStrings.settings,
                      icon: Iconsax.setting_2,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsPage(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Slim Stops → Route → Drive progress chip. Appears once the first point
/// is placed and tells the user which phase of the trip they're in.
class StepIndicator extends StatelessWidget {
  /// 0 = adding stops, 1 = route ready, 2 = driving.
  final int step;

  const StepIndicator({super.key, required this.step});

  static List<String> get _labels => [
    AppStrings.stepStops,
    AppStrings.stepRoute,
    AppStrings.stepDrive,
  ];

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0)
              Container(
                width: 14,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: i <= step
                      ? AppColors.primary
                      : AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            StepDot(
              index: i,
              label: _labels[i],
              done: i < step,
              active: i == step,
            ),
          ],
        ],
      ),
    );
  }
}

class StepDot extends StatelessWidget {
  final int index;
  final String label;
  final bool done;
  final bool active;

  const StepDot({
    super.key,
    required this.index,
    required this.label,
    required this.done,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final dot = AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done || active ? AppColors.primary : AppColors.surfaceDim,
      ),
      alignment: Alignment.center,
      child: done
          ? const Icon(Icons.check_rounded, size: 14, color: AppColors.white)
          : Text(
              '${index + 1}',
              style: AppTextStyles.mutedSm.copyWith(
                color: active ? AppColors.white : AppColors.textMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
    );

    // Only the active step shows its label — keeps the chip compact.
    if (!active) return dot;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.titleSm.copyWith(color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

class TopIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const TopIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(48),
        minimumSize: const Size.square(48),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () {
        HapticFeedback.selectionClick();
        onPressed();
      },
      icon: Icon(icon, color: AppColors.textPrimary, size: 22),
    );
  }
}
