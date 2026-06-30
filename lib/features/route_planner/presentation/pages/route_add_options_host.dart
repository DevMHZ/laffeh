import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';
import '../widgets/route_add_options_panel.dart';
import 'route_planner_actions.dart';

/// Screen-level entry point shown while the route is still empty: a single
/// "Add a stop" call-to-action docked at the bottom of the map. Tapping it
/// opens the per-point add-method chooser. It deliberately is NOT a draggable
/// bottom sheet — the sheet only takes over once the first point lands.
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
          a.movingPointId != b.movingPointId,
      builder: (context, state) {
        final hide = state.hasPoints ||
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
          child: hide ? const SizedBox.shrink() : const _OptionsCard(),
        );
      },
    );
  }
}

/// Positions the [RouteAddOptionsPanel] CTA at the bottom of the map and wires
/// it to the add-method chooser.
class _OptionsCard extends StatelessWidget {
  const _OptionsCard();

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
            child: RouteAddOptionsPanel(
              onTap: () =>
                  RoutePlannerActions.showAddMethodChooser(context, cubit),
            ),
          ),
        ),
      ),
    );
  }
}
