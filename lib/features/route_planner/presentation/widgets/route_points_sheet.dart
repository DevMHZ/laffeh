import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../domain/entities/route_point.dart';
import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';
import '../pages/route_planner_actions.dart';
import 'add_place_bar.dart';
import 'missed_time_window_sheet.dart';
import 'route_address_search_sheet.dart';
import 'point_actions_sheet.dart';
import 'stop_time_window_sheet.dart';

part 'route_points_sheet_widgets.dart';

class RoutePointsSheet extends StatelessWidget {
  /// Whether the sheet offers the ways to add another place. False only
  /// where the sheet is being shown for its own sake — a preview.
  final bool canAddPoints;

  const RoutePointsSheet({super.key, this.canAddPoints = true});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) =>
          a.points != b.points ||
          a.status != b.status ||
          a.errorMessage != b.errorMessage ||
          a.isOffline != b.isOffline ||
          a.draftRestored != b.draftRestored ||
          a.departureAt != b.departureAt,
      builder: (context, state) {
        final cubit = context.read<RoutePlannerCubit>();

        // Location-blocked warnings get a one-tap "Enable location"
        // action; other warnings (e.g. min-two-points) don't.
        final isLocationIssue =
            state.errorMessage == AppStrings.errLocationServiceDisabled ||
            state.errorMessage == AppStrings.errLocationPermissionDenied;

        // The grid is the destinations, and only those: the departure —
        // automatic or chosen — has its own row above it, so listing it here
        // as well would number the trip's start "1" and the first stop "2".
        final destinations = state.points.where((p) => !p.isDepot).toList();

        // Stops the last optimization couldn't reach inside their window.
        final missedWindows = state.missedTimeWindowPoints;

        // No title / count header: the add controls below make the
        // sheet's purpose obvious and the empty state has its own hint,
        // so dropping the title row (and the big empty gutter beside it)
        // hands that vertical space back to the map. Only the drag handle
        // stays.
        return AppSheetContainer(
          contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          // The pinned action bar below this content carries the device
          // inset — see [RoutePlanActionBar].
          applyBottomInset: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Add another stop ─────────────────────────────────────
              //    The same four ways the empty map offers, in the same
              //    order and the same shapes. This used to be a single "add
              //    a stop" button that opened a chooser: one extra tap, every
              //    stop, for a driver who already knew which way they wanted.
              if (canAddPoints) ...[
                AddPlaceBar(
                  title: AppStrings.addPointCta,
                  floating: false,
                  onSearch: () => showAddressSearchSheet(context, cubit),
                  onPickOnMap: cubit.beginManualPlacement,
                  onGoogleMaps: () =>
                      RoutePlannerActions.showGoogleMapsInfo(context, cubit),
                  onWhatsapp: () =>
                      RoutePlannerActions.showWhatsappInfo(context),
                ),
                const SizedBox(height: 14),
              ],

              // Offline first — it explains why a sync/optimize may wait.
              //
              // Nothing offers to download a map here any more. The app
              // keeps a square around the driver on its own (see
              // `AutoMapCache`), so the banner that used to ask about it was
              // spending a row of the planning sheet on a question already
              // answered. Picking a *bigger* map is still a real choice, and
              // it lives in Settings.
              if (state.isOffline) ...[
                const _OfflineBanner(),
                const SizedBox(height: 10),
              ] else if (state.draftRestored && state.hasPoints) ...[
                const _DraftRestoredHint(),
                const SizedBox(height: 10),
              ],

              if (state.errorMessage != null &&
                  state.status != RoutePlannerStatus.optimizedFailure) ...[
                _MessageBanner(
                  icon: Iconsax.info_circle,
                  color: AppColors.warning,
                  message: state.errorMessage!,
                  actionLabel: isLocationIssue
                      ? AppStrings.enableLocationCta
                      : null,
                  actionIcon: Iconsax.location,
                  onAction: isLocationIssue
                      ? cubit.resolveLocationAccess
                      : null,
                ),
                const SizedBox(height: 10),
              ],

              // Where the round starts. Above the destinations because that
              // is what it is — the trip's first place — and because a driver
              // planning a round from a desk has to be able to see, before
              // they optimize, that Laffeh is still assuming they set off
              // from wherever they are standing.
              _StartFromRow(
                from: state.departureIsCurrentLocation
                    ? null
                    : state.departurePoint,
                onTap: () =>
                    RoutePlannerActions.showDeparturePicker(context, cubit),
              ),
              const SizedBox(height: 10),

              // Compact grid — points laid out a couple per row to keep the
              // sheet small. Tapping a cell opens its full address + actions
              // (rename / move / optional / delete) through the shared
              // showPointActions sheet. Ordering is owned by the optimizer
              // (#6), so cells aren't reorderable. (The empty state lives in
              // the screen-level AddOptionsHost, so the sheet always has at
              // least one point here.)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: destinations.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisExtent: 54,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, i) {
                  final p = destinations[i];
                  return _PointGridCell(
                    key: ValueKey(p.id),
                    point: p,
                    index: i + 1,
                    onTap: () => showPointActions(context, p),
                  );
                },
              ),
              const SizedBox(height: 6),

              // Departure clock — only meaningful once a stop has an
              // arrival window to measure against.
              if (state.hasTimeWindows) ...[
                const SizedBox(height: 4),
                _DepartureRow(
                  departureAt: state.departureAt,
                  onChanged: cubit.setDepartureAt,
                ),
                const SizedBox(height: 6),
              ],

              if (missedWindows.isNotEmpty) ...[
                const SizedBox(height: 6),
                MissedWindowBanner(
                  points: missedWindows,
                  onTap: () => showMissedTimeWindowSheet(context),
                ),
              ],

              if (state.errorMessage != null &&
                  state.status == RoutePlannerStatus.optimizedFailure) ...[
                const SizedBox(height: 10),
                _MessageBanner(
                  icon: Iconsax.info_circle,
                  color: AppColors.danger,
                  message: state.errorMessage!,
                ),
              ],
              // Optimizing lives in the sheet's pinned action bar, not here:
              // at the end of a scrolling list inside a collapsed sheet it
              // was the one thing drivers could not find.

              // Destructive escape hatch — only once there's something to
              // clear, and kept in the scroll where a mis-tap is unlikely.
              if (state.hasPoints) ...[
                const SizedBox(height: 14),
                _ClearAllButton(onPressed: () => confirmClearAll(context)),
              ],
            ],
          ),
        );
      },
    );
  }
}
