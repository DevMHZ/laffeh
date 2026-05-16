import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../saved_routes/domain/entities/saved_route.dart';
import '../../../saved_routes/presentation/pages/saved_routes_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';
import '../widgets/map_action_button.dart';
import '../widgets/route_map_view.dart';
import '../widgets/route_points_sheet.dart';
import '../widgets/route_simulation_sheet.dart';
import '../widgets/route_summary_sheet.dart';

/// Map-first route planner.
///
/// Layout:
///   * Full-screen [RouteMapView] underneath.
///   * Floating "Afdal" logo chip + settings on top.
///   * Floating action buttons on the trailing edge.
///   * Draggable bottom sheet that swaps between
///     [RoutePointsSheet] (before optimization),
///     [RouteSummarySheet] (after), and
///     [RouteSimulationSheet] (while playing back).
class RoutePlannerPage extends StatelessWidget {
  const RoutePlannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RoutePlannerCubit>(
      create: (_) => sl<RoutePlannerCubit>()..initialize(),
      child: const _RoutePlannerView(),
    );
  }
}

class _RoutePlannerView extends StatelessWidget {
  const _RoutePlannerView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const Positioned.fill(child: RouteMapView()),
          const _TopBar(),
          const _SideActions(),
          const _BottomSheetHost(),
          const _LoadingOverlay(),
        ],
      ),
    );
  }
}

/// Pushes the saved-routes page and, if the user picked one, loads
/// it back into the planner cubit.
Future<void> _openSavedRoutes(BuildContext context) async {
  final cubit = context.read<RoutePlannerCubit>();
  final picked = await Navigator.of(context).push<SavedRoute>(
    MaterialPageRoute(builder: (_) => const SavedRoutesPage()),
  );
  if (picked != null) {
    cubit.loadSavedRoute(picked);
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
        buildWhen: (a, b) =>
            a.missingMapsKey != b.missingMapsKey ||
            a.errorMessage != b.errorMessage ||
            a.status != b.status,
        builder: (context, state) {
          return SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      _Glass(
                        padding: const EdgeInsets.all(4),
                        child: IconButton(
                          tooltip: AppStrings.savedRoutes,
                          onPressed: () => _openSavedRoutes(context),
                          icon: const Icon(
                            Iconsax.archive_book,
                            color: AppColors.textPrimary,
                            size: 22,
                          ),
                        ),
                      ),
                      const Spacer(),
                      _Glass(
                        padding: const EdgeInsets.all(4),
                        child: IconButton(
                          tooltip: AppStrings.settings,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SettingsPage(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Iconsax.setting_2,
                            color: AppColors.textPrimary,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (state.missingMapsKey) ...[
                    const SizedBox(height: 8),
                    _Glass(
                      background: AppColors.danger.withOpacity(0.10),
                      borderColor: AppColors.danger.withOpacity(0.35),
                      child: Row(
                        children: [
                          const Icon(
                            Iconsax.danger,
                            color: AppColors.danger,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              AppStrings.errMissingApiKey,
                              style: AppTextStyles.danger13w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? background;
  final Color? borderColor;
  const _Glass({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.background,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? AppColors.border, width: 1),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SideActions extends StatelessWidget {
  const _SideActions();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 280,
      right: 14,
      child: BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
        buildWhen: (a, b) =>
            a.userLocation != b.userLocation ||
            a.points != b.points ||
            a.simulationActive != b.simulationActive,
        builder: (context, state) {
          if (state.simulationActive) return const SizedBox.shrink();
          final cubit = context.read<RoutePlannerCubit>();
          return Column(
            children: [
              MapActionButton(
                icon: Iconsax.gps,
                tooltip: AppStrings.yourLocation,
                onPressed: cubit.initialize,
              ),
              const SizedBox(height: 10),
              if (state.points.isNotEmpty)
                MapActionButton(
                  icon: Iconsax.trash,
                  tooltip: AppStrings.clearAll,
                  iconColor: AppColors.danger,
                  onPressed: cubit.clearAll,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BottomSheetHost extends StatelessWidget {
  const _BottomSheetHost();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) =>
          a.optimizedRoute != b.optimizedRoute ||
          a.points != b.points ||
          a.status != b.status ||
          a.simulationActive != b.simulationActive,
      builder: (context, state) {
        final showSimulation = state.simulationActive;
        final showSummary = state.hasOptimizedRoute && !showSimulation;

        final key = showSimulation
            ? 'sim'
            : showSummary
            ? 'summary'
            : 'points';

        // ────────────────────────────────────────────────
        // Snap sizes are intentionally tight to content.
        //   * `min`     — peek; user sees the title + 1-2 lines.
        //   * `initial` — comfortable default for the screen.
        //   * `max`     — capped per sheet so the user can't drag
        //                 past where there's actually content.
        //                 No more "empty void" under the list.
        // The opaque Material below ensures even if max > content,
        // the gap is rendered as the same surface color (no map
        // bleed-through).
        // ────────────────────────────────────────────────
        final config = showSimulation
            ? const _SheetConfig(
                min: 0.22,
                initial: 0.42,
                max: 0.55,
                snaps: [0.22, 0.42, 0.55],
              )
            : showSummary
            ? const _SheetConfig(
                min: 0.28,
                initial: 0.55,
                max: 0.85,
                snaps: [0.28, 0.55, 0.85],
              )
            : const _SheetConfig(
                min: 0.22,
                initial: 0.36,
                max: 0.62,
                snaps: [0.22, 0.36, 0.62],
              );

        return DraggableScrollableSheet(
          key: ValueKey(key),
          initialChildSize: config.initial,
          minChildSize: config.min,
          maxChildSize: config.max,
          snap: true,
          snapSizes: config.snaps,
          builder: (context, scrollController) {
            return Material(
              color: AppColors.surface,
              clipBehavior: Clip.antiAlias,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              elevation: 6,
              shadowColor: AppColors.shadow,
              child: SingleChildScrollView(
                controller: scrollController,
                physics: const ClampingScrollPhysics(),
                child: showSimulation
                    ? const RouteSimulationSheet()
                    : showSummary
                    ? const RouteSummarySheet()
                    : const RoutePointsSheet(),
              ),
            );
          },
        );
      },
    );
  }
}

class _SheetConfig {
  final double min;
  final double initial;
  final double max;
  final List<double> snaps;
  const _SheetConfig({
    required this.min,
    required this.initial,
    required this.max,
    required this.snaps,
  });
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) => a.status != b.status,
      builder: (context, state) {
        if (!state.isOptimizing) return const SizedBox.shrink();
        return const AppLoadingOverlay(message: "يقوم بحساب الأفضل");
      },
    );
  }
}
