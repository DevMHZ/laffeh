import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';
import '../widgets/route_address_search_sheet.dart';
import '../widgets/where_to_bar.dart';
import 'route_planner_actions.dart';

/// Screen-level entry point shown while the route is still empty: the
/// [WhereToBar] docked at the bottom of the map — a navigator's search box,
/// with the other three ways to name a place beneath it.
///
/// Nobody opens a map wanting to build a plan; they want to get somewhere.
/// So the empty screen asks where to, and the planner vocabulary stays out of
/// sight until a second destination makes it worth having. It deliberately is
/// NOT a draggable bottom sheet — a sheet only takes over once the driver has
/// more than one place to go.
///
/// Hidden whenever a point exists, a route is optimized, the user is placing a
/// pin manually, or a full-screen flow (preview / drive / move-a-point) is
/// active.
class AddOptionsHost extends StatelessWidget {
  const AddOptionsHost({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) =>
          a.points != b.points ||
          a.optimizedRoute != b.optimizedRoute ||
          a.simulationActive != b.simulationActive ||
          a.navigationActive != b.navigationActive ||
          a.manualPlacement != b.manualPlacement ||
          a.multiStopIntent != b.multiStopIntent ||
          a.movingPointId != b.movingPointId,
      builder: (context, state) {
        final hide =
            state.hasPoints ||
            state.hasOptimizedRoute ||
            state.simulationActive ||
            state.navigationActive ||
            state.manualPlacement ||
            state.movingPointId != null;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: hide
              ? const SizedBox.shrink()
              : _OptionsCard(multiStop: state.multiStopIntent),
        );
      },
    );
  }
}

/// Docks the [WhereToBar] at the bottom of the map and wires each way in.
class _OptionsCard extends StatelessWidget {
  /// Whether the driver has already said this trip has several stops.
  final bool multiStop;

  const _OptionsCard({required this.multiStop});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RoutePlannerCubit>();

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: WhereToBar(
              onSearch: () => showAddressSearchSheet(context, cubit),
              onPickOnMap: cubit.beginManualPlacement,
              // Both of these open a demo of how the import works, with the
              // way out to the other app on it — the driver who has never
              // done it before is the one tapping.
              onGoogleMaps: () =>
                  RoutePlannerActions.showGoogleMapsInfo(context, cubit),
              onWhatsapp: () => RoutePlannerActions.showWhatsappInfo(context),
              multiStop: multiStop,
              onPlanMultiStop: cubit.beginMultiStopTrip,
              onExitMultiStop: cubit.endMultiStopTrip,
            ),
          ),
        ),
      ),
    );
  }
}
