import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';
import '../widgets/route_add_options_panel.dart';
import '../widgets/route_map_view.dart';
import 'route_planner_actions.dart';

/// Screen-level entry point shown while the route is still empty: a
/// professional floating panel docked at the bottom of the map offering the
/// three ways to add stops. It deliberately is NOT a draggable bottom sheet —
/// the sheet only takes over once the first point lands.
///
/// Hidden whenever a point exists, a route is optimized, or a full-screen
/// flow (preview / drive / move-a-point) is active.
class AddOptionsHost extends StatelessWidget {
  final GlobalKey<RouteMapViewState> mapKey;
  const AddOptionsHost({super.key, required this.mapKey});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) =>
          a.points != b.points ||
          a.optimizedRoute != b.optimizedRoute ||
          a.simulationActive != b.simulationActive ||
          a.navigationActive != b.navigationActive ||
          a.movingPointId != b.movingPointId,
      builder: (context, state) {
        final hide = state.hasPoints ||
            state.hasOptimizedRoute ||
            state.simulationActive ||
            state.navigationActive ||
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
              : _OptionsCard(mapKey: mapKey),
        );
      },
    );
  }
}

/// Positions [RouteAddOptionsPanel] at the bottom of the map. The panel owns
/// its own chrome now — a bare button while collapsed, a frosted card once
/// expanded — so the host only handles placement and wiring.
class _OptionsCard extends StatelessWidget {
  final GlobalKey<RouteMapViewState> mapKey;
  const _OptionsCard({required this.mapKey});

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
              onAddHere: () {
                final map = mapKey.currentState;
                if (map == null) return;
                cubit.addPoint(map.mapCenter);
              },
              onOpenWhatsapp: () => RoutePlannerActions.openWhatsapp(context),
              onShowWhatsappInfo: () =>
                  RoutePlannerActions.showWhatsappInfo(context),
              onShowImport: () =>
                  RoutePlannerActions.showImportChooser(context, cubit),
              onBeginManual: () => cubit.beginManualPlacement(),
              onCancelManual: () => cubit.cancelManualPlacement(),
            ),
          ),
        ),
      ),
    );
  }
}
