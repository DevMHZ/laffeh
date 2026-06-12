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

class RouteNavigationSheet extends StatelessWidget {
  const RouteNavigationSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) =>
          a.navigationProgress != b.navigationProgress ||
          a.navigationSpeedMps != b.navigationSpeedMps ||
          a.userLocation != b.userLocation ||
          a.optimizedRoute != b.optimizedRoute,
      builder: (context, state) {
        final route = state.optimizedRoute;
        if (route == null) return const SizedBox.shrink();
        if (route.orderedPoints.isEmpty) return const SizedBox.shrink();

        final cubit = context.read<RoutePlannerCubit>();
        final target = _currentTarget(route, state.navigationProgress);
        final loc = state.userLocation;
        final distanceToTarget = loc == null
            ? null
            : DistanceUtils.haversineKm(loc, target.latLng);
        final remainingKm =
            (route.metrics.totalDistanceKm ?? 0) *
            (1 - state.navigationProgress);
        final speedKmh = state.navigationSpeedMps == null
            ? null
            : state.navigationSpeedMps! * 3.6;

        return AppSheetContainer(
          title: AppStrings.navigationModeTitle,
          subtitle: '${AppStrings.nextStop}: ${target.label}',
          actions: [
            IconButton(
              tooltip: AppStrings.stopNavigation,
              icon: const Icon(
                Iconsax.close_circle,
                color: AppColors.textSecondary,
              ),
              onPressed: cubit.stopNavigation,
            ),
          ],
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _ProgressBar(progress: state.navigationProgress),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _Pill(
                      icon: Iconsax.location_tick,
                      label: AppStrings.nextStop,
                      value: distanceToTarget == null
                          ? AppStrings.unavailable
                          : MetricFormat.distance(distanceToTarget),
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Pill(
                      icon: Iconsax.routing,
                      label: AppStrings.remainingDistance,
                      value: MetricFormat.distance(remainingKm),
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _Pill(
                icon: Iconsax.gps,
                label: AppStrings.liveLocation,
                value: speedKmh == null
                    ? AppStrings.navigationSubtitle
                    : '${speedKmh.round()} km/h',
                color: AppColors.info,
              ),
            ],
          ),
        );
      },
    );
  }

  RoutePoint _currentTarget(OptimizedRoute route, double progress) {
    final points = route.orderedPoints;
    if (points.length < 2) return points.first;
    final segmentCount = points.length - 1;
    final index = (progress * segmentCount).floor().clamp(0, segmentCount - 1);
    return points[index + 1];
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
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
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
              color: color.withValues(alpha: 0.12),
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
