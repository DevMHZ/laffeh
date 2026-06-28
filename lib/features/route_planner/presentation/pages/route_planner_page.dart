import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/utils/share_intent_handler.dart';
import '../cubit/route_planner_cubit.dart';
import '../widgets/route_map_view.dart';
import 'route_add_options_host.dart';
import 'route_planner_actions.dart';
import 'route_planner_bottom_sheet.dart';
import 'route_planner_move_overlay.dart';
import 'route_planner_overlays.dart';
import 'route_planner_top_bar.dart';

/// Map-first route planner.
///
/// Layout:
///   * Full-screen [RouteMapView] underneath.
///   * Top bar: saved routes / settings + a Stops→Route→Drive step
///     indicator so the user always knows where they are in the trip.
///   * A centre crosshair marks where a point lands; the "Add stop
///     here" + current-location controls are docked in the sheet's
///     header (not floating) so the map stays as clear as possible.
///   * Draggable bottom sheet for [RoutePointsSheet] (before
///     optimization) and [RouteSummarySheet] (after).
///   * Full-screen overlays for trip preview
///     ([RouteSimulationOverlay]) and drive mode
///     ([RouteNavigationOverlay]) — the map stays the hero.
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

class _RoutePlannerView extends StatefulWidget {
  const _RoutePlannerView();

  @override
  State<_RoutePlannerView> createState() => _RoutePlannerViewState();
}

class _RoutePlannerViewState extends State<_RoutePlannerView>
    with WidgetsBindingObserver {
  final GlobalKey<RouteMapViewState> _mapKey = GlobalKey<RouteMapViewState>();
  StreamSubscription<String>? _shareSub;

  /// Timestamp of the last Android back press — used so the app only exits on
  /// a second back within the window, never on a single accidental tap.
  DateTime? _lastBackPress;

  void _handleBackPressed() {
    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(AppStrings.pressBackAgainToExit),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    SystemNavigator.pop();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shareSub = ShareIntentHandler.stream.listen(_onSharedText);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shareSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back to the app re-checks connectivity so the offline
    // banner clears (or appears) without the user doing anything (#11).
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<RoutePlannerCubit>().refreshConnectivity();
    }
  }

  Future<void> _onSharedText(String text) async {
    if (!mounted) return;
    final cubit = context.read<RoutePlannerCubit>();
    EasyLoading.show(status: AppStrings.searchingAddresses);
    final count = await cubit.addPointsFromText(text);
    EasyLoading.dismiss();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(RoutePlannerActions.addedMessage(count))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Exit only on a deliberate double-back (handled in _handleBackPressed),
      // never on a single press.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBackPressed();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
      // Coalesces all the frosted map chrome (top bar, floating action
      // buttons, compass) into a single backdrop sampling/blur pass instead
      // of one per widget — a large GPU saving while the map pans, zooms and
      // rotates. Each panel opts in via `BackdropFilter.grouped`.
      body: BackdropGroup(
        child: Stack(
          children: [
            // Keeps the Stack full-screen even when every other child
            // collapses to SizedBox.shrink during preview/drive.
            const SizedBox.expand(),
            Positioned.fill(child: RouteMapView(key: _mapKey)),
            const TopBar(),
            CenterPin(mapKey: _mapKey),
            BottomSheetHost(mapKey: _mapKey),
            AddOptionsHost(mapKey: _mapKey),
            MovePointHost(mapKey: _mapKey),
            const TripOverlayHost(),
            const LoadingOverlay(),
          ],
        ),
        ),
      ),
    );
  }
}
