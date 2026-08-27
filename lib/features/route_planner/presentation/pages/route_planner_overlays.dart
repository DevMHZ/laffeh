import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/location_gate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_loading.dart';
import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';
import '../widgets/aim_aligned_reticle.dart';
import '../widgets/center_pin_widget.dart';
import '../widgets/glass_panel.dart';
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
          a.movingPointId != b.movingPointId ||
          a.manualPlacement != b.manualPlacement ||
          a.points.isEmpty != b.points.isEmpty,
      builder: (context, state) {
        // The crosshair is purely an aiming aid for the "pick on the map"
        // flow: it shows while the user is actively placing a pin
        // (manualPlacement) and disappears the moment the point is dropped.
        // An existing route is deliberately NOT a reason to hide it: a lone
        // destination gets routed the moment it lands, so "add another stop
        // → pick on the map" always runs with a route already drawn.
        // (The move-a-point flow draws its own reticle in MovePointHost.)
        final visible =
            state.manualPlacement &&
            !state.simulationActive &&
            !state.navigationActive &&
            state.movingPointId == null;
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

/// A standing "turn location on" pill, tucked under the leading top-bar
/// button on the map.
///
/// The sheet's warning banner says *why* the dot is missing, but it is
/// transient — the next successful action clears it — and it sits inside a
/// draggable sheet that may be collapsed past it. A driver who came in past
/// the splash gate ([LocationGate]) therefore had no standing way back. This
/// is that way: frosted like the rest of the map chrome, out of the way of
/// both the sheet and the add-stop CTA, and it removes itself the moment
/// access is granted — including a permission granted out in the system
/// settings, which the page re-checks on resume.
class LocationAccessChip extends StatelessWidget {
  const LocationAccessChip({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) =>
          a.locationAccess != b.locationAccess ||
          a.simulationActive != b.simulationActive ||
          a.navigationActive != b.navigationActive ||
          a.movingPointId != b.movingPointId,
      builder: (context, state) {
        final access = state.locationAccess;
        // Unknown (not checked yet) and granted both mean "nothing to offer".
        // Driving, simulating and dragging a point all own the screen.
        final show =
            access != null &&
            access != LocationAccess.granted &&
            !state.simulationActive &&
            !state.navigationActive &&
            state.movingPointId == null;

        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            // 62 clears the 44pt top-bar button plus its padding.
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 62, 14, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(scale: anim, child: child),
                  ),
                  child: show
                      ? GlassPanel(
                          padding: EdgeInsets.zero,
                          radius: 20,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: context
                                .read<RoutePlannerCubit>()
                                .resolveLocationAccess,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Iconsax.location_slash,
                                    size: 17,
                                    color: AppColors.warning,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    AppStrings.enableLocationCta,
                                    style: AppTextStyles.bodySm.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
