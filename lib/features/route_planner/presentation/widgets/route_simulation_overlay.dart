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
                          child: _TripScrubber(
                            progress: progress,
                            stops: _stopFractions(route),
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

  /// Even-spaced fractions for the interior stops, matching how [_targetIndex]
  /// maps progress to "stop N of M" — so a scrubber tick lines up with each
  /// stop transition in the headline.
  List<double> _stopFractions(OptimizedRoute route) {
    final count = route.orderedPoints.length;
    if (count < 3) return const [];
    final segments = count - 1;
    return [for (var i = 1; i < count - 1; i++) i / segments];
  }
}

/// A video-player-style trip scrubber: a track with the elapsed portion filled,
/// little ticks at each stop, and a draggable playhead shaped like the preview
/// car. Drag (or tap) anywhere to scrub the trip — pauses playback so the user
/// can park on a stretch and replay it.
class _TripScrubber extends StatefulWidget {
  final double progress;
  final List<double> stops;
  final double totalMinutes;
  final ValueChanged<double> onSeek;

  const _TripScrubber({
    required this.progress,
    required this.stops,
    required this.totalMinutes,
    required this.onSeek,
  });

  @override
  State<_TripScrubber> createState() => _TripScrubberState();
}

class _TripScrubberState extends State<_TripScrubber> {
  bool _dragging = false;

  static const double _trackHeight = 34;
  static const double _carSize = 30;

  String _fmt(double minutes) {
    if (minutes <= 0) return '--:--';
    final total = (minutes * 60).round();
    return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
  }

  void _seekTo(double dx, double width) {
    if (width <= 0) return;
    widget.onSeek((dx / width).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.progress.clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(widget.totalMinutes * p), style: AppTextStyles.mutedSm),
              Text(_fmt(widget.totalMinutes), style: AppTextStyles.mutedSm),
            ],
          ),
        ),
        const SizedBox(height: 3),
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                HapticFeedback.selectionClick();
                _seekTo(d.localPosition.dx, w);
              },
              onHorizontalDragStart: (d) {
                setState(() => _dragging = true);
                _seekTo(d.localPosition.dx, w);
              },
              onHorizontalDragUpdate: (d) => _seekTo(d.localPosition.dx, w),
              onHorizontalDragEnd: (_) {
                HapticFeedback.selectionClick();
                setState(() => _dragging = false);
              },
              child: SizedBox(
                height: _trackHeight,
                width: w,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ScrubberTrackPainter(
                          progress: p,
                          stops: widget.stops,
                        ),
                      ),
                    ),
                    // The car playhead rides the track at the current position.
                    Positioned(
                      left: (p * w) - _carSize / 2,
                      top: (_trackHeight - _carSize) / 2,
                      child: AnimatedScale(
                        scale: _dragging ? 1.18 : 1,
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOut,
                        child: Transform.rotate(
                          angle: math.pi / 2, // nose points along travel (right)
                          child: const SizedBox(
                            width: _carSize,
                            height: _carSize,
                            child: CustomPaint(painter: TopViewCarPainter()),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ScrubberTrackPainter extends CustomPainter {
  final double progress;
  final List<double> stops;

  _ScrubberTrackPainter({required this.progress, required this.stops});

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    const h = 7.0;
    final r = const Radius.circular(99);

    // Unplayed track.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, cy - h / 2, size.width, h),
        r,
      ),
      Paint()..color = AppColors.surfaceDim,
    );

    // Played portion.
    final px = (progress.clamp(0.0, 1.0)) * size.width;
    if (px > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, cy - h / 2, px, h), r),
        Paint()..color = AppColors.primary,
      );
    }

    // Stop ticks.
    for (final f in stops) {
      final x = f * size.width;
      final passed = f <= progress;
      canvas.drawCircle(
        Offset(x, cy),
        3.4,
        Paint()..color = AppColors.white,
      );
      canvas.drawCircle(
        Offset(x, cy),
        2.2,
        Paint()..color = passed ? AppColors.primaryDark : AppColors.borderStrong,
      );
    }
  }

  @override
  bool shouldRepaint(_ScrubberTrackPainter old) =>
      old.progress != progress || old.stops != stops;
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
