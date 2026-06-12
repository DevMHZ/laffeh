import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../domain/entities/optimized_route.dart';
import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';
import 'stop_timeline.dart';

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
          a.optimizedRoute != b.optimizedRoute,
      builder: (context, state) {
        final route = state.optimizedRoute;
        if (route == null) return const SizedBox.shrink();
        final cubit = context.read<RoutePlannerCubit>();

        final progress = state.simulationProgress;
        final finished = progress >= 1.0;
        final targetIndex = _targetIndex(route, progress);
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: finished
                                    ? AppColors.primarySoft
                                    : AppColors.pinOrange.withValues(
                                        alpha: 0.14,
                                      ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                finished
                                    ? Iconsax.tick_circle
                                    : Iconsax.location,
                                color: finished
                                    ? AppColors.primary
                                    : AppColors.pinOrange,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    finished
                                        ? AppStrings.previewRoute
                                        : AppStrings.stopNofM(
                                            _stopNumber(route, targetIndex),
                                            _stopCount(route),
                                          ),
                                    style: AppTextStyles.mutedSm,
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    finished ? AppStrings.arrived : target.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.h3,
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    '${MetricFormat.distance(remainingKm)} • ${MetricFormat.duration(remainingMin)}',
                                    style: AppTextStyles.bodySm.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: AppStrings.exitSimulation,
                              style: IconButton.styleFrom(
                                fixedSize: const Size.square(46),
                              ),
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                cubit.exitSimulation();
                              },
                              icon: const Icon(
                                Iconsax.close_circle,
                                color: AppColors.textSecondary,
                                size: 26,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
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
                          child: _TripProgressBar(progress: progress),
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

  int _targetIndex(OptimizedRoute route, double progress) {
    final count = route.orderedPoints.length;
    if (count < 2) return 0;
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
}

class _TripProgressBar extends StatelessWidget {
  final double progress;
  const _TripProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 12,
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: AppColors.surfaceDim,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${(progress * 100).round()}%',
          style: AppTextStyles.mutedSm,
        ),
      ],
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  final bool playing;
  final bool finished;
  final VoidCallback onPlay;
  final VoidCallback onPause;

  const _PlayPauseButton({
    required this.playing,
    required this.finished,
    required this.onPlay,
    required this.onPause,
  });

  @override
  Widget build(BuildContext context) {
    final icon = finished
        ? Iconsax.refresh
        : playing
        ? Iconsax.pause
        : Iconsax.play;

    return Material(
      color: AppColors.primary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.lightImpact();
          playing ? onPause() : onPlay();
        },
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.white, size: 28),
        ),
      ),
    );
  }
}

class _SmallControl extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _SmallControl({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.selectionClick();
          onPressed();
        },
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(icon, color: AppColors.textPrimary, size: 22),
          ),
        ),
      ),
    );
  }
}
