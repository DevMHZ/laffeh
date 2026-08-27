import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';
import '../widgets/destination_card.dart';
import '../widgets/route_plan_action_bar.dart';
import '../widgets/route_points_sheet.dart';
import '../widgets/route_summary_sheet.dart';
import 'route_planner_actions.dart';

/// The bottom half of the planner screen, in whichever shape the trip is in.
///
///   * **One destination** — a [DestinationCard]: time, distance, and a Go
///     button. No sheet, no list, no optimize step, because there is nothing
///     to order. This is the app behaving like any other navigator.
///   * **Two or more** — the draggable planner sheet: the points list before
///     optimization, the route summary after. This is the app doing the thing
///     it sells, and it appears because the driver asked for it.
///
/// Hidden while a full-screen flow is active.
class BottomSheetHost extends StatelessWidget {
  const BottomSheetHost({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) =>
          a.optimizedRoute != b.optimizedRoute ||
          a.points != b.points ||
          a.status != b.status ||
          a.simulationActive != b.simulationActive ||
          a.navigationActive != b.navigationActive ||
          a.manualPlacement != b.manualPlacement ||
          a.quietRouting != b.quietRouting ||
          a.departureAt != b.departureAt ||
          a.multiStopIntent != b.multiStopIntent ||
          a.movingPointId != b.movingPointId,
      builder: (context, state) {
        final cubit = context.read<RoutePlannerCubit>();
        // Preview, drive, move-a-point, and manual pin-placement all use the
        // full-screen map.
        if (state.simulationActive ||
            state.navigationActive ||
            state.manualPlacement ||
            state.movingPointId != null) {
          return const SizedBox.shrink();
        }
        // One place to go: the navigator card, docked rather than draggable.
        // Its height is its content — a card that can be dragged over the map
        // implies there is more underneath it, and here there isn't.
        if (state.isSingleDestination) {
          return Align(
            alignment: Alignment.bottomCenter,
            child: DestinationCard(
              destination: state.points.firstWhere((p) => !p.isDepot),
              route: state.optimizedRoute,
              routing: state.quietRouting || state.isOptimizing,
              departureAt: state.departureAt,
              // Null while the trip starts from wherever the driver is —
              // the card says so in its own words rather than naming a
              // place that will have moved by the time they set off.
              departureFrom: state.departureIsCurrentLocation
                  ? null
                  : state.departurePoint,
              onGo: cubit.driveToDestination,
              onAddAnotherStop: () =>
                  RoutePlannerActions.showAddMethodChooser(context, cubit),
              onChangeDestination: cubit.clearDestination,
              onChangeDeparture: () =>
                  RoutePlannerActions.showDeparturePicker(context, cubit),
            ),
          );
        }

        final showSummary = state.hasOptimizedRoute;

        // Empty state is owned by the screen-level AddOptionsHost, not a
        // bottom sheet — so the sheet only appears once a point exists.
        if (!showSummary && !state.hasPoints) {
          return const SizedBox.shrink();
        }

        final key = showSummary ? 'summary' : 'points';

        // Snap sizes are capped per sheet so the user can't drag past where
        // there's actually content.
        final config = showSummary
            ? const _SheetConfig(
                min: 0.28,
                initial: 0.55,
                max: 0.85,
                snaps: [0.28, 0.55, 0.85],
              )
            // Opens collapsed, but never below its own action bar: the peek
            // has to show the handle, every way of adding a place, and the
            // pinned "optimize" CTA, because a driver who never drags the
            // sheet has to be able to finish a plan anyway. Each rise in this
            // number has been the ways-in growing — first the action bar,
            // then the four methods taking the place of one button.
            : const _SheetConfig(
                min: 0.33,
                initial: 0.33,
                max: 0.80,
                snaps: [0.33, 0.58, 0.80],
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
              color: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              elevation: 10,
              shadowColor: AppColors.shadow,
              // Joins the screen's single grouped backdrop pass (the sheet
              // floats over the live map, so its blur would otherwise re-sample
              // the map on its own every frame).
              child: BackdropFilter.grouped(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.97),
                    border: Border(
                      top: BorderSide(
                        color: AppColors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                  // Scrolling content, then the planner's pinned action bar.
                  // The bar sits outside the scroll view on purpose: it is
                  // the one control that has to be on screen at every drag
                  // position, whatever the list above it is doing.
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          child: showSummary
                              ? RouteSummarySheet(
                                  onOpenGoogleMaps: () =>
                                      RoutePlannerActions.launchGoogleMaps(
                                        state.optimizedRoute!.orderedPoints,
                                      ),
                                  onExportCsv: () =>
                                      RoutePlannerActions.exportCsv(
                                        context,
                                        RoutePlannerActions.csvPointsForState(
                                          state,
                                        ),
                                      ),
                                )
                              : const RoutePointsSheet(),
                        ),
                      ),
                      // The summary sheet has its own actions at the top;
                      // only the planning sheet needs a pinned one.
                      if (!showSummary)
                        RoutePlanActionBar(
                          pointsCount: state.routableCount,
                          canOptimize: state.canOptimize,
                          isOptimizing: state.isOptimizing,
                          onOptimize: cubit.optimize,
                        ),
                    ],
                  ),
                ),
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
