import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/optimized_route.dart';
import '../cubit/route_planner_state.dart';

/// Owns one countdown per explicit optimization, outside the disposable sheet.
/// Readiness and route identity must agree before any countdown is displayed.
class AutoPreviewController extends ChangeNotifier {
  final bool Function(OptimizedRoute route) canStart;
  final VoidCallback onStart;
  int _lastRequestId;
  OptimizedRoute? _pendingRoute;
  OptimizedRoute? _readyRoute;
  Timer? _timer;
  int? _secondsRemaining;

  AutoPreviewController({
    required this.canStart,
    required this.onStart,
    int initialRequestId = 0,
  }) : _lastRequestId = initialRequestId;

  int? get secondsRemaining => _secondsRemaining;

  static bool eligible(RoutePlannerState state) =>
      state.status == RoutePlannerStatus.optimizedSuccess &&
      !state.isSingleDestination &&
      !state.simulationActive &&
      !state.navigationActive &&
      !state.quietRouting &&
      !state.manualPlacement &&
      state.movingPointId == null &&
      // These banners precede the preview card and need time to read.
      state.missedTimeWindowPoints.isEmpty &&
      state.optimizedRoute?.orderedOnStraightLines != true &&
      (state.optimizedRoute?.fullPolyline.length ?? 0) > 1;

  void update(RoutePlannerState state) {
    if (state.previewRequestId != _lastRequestId) {
      _lastRequestId = state.previewRequestId;
      cancel();
      if (eligible(state) && canStart(state.optimizedRoute!)) {
        _pendingRoute = state.optimizedRoute;
      }
    }
    if (_pendingRoute != null &&
        (!identical(_pendingRoute, state.optimizedRoute) || !eligible(state))) {
      cancel();
    }
    _tryStart();
  }

  /// Called only after the native map has applied this route and its camera.
  void mapReady(OptimizedRoute? route) {
    _readyRoute = route;
    if (route == null && _timer != null) cancel();
    _tryStart();
  }

  void _tryStart() {
    final route = _pendingRoute;
    if (route == null || _timer != null || !identical(route, _readyRoute)) {
      return;
    }
    if (!canStart(route)) {
      cancel();
      return;
    }
    _secondsRemaining = 5;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!canStart(route)) {
        cancel();
        return;
      }
      if (_secondsRemaining! > 1) {
        _secondsRemaining = _secondsRemaining! - 1;
        notifyListeners();
      } else {
        // Consume before calling the cubit: preview/exit emits more states.
        cancel();
        onStart();
      }
    });
    notifyListeners();
  }

  /// Cancels pending readiness as well as a visible countdown. Never re-arms
  /// this request when focus, preferences, the map or the sheet change.
  void cancel() {
    _timer?.cancel();
    _timer = null;
    _pendingRoute = null;
    if (_secondsRemaining == null) return;
    _secondsRemaining = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
