import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/debug_log.dart';
import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';
import '../widgets/route_map_view.dart';
import '../widgets/route_points_sheet.dart';
import '../widgets/route_summary_sheet.dart';
import 'route_planner_actions.dart';

/// Draggable bottom sheet hosting the points list (before optimization) or
/// the route summary (after). Hidden while a full-screen flow is active.
class BottomSheetHost extends StatelessWidget {
  final GlobalKey<RouteMapViewState> mapKey;
  const BottomSheetHost({super.key, required this.mapKey});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) =>
          a.optimizedRoute != b.optimizedRoute ||
          a.points != b.points ||
          a.status != b.status ||
          a.simulationActive != b.simulationActive ||
          a.navigationActive != b.navigationActive ||
          a.movingPointId != b.movingPointId,
      builder: (context, state) {
        final cubit = context.read<RoutePlannerCubit>();
        // Preview, drive, and move-a-point all use the full-screen map.
        if (state.simulationActive ||
            state.navigationActive ||
            state.movingPointId != null) {
          return const SizedBox.shrink();
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
            // Opens collapsed: after the first point lands the sheet just
            // peeks (handle + add controls) so it never covers the map
            // uninvited — the user drags it up when they want the list.
            : const _SheetConfig(
                min: 0.24,
                initial: 0.24,
                max: 0.68,
                snaps: [0.24, 0.42, 0.68],
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
                            onExportCsv: () => RoutePlannerActions.exportCsv(
                              context,
                              RoutePlannerActions.csvPointsForState(state),
                            ),
                          )
                        : RoutePointsSheet(
                            onAddHere: () {
                              final mapState = mapKey.currentState;
                              if (mapState == null) {
                                DebugLog.add(
                                  'onAddHere TAP ✋ mapKey.currentState NULL '
                                  '— button is a no-op',
                                );
                                return;
                              }
                              final center = mapState.mapCenter;
                              DebugLog.add(
                                'onAddHere TAP → forwarding center '
                                '${center.latitude.toStringAsFixed(6)},'
                                '${center.longitude.toStringAsFixed(6)} to cubit',
                              );
                              cubit.addPoint(center);
                            },
                            onShowImport: () =>
                                RoutePlannerActions.showImportChooser(
                                  context,
                                  cubit,
                                ),
                            onOpenWhatsapp: () =>
                                RoutePlannerActions.openWhatsapp(context),
                          ),
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
