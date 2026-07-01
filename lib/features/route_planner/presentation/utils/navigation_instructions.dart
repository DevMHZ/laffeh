import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../domain/entities/optimized_route.dart';
import '../../domain/entities/route_maneuver.dart';
import '../cubit/route_planner_state.dart';

/// The maneuver line the drive HUD renders right now: icon, localized
/// text, live distance, and the road it leads onto (when known).
class NavInstruction {
  final IconData icon;
  final String text;
  final String? roadName;

  /// Metres from the vehicle to the maneuver (or to the target stop when
  /// no maneuver data exists). Recomputed on every progress tick so the
  /// HUD counts down continuously.
  final double distanceMeters;

  /// Fraction (0..1) of the maneuver along the full polyline; null in the
  /// no-maneuver fallback. The map uses it to highlight the turn segment.
  final double? maneuverFraction;

  const NavInstruction({
    required this.icon,
    required this.text,
    required this.distanceMeters,
    this.roadName,
    this.maneuverFraction,
  });
}

/// Pure derivation of the current turn instruction from cubit state — no
/// caching, no side effects, cheap enough to run on every GPS-tick rebuild.
class NavigationInstructions {
  NavigationInstructions._();

  /// The next maneuver ahead of the vehicle, or a "continue toward stop"
  /// fallback when the route has no maneuver data (straight-line fallback,
  /// legacy saved routes). Null when navigation isn't running.
  static NavInstruction? compute(RoutePlannerState state) {
    final route = state.optimizedRoute;
    if (!state.navigationActive || route == null) return null;
    if (route.fullPolyline.length < 2) return _fallback(state, route);

    final progress = state.navigationProgress.clamp(0.0, 1.0);
    final maneuvers = route.maneuvers;
    final fractions = state.maneuverFractions;
    if (maneuvers.isEmpty || fractions.length != maneuvers.length) {
      return _fallback(state, route);
    }

    final totalKm = DistanceUtils.pathLengthKm(route.fullPolyline);
    if (totalKm <= 0) return _fallback(state, route);

    // First maneuver still ahead of the vehicle. A small epsilon keeps an
    // instruction on screen until the turn is genuinely behind the car.
    const passedEpsilon = 0.00001;
    for (var i = 0; i < maneuvers.length; i++) {
      final f = fractions[i];
      if (f <= progress + passedEpsilon) continue;
      final m = maneuvers[i];
      return NavInstruction(
        icon: iconFor(m.kind),
        text: textFor(m),
        roadName: m.roadName,
        distanceMeters: ((f - progress) * totalKm * 1000).clamp(
          0.0,
          double.infinity,
        ),
        maneuverFraction: f,
      );
    }
    return _fallback(state, route);
  }

  /// No maneuver data (or all maneuvers passed): guide by the target stop.
  static NavInstruction _fallback(
    RoutePlannerState state,
    OptimizedRoute route,
  ) {
    final count = route.orderedPoints.length;
    final idx = state.navigationStopIndex.clamp(0, count - 1);
    final target = route.orderedPoints[idx];
    final isFinal = idx == count - 1;

    double meters;
    final gps = state.navigationStopDistanceMeters;
    if (gps != null) {
      meters = gps;
    } else if (route.fullPolyline.length >= 2 &&
        idx < state.stopFractions.length) {
      final totalKm = DistanceUtils.pathLengthKm(route.fullPolyline);
      meters =
          ((state.stopFractions[idx] - state.navigationProgress) *
                  totalKm *
                  1000)
              .clamp(0.0, double.infinity);
    } else {
      meters = 0;
    }

    return NavInstruction(
      icon: isFinal ? Icons.sports_score_rounded : Icons.straight_rounded,
      text: AppStrings.continueToward(target.label),
      distanceMeters: meters,
    );
  }

  static IconData iconFor(ManeuverKind kind) => switch (kind) {
    ManeuverKind.depart => Icons.navigation_rounded,
    ManeuverKind.arrive => Icons.sports_score_rounded,
    ManeuverKind.turnLeft => Icons.turn_left_rounded,
    ManeuverKind.turnRight => Icons.turn_right_rounded,
    ManeuverKind.slightLeft => Icons.turn_slight_left_rounded,
    ManeuverKind.slightRight => Icons.turn_slight_right_rounded,
    ManeuverKind.sharpLeft => Icons.turn_sharp_left_rounded,
    ManeuverKind.sharpRight => Icons.turn_sharp_right_rounded,
    ManeuverKind.uTurn => Icons.u_turn_left_rounded,
    ManeuverKind.straight => Icons.straight_rounded,
    ManeuverKind.merge => Icons.merge_rounded,
    ManeuverKind.keepLeft => Icons.fork_left_rounded,
    ManeuverKind.keepRight => Icons.fork_right_rounded,
    ManeuverKind.onRamp => Icons.ramp_right_rounded,
    ManeuverKind.offRamp => Icons.exit_to_app_rounded,
    // Right-hand traffic (KSA) circulates counterclockwise.
    ManeuverKind.roundabout => Icons.roundabout_left_rounded,
  };

  static String textFor(RouteManeuver m) => switch (m.kind) {
    ManeuverKind.depart => AppStrings.manStraight,
    ManeuverKind.arrive => AppStrings.manArrive,
    ManeuverKind.turnLeft => AppStrings.manTurnLeft,
    ManeuverKind.turnRight => AppStrings.manTurnRight,
    ManeuverKind.slightLeft => AppStrings.manSlightLeft,
    ManeuverKind.slightRight => AppStrings.manSlightRight,
    ManeuverKind.sharpLeft => AppStrings.manSharpLeft,
    ManeuverKind.sharpRight => AppStrings.manSharpRight,
    ManeuverKind.uTurn => AppStrings.manUTurn,
    ManeuverKind.straight => AppStrings.manStraight,
    ManeuverKind.merge => AppStrings.manMerge,
    ManeuverKind.keepLeft => AppStrings.manKeepLeft,
    ManeuverKind.keepRight => AppStrings.manKeepRight,
    ManeuverKind.onRamp => AppStrings.manOnRamp,
    ManeuverKind.offRamp => AppStrings.manOffRamp,
    ManeuverKind.roundabout => m.roundaboutExit != null
        ? AppStrings.manRoundaboutExit(m.roundaboutExit!)
        : AppStrings.manRoundabout,
  };
}
