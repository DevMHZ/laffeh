import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/map_pack_controller.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/trip_map_pack_tile.dart';
import '../../../saved_routes/presentation/pages/saved_routes_page.dart';
import '../../domain/entities/optimized_route.dart';
import '../../domain/entities/route_finish.dart';
import '../../domain/entities/route_point.dart';
import '../../domain/entities/stop_time_window.dart';
import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';
import 'missed_time_window_sheet.dart';
import 'route_finish_sheet.dart';
import 'stop_time_window_sheet.dart';

part 'route_summary_sheet_widgets.dart';

class RouteSummarySheet extends StatelessWidget {
  final VoidCallback? onOpenGoogleMaps;
  final VoidCallback? onExportCsv;

  const RouteSummarySheet({super.key, this.onOpenGoogleMaps, this.onExportCsv});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) =>
          a.optimizedRoute != b.optimizedRoute ||
          a.departureAt != b.departureAt ||
          a.points != b.points,
      builder: (context, state) {
        final route = state.optimizedRoute;
        if (route == null) return const SizedBox.shrink();
        final cubit = context.read<RoutePlannerCubit>();

        final order = route.orderedPoints;

        // Per-stop ETAs are stored as minutes after departure; turning them
        // back into a wall clock needs the departure the route was solved
        // for (null = the trip starts now).
        final departureMinute = StopTimeWindow.minuteOfDay(
          state.departureAt ?? DateTime.now(),
        );

        // Stops whose requested time this route can't hit. Surfaced at the
        // very top: this is the moment the user learns the plan doesn't
        // work, and the banner is the way into the fixes.
        final missedWindows = state.missedTimeWindowPoints;

        return AppSheetContainer(
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          // "Start driving" is pinned below this content by the sheet host
          // (see [RouteDriveActionBar]) and carries the device inset with it.
          applyBottomInset: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (missedWindows.isNotEmpty) ...[
                MissedWindowBanner(
                  points: missedWindows,
                  onTap: () => showMissedTimeWindowSheet(context),
                ),
                const SizedBox(height: 12),
              ],

              // ── The whole trip in one line ─────────────────────────
              //    Time, distance and how many stops used to be a card with
              //    two labelled tiles and a lot of air in it, plus a third
              //    count in a chip further down. They are three numbers.
              _TripStrip(route: route, stops: order.length),
              const SizedBox(height: 10),

              // ── The two things that are not driving ────────────────
              //    Half width, quiet, and below the numbers: rehearsing the
              //    trip and handing it to another app are both real wants,
              //    and neither is what this screen is for.
              Row(
                children: [
                  Expanded(
                    child: _SecondaryAction(
                      icon: Iconsax.play_circle,
                      label: AppStrings.previewRoute,
                      onTap: cubit.startSimulation,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SecondaryAction(
                      icon: Iconsax.map_1,
                      label: AppStrings.openWithMaps,
                      onTap: onOpenGoogleMaps,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── Route sequence ──────────────────────────────────────
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  AppStrings.routeOrder,
                  style: AppTextStyles.titleMd,
                ),
              ),
              const SizedBox(height: 8),
              // One full-width row per stop (not a 3-up grid) so the optimised
              // order reads cleanly top-to-bottom.
              Column(
                children: [
                  for (var i = 0; i < order.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _orderCell(context, order[i], i + 1, order.length,
                        departureMinute),
                  ],
                  // An open route has no closing row, so the way to change
                  // how the day ends would vanish with the row that offered
                  // it. Keep the affordance, stated as what actually happens.
                  if (state.finish.effectiveMode == RouteEndMode.open &&
                      order.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _OpenFinishRow(
                      lastStopLabel: order.last.label,
                      onTap: () => _pickFinish(context),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // ── Save / export — kept low, just above the destructive
              //    action so the primary trip actions lead the sheet. ───
              Row(
                children: [
                  // Fresh plan for the same stops, departure re-anchored to
                  // the user's current position — for stale saved routes or
                  // a first result that looks wrong.
                  Expanded(
                    child: _ActionTile(
                      icon: Iconsax.refresh,
                      label: AppStrings.reoptimize,
                      onTap: cubit.optimize,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionTile(
                      icon: Iconsax.save_2,
                      label: AppStrings.save,
                      onTap: () => _saveRoute(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionTile(
                      icon: Iconsax.document_upload,
                      label: 'CSV',
                      onTap: onExportCsv,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Offline map — last, and as a plain row rather than a
              //    card. It is worth doing before losing signal, but it is
              //    housekeeping: putting it mid-sheet cut the stop list off
              //    from the actions that follow it. The offline button on
              //    the map carries the same row, for anyone who wants it
              //    after the fact. ────────────────────────────────────────
              Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              TripMapPackTile(polyline: route.fullPolyline),
              const SizedBox(height: 16),

              // ── Destructive escape hatch ────────────────────────────
              _StartFreshButton(onPressed: () => _handleStartNew(context)),
            ],
          ),
        );
      },
    );
  }

  /// One full-width row for a single stop in the optimised sequence — order
  /// number badge, label, and (when known) address. Laid out one per line for
  /// clear order reading.
  Widget _orderCell(BuildContext context, RoutePoint p, int index, int total,
      int departureMinute) {
    final i = index - 1;
    final isReturn = i == total - 1 && p.isDepot && i != 0;
    final color = p.isDeactivated
        ? AppColors.optionalOff
        : p.isDepot && !isReturn
        ? AppColors.primary
        : isReturn
        ? AppColors.accent
        : p.optional
        ? AppColors.optional
        : AppColors.info;
    // House for both ends of a round trip — the return leg is the departure,
    // and drawing it as anything else invites the driver to look for a place
    // that isn't there. The flag is reserved for a finish they chose.
    final isChosenFinish = p.id.endsWith(kFinishPointIdSuffix);
    final icon = p.isDepot
        ? (isChosenFinish ? Iconsax.flag : Iconsax.home_2)
        : p.optional
        ? Iconsax.star_1
        : Iconsax.location;
    return _SummaryGridCell(
      key: ValueKey(p.id),
      point: p,
      index: index,
      color: color,
      icon: icon,
      departureMinute: departureMinute,
      // Only the closing row is a choice: it is where the day ends, and the
      // Re-optimize button sits directly beneath it.
      onTap: isReturn ? () => _pickFinish(context) : null,
    );
  }

  /// Ask where the day should end, and replan if the answer changed.
  Future<void> _pickFinish(BuildContext context) async {
    final cubit = context.read<RoutePlannerCubit>();
    final chosen = await showRouteFinishSheet(
      context,
      cubit,
      current: cubit.state.finish,
    );
    if (chosen != null) await cubit.setRouteFinish(chosen);
  }

  Future<void> _handleStartNew(BuildContext context) async {
    final cubit = context.read<RoutePlannerCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final choice = await showSaveBeforeClearDialog(context);
    if (choice == null) return;
    if (!context.mounted) return;

    if (choice == SaveBeforeClearChoice.save) {
      final defaultName =
          '${AppStrings.defaultRouteName} • ${_shortDate(DateTime.now())}';
      final name = await showSaveRouteDialog(context, initialName: defaultName);
      if (name == null) return;
      if (!context.mounted) return;

      try {
        final saved = await cubit.saveCurrentRouteToHistory(name);
        if (saved == null) {
          messenger.showSnackBar(
            SnackBar(content: Text(AppStrings.errSaveRoute)),
          );
          return;
        }
        messenger.showSnackBar(
          SnackBar(content: Text(AppStrings.routeSavedMsg)),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text(AppStrings.routeSaveFailed(e))),
        );
        return;
      }
    }

    // The downloaded corridor belongs to the plan being discarded — left
    // behind it would sit on the device forever with nothing pointing at it.
    // The area map around the driver is a separate pack and stays put.
    await MapPackController.route.delete();
    MapPackController.route.reset();

    cubit.clearAll();
  }

  Future<void> _saveRoute(BuildContext context) async {
    final cubit = context.read<RoutePlannerCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final defaultName =
        '${AppStrings.defaultRouteName} • ${_shortDate(DateTime.now())}';

    final name = await showSaveRouteDialog(context, initialName: defaultName);
    if (name == null) return;
    if (!context.mounted) return;

    try {
      final saved = await cubit.saveCurrentRouteToHistory(name);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            saved == null ? AppStrings.errSaveRoute : AppStrings.routeSavedMsg,
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppStrings.routeSaveFailed(e))),
      );
    }
  }

  String _shortDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}/${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}
