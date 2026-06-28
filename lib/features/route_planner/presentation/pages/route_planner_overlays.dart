import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_loading.dart';
import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';
import '../widgets/aim_aligned_reticle.dart';
import '../widgets/center_pin_widget.dart';
import '../widgets/route_map_view.dart';
import '../widgets/route_navigation_overlay.dart';
import '../widgets/route_simulation_overlay.dart';
import 'route_planner_actions.dart';

/// Crosshair marking where an added point lands. Asphalt until the
/// departure exists, brand green afterwards. Pinned via [AimAlignedReticle]
/// to the real drop point (the camera target's on-screen projection), so it
/// stays exactly over what gets dropped even on Android, where the native
/// map and the Flutter overlay don't share the same centre.
class CenterPin extends StatelessWidget {
  final GlobalKey<RouteMapViewState> mapKey;
  const CenterPin({super.key, required this.mapKey});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) =>
          a.simulationActive != b.simulationActive ||
          a.navigationActive != b.navigationActive ||
          a.optimizedRoute != b.optimizedRoute ||
          a.status != b.status ||
          a.movingPointId != b.movingPointId ||
          a.manualPlacement != b.manualPlacement ||
          a.points.isEmpty != b.points.isEmpty,
      builder: (context, state) {
        // The move-a-point flow shows its own reticle (MovePointHost).
        // On an empty map the crosshair stays hidden until the user actually
        // chooses "add manually" (manualPlacement) — once any point exists it
        // shows again so "add stop here" has its aim.
        final visible =
            !state.simulationActive &&
            !state.navigationActive &&
            !state.hasOptimizedRoute &&
            !state.isOptimizing &&
            state.movingPointId == null &&
            (state.hasPoints || state.manualPlacement);
        if (!visible) return const SizedBox.shrink();
        final hasDepot = state.points.isNotEmpty;
        final color = hasDepot ? AppColors.primary : AppColors.asphalt;

        return AimAlignedReticle(
          mapKey: mapKey,
          child: IgnorePointer(
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: color),
              duration: const Duration(milliseconds: 400),
              builder: (_, value, __) => CenterPinWidget(color: value ?? color),
            ),
          ),
        );
      },
    );
  }
}

/// Hosts the full-screen trip overlays (preview + drive). Renders nothing
/// while planning.
class TripOverlayHost extends StatelessWidget {
  const TripOverlayHost({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) =>
          a.simulationActive != b.simulationActive ||
          a.navigationActive != b.navigationActive,
      builder: (context, state) {
        if (state.navigationActive) {
          return RouteNavigationOverlay(
            onOpenGoogleMaps: () {
              final route = context
                  .read<RoutePlannerCubit>()
                  .state
                  .optimizedRoute;
              if (route != null) {
                RoutePlannerActions.launchGoogleMaps(route.orderedPoints);
              }
            },
          );
        }
        if (state.simulationActive) return const RouteSimulationOverlay();
        return const SizedBox.shrink();
      },
    );
  }
}

/// Full-screen loading veil shown while the route is being optimized.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) => a.status != b.status,
      builder: (context, state) {
        if (!state.isOptimizing) return const SizedBox.shrink();
        return AppLoadingOverlay(message: AppStrings.bestRouteTitle);
      },
    );
  }
}
