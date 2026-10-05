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
import '../widgets/route_connectivity_notice.dart';
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

/// Remains visible when the planning sheet is collapsed, including an empty
/// offline launch and a single-destination preview. The expanded sheet has
/// its own notice, so this stays below the sheet in the page's stacking order.
class PlannerConnectivityNotice extends StatelessWidget {
  const PlannerConnectivityNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) =>
          a.isOffline != b.isOffline ||
          a.optimizedRoute != b.optimizedRoute ||
          a.locationAccess != b.locationAccess ||
          a.userLocation != b.userLocation ||
          a.status != b.status ||
          a.simulationActive != b.simulationActive ||
          a.navigationActive != b.navigationActive ||
          a.movingPointId != b.movingPointId,
      builder: (context, state) {
        if (!state.isOffline ||
            state.simulationActive ||
            state.navigationActive ||
            state.movingPointId != null) {
          return const SizedBox.shrink();
        }
        final hasLocationChip =
            state.status != RoutePlannerStatus.initial &&
            state.status != RoutePlannerStatus.loadingLocation &&
            (state.userLocation == null ||
                state.locationAccess != LocationAccess.granted);
        final route = state.optimizedRoute;
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                hasLocationChip ? 280 : 62,
                14,
                0,
              ),
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: RouteConnectivityNotice(
                    hasSavedRoute:
                        route != null &&
                        route.hasRoadGeometry &&
                        route.fullPolyline.length > 1,
                    onRetry: context
                        .read<RoutePlannerCubit>()
                        .refreshConnectivity,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A persistent recovery message when permission or the first GPS fix is
/// missing. It remains visible even when the planning sheet is collapsed.
class LocationAccessChip extends StatelessWidget {
  const LocationAccessChip({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) =>
          a.locationAccess != b.locationAccess ||
          a.userLocation != b.userLocation ||
          a.status != b.status ||
          a.simulationActive != b.simulationActive ||
          a.navigationActive != b.navigationActive ||
          a.movingPointId != b.movingPointId,
      builder: (context, state) {
        final access = state.locationAccess;
        final show =
            state.status != RoutePlannerStatus.initial &&
            state.status != RoutePlannerStatus.loadingLocation &&
            (state.userLocation == null || access != LocationAccess.granted) &&
            !state.simulationActive &&
            !state.navigationActive &&
            state.movingPointId == null;
        final body = switch (access) {
          LocationAccess.servicesOff => AppStrings.locationRecoveryServices,
          LocationAccess.denied ||
          LocationAccess.blocked => AppStrings.locationRecoveryPermission,
          _ => AppStrings.locationRecoveryNoFix,
        };
        final needsSettings =
            access != null && access != LocationAccess.granted;

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
                alignment: AlignmentDirectional.topCenter,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(scale: anim, child: child),
                  ),
                  child: show
                      ? ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 500),
                          child: GlassPanel(
                            padding: const EdgeInsets.all(16),
                            radius: 20,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Iconsax.location_slash,
                                      size: 20,
                                      color: AppColors.warning,
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Text(
                                        AppStrings.locationRecoveryTitle,
                                        style: AppTextStyles.bodyMd.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(body, style: AppTextStyles.bodySm),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: TextButton.icon(
                                    onPressed: needsSettings
                                        ? context
                                              .read<RoutePlannerCubit>()
                                              .resolveLocationAccess
                                        : context
                                              .read<RoutePlannerCubit>()
                                              .retryLocationFix,
                                    icon: const Icon(Iconsax.refresh, size: 17),
                                    label: Text(
                                      needsSettings
                                          ? AppStrings.enableLocationCta
                                          : AppStrings.locationRecoveryRetry,
                                    ),
                                  ),
                                ),
                              ],
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
