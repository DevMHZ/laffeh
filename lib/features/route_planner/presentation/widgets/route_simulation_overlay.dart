import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../../../core/utils/marker_factory.dart';
import '../../domain/entities/optimized_route.dart';
import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';
import 'stop_timeline.dart';

part 'route_simulation_overlay_widgets.dart';

/// Full-screen "Trip preview" experience.
///
/// Replaces the old simulation bottom sheet. The map stays the hero:
/// only a slim status card on top and one control bar at the bottom.
/// No speed selector, no camera modes — one good default (follow
/// camera, calm pace). Controls a driver actually needs:
///   * where the vehicle is headed (big, top)
///   * which stop of how many (timeline)
///   * play / pause / replay (bottom, thumb-sized)
class RouteSimulationOverlay extends StatelessWidget {
  const RouteSimulationOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) =>
          a.simulationProgress != b.simulationProgress ||
          a.simulationPlaying != b.simulationPlaying ||
          a.simulationCameraMode != b.simulationCameraMode ||
          a.optimizedRoute != b.optimizedRoute,
      builder: (context, state) {
        final route = state.optimizedRoute;
        if (route == null) return const SizedBox.shrink();
        final cubit = context.read<RoutePlannerCubit>();

        final progress = state.simulationProgress;
        final finished = progress >= 1.0;
        // True arc-length fractions keep the headline / timeline in lock-step
        // with the vehicle and the map markers.
        final fractions = state.stopFractions;
        final targetIndex = _targetIndex(fractions, route, progress);
        final target = route.orderedPoints[targetIndex];

        final remainingKm =
            (route.metrics.totalDistanceKm ?? 0) * (1 - progress);
        final remainingMin =
            (route.metrics.estimatedDurationMinutes ?? 0) * (1 - progress);

        return Positioned.fill(
          child: Column(
            children: [
              // ── Top: where are we headed ──
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: GlassPanel(
                    padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                    radius: 18,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: finished
                                    ? AppColors.primarySoft
                                    : AppColors.pinOrange.withValues(
                                        alpha: 0.14,
                                      ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                finished
                                    ? Iconsax.tick_circle
                                    : Iconsax.location,
                                color: finished
                                    ? AppColors.primary
                                    : AppColors.pinOrange,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          finished
                                              ? AppStrings.previewRoute
                                              : AppStrings.stopNofM(
                                                  _stopNumber(
                                                      route, targetIndex),
                                                  _stopCount(route),
                                                ),
                                          style: AppTextStyles.mutedSm,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (!finished) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '${MetricFormat.distance(remainingKm)} • ${MetricFormat.duration(remainingMin)}',
                                          style: AppTextStyles.mutedSm,
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    finished ? AppStrings.arrived : target.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.titleMd,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: AppStrings.exitSimulation,
                              visualDensity: VisualDensity.compact,
                              style: IconButton.styleFrom(
                                fixedSize: const Size.square(36),
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                cubit.exitSimulation();
                              },
                              icon: const Icon(
                                Iconsax.close_circle,
                                color: AppColors.textSecondary,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        StopTimeline(
                          points: route.orderedPoints,
                          currentTarget: targetIndex,
                          finished: finished,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Camera-mode switch — Overview fits every point on screen
              // (#1), Follow tracks the vehicle, Chase is the 3D view.
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: _CameraModeToggle(
                    mode: state.simulationCameraMode,
                    onChanged: cubit.setSimulationCameraMode,
                  ),
                ),
              ),

              // Middle stays transparent — the map is the show.
              const Spacer(),

              // ── Bottom: one obvious control bar ──
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: GlassPanel(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    radius: 26,
                    child: Row(
                      children: [
                        _SmallControl(
                          icon: Iconsax.refresh,
                          tooltip: AppStrings.replay,
                          onPressed: cubit.resetSimulation,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _TripScrubber(
                            progress: progress,
                            stops: _scrubberTicks(fractions, route),
                            totalMinutes:
                                (route.metrics.estimatedDurationMinutes ?? 0)
                                    .toDouble(),
                            onSeek: cubit.seekSimulation,
                          ),
                        ),
                        const SizedBox(width: 14),
                        _PlayPauseButton(
                          playing: state.simulationPlaying,
                          finished: finished,
                          onPlay: cubit.resumeSimulation,
                          onPause: cubit.pauseSimulation,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Ordered index of the stop the vehicle is currently heading to — the
  /// first whose true arc-length fraction is still ahead of [progress].
  /// Falls back to even spacing only if fractions aren't available yet.
  int _targetIndex(List<double> fractions, OptimizedRoute route, double progress) {
    final count = route.orderedPoints.length;
    if (count < 2) return 0;
    if (fractions.length == count) {
      for (var i = 1; i < count; i++) {
        if (fractions[i] > progress) return i;
      }
      return count - 1;
    }
    final segments = count - 1;
    return ((progress * segments).floor() + 1).clamp(1, count - 1);
  }

  /// Stops visited when arriving at [targetIndex] (1-based, depot
  /// entries excluded).
  int _stopNumber(OptimizedRoute route, int targetIndex) {
    var n = 0;
    for (var i = 0; i <= targetIndex; i++) {
      if (!route.orderedPoints[i].isDepot) n++;
    }
    // Heading back to the depot at the end: report the last stop.
    return n == 0 ? _stopCount(route) : n;
  }

  int _stopCount(OptimizedRoute route) =>
      route.orderedPoints.where((p) => !p.isDepot).length;

  /// Scrubber tick positions for the interior stops, using their true
  /// arc-length fractions so a tick sits exactly where the playhead is when
  /// the vehicle reaches that stop. Falls back to even spacing if needed.
  List<double> _scrubberTicks(List<double> fractions, OptimizedRoute route) {
    final count = route.orderedPoints.length;
    if (count < 3) return const [];
    if (fractions.length == count) {
      return [for (var i = 1; i < count - 1; i++) fractions[i]];
    }
    final segments = count - 1;
    return [for (var i = 1; i < count - 1; i++) i / segments];
  }
}
