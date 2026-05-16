import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../domain/entities/optimized_route.dart';
import '../../domain/entities/route_point.dart';
import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';

/// Bottom sheet shown while the user plays back the optimized route
/// as a simulation. Drives [RoutePlannerCubit] for play / pause /
/// reset, exposes a speed selector and a camera-mode selector.
class RouteSimulationSheet extends StatelessWidget {
  const RouteSimulationSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) =>
          a.simulationProgress != b.simulationProgress ||
          a.simulationPlaying != b.simulationPlaying ||
          a.simulationSpeed != b.simulationSpeed ||
          a.simulationCameraMode != b.simulationCameraMode ||
          a.optimizedRoute != b.optimizedRoute,
      builder: (context, state) {
        final route = state.optimizedRoute;
        if (route == null) return const SizedBox.shrink();
        final cubit = context.read<RoutePlannerCubit>();

        final progress = state.simulationProgress;
        final finished = progress >= 1.0;
        final upcoming = _currentTarget(route, progress);

        final remainingKm = (route.metrics.totalDistanceKm ?? 0) * (1 - progress);
        final remainingMin =
            (route.metrics.estimatedDurationMinutes ?? 0) * (1 - progress);

        return AppSheetContainer(
          title: AppStrings.simulationTitle,
          subtitle: finished
              ? AppStrings.arrived
              : '${AppStrings.headedTo}: ${upcoming.label}',
          actions: [
            IconButton(
              tooltip: AppStrings.exitSimulation,
              icon: const Icon(Iconsax.close_circle,
                  color: AppColors.textSecondary),
              onPressed: cubit.exitSimulation,
            ),
          ],
          contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _ProgressBar(progress: progress),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _Pill(
                      icon: Iconsax.routing,
                      label: AppStrings.remainingDistance,
                      value: MetricFormat.distance(remainingKm),
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Pill(
                      icon: Iconsax.timer_1,
                      label: AppStrings.remainingTime,
                      value: MetricFormat.duration(remainingMin),
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _Controls(
                playing: state.simulationPlaying,
                finished: finished,
                onPlay: cubit.resumeSimulation,
                onPause: cubit.pauseSimulation,
                onReset: cubit.resetSimulation,
              ),
              const SizedBox(height: 16),
              _SectionLabel(text: 'السرعة'),
              const SizedBox(height: 6),
              _SpeedSelector(
                current: state.simulationSpeed,
                onSelect: cubit.setSimulationSpeed,
              ),
              const SizedBox(height: 14),
              _SectionLabel(text: AppStrings.cameraMode),
              const SizedBox(height: 6),
              _CameraModeSelector(
                current: state.simulationCameraMode,
                onSelect: cubit.setSimulationCameraMode,
              ),
            ],
          ),
        );
      },
    );
  }

  RoutePoint _currentTarget(OptimizedRoute route, double progress) {
    final pts = route.orderedPoints;
    if (pts.length < 2) return pts.first;
    final segmentCount = pts.length - 1;
    final idx = (progress * segmentCount).floor().clamp(0, segmentCount - 1);
    return pts[idx + 1];
  }
}

// ── small building blocks ─────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text, style: AppTextStyles.titleSm),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppStrings.progress, style: AppTextStyles.titleSm),
            Text(
              '${(progress * 100).round()}%',
              style: AppTextStyles.primary14w700,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 10,
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: AppColors.surfaceDim,
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _Pill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppTextStyles.mutedSm),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.titleMd,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final bool playing;
  final bool finished;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onReset;

  const _Controls({
    required this.playing,
    required this.finished,
    required this.onPlay,
    required this.onPause,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RoundButton(
            icon: Iconsax.refresh,
            label: AppStrings.resetSimulation,
            onPressed: onReset,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _PrimaryControl(
            playing: playing,
            finished: finished,
            onPlay: onPlay,
            onPause: onPause,
          ),
        ),
      ],
    );
  }
}

class _PrimaryControl extends StatelessWidget {
  final bool playing;
  final bool finished;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  const _PrimaryControl({
    required this.playing,
    required this.finished,
    required this.onPlay,
    required this.onPause,
  });

  @override
  Widget build(BuildContext context) {
    final label = finished
        ? AppStrings.resumeSimulation
        : (playing ? AppStrings.pauseSimulation : AppStrings.resumeSimulation);
    final icon =
        finished ? Iconsax.play : (playing ? Iconsax.pause : Iconsax.play);
    final action = playing ? onPause : onPlay;

    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: action,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: AppTextStyles.button,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 54,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.textPrimary, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMd,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Generic segmented selector — used for both speed and camera mode.
class _Segmented<T> extends StatelessWidget {
  final List<({T value, String label, IconData? icon})> options;
  final T current;
  final ValueChanged<T> onSelect;
  final double height;

  const _Segmented({
    required this.options,
    required this.current,
    required this.onSelect,
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: options.map((opt) {
          final selected = opt.value == current;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(opt.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (opt.icon != null) ...[
                      Icon(
                        opt.icon,
                        size: 16,
                        color: selected
                            ? AppColors.white
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        opt.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.titleSm.copyWith(
                          color: selected
                              ? AppColors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SpeedSelector extends StatelessWidget {
  final double current;
  final ValueChanged<double> onSelect;
  const _SpeedSelector({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return _Segmented<double>(
      current: _quantize(current),
      onSelect: onSelect,
      options: const [
        (value: 0.5, label: AppStrings.simSpeedHalfX, icon: null),
        (value: 1.0, label: AppStrings.simSpeed1x, icon: null),
        (value: 2.0, label: AppStrings.simSpeed2x, icon: null),
        (value: 4.0, label: AppStrings.simSpeed4x, icon: null),
      ],
    );
  }

  /// Snap the slider value to the nearest discrete speed step so the
  /// pill highlight stays accurate even after float arithmetic drift.
  double _quantize(double v) {
    const stops = [0.5, 1.0, 2.0, 4.0];
    return stops.reduce(
      (a, b) => (v - a).abs() < (v - b).abs() ? a : b,
    );
  }
}

class _CameraModeSelector extends StatelessWidget {
  final SimulationCameraMode current;
  final ValueChanged<SimulationCameraMode> onSelect;
  const _CameraModeSelector({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return _Segmented<SimulationCameraMode>(
      current: current,
      onSelect: onSelect,
      height: 48,
      options: const [
        (
          value: SimulationCameraMode.overview,
          label: AppStrings.cameraOverview,
          icon: Iconsax.maximize_4,
        ),
        (
          value: SimulationCameraMode.follow,
          label: AppStrings.cameraFollow,
          icon: Iconsax.location,
        ),
        (
          value: SimulationCameraMode.chase,
          label: AppStrings.cameraChase,
          icon: Iconsax.video,
        ),
      ],
    );
  }
}
