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

/// Full-screen drive-mode HUD.
///
/// Replaces the old navigation bottom sheet. Built for a phone
/// mounted in a vehicle:
///   * The next stop is the loudest thing on screen — dark asphalt
///     banner, white text readable in sunlight, distance huge.
///   * The stop timeline shows trip progress without reading.
///   * Two thumb-sized actions only: hand off to Google Maps for
///     turn-by-turn, or end the trip.
class RouteNavigationOverlay extends StatelessWidget {
  /// Opens the remaining route in Google Maps for turn-by-turn.
  final VoidCallback? onOpenGoogleMaps;

  const RouteNavigationOverlay({super.key, this.onOpenGoogleMaps});

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
        if (route == null || route.orderedPoints.isEmpty) {
          return const SizedBox.shrink();
        }
        final cubit = context.read<RoutePlannerCubit>();

        final targetIndex = _targetIndex(route, state.navigationProgress);
        final target = route.orderedPoints[targetIndex];
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

        return Positioned.fill(
          child: Column(
            children: [
              // ── Next-stop banner: the loudest thing on screen ──
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: Column(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.asphalt.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.shadow,
                              blurRadius: 28,
                              offset: Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  _isReturn(route, targetIndex)
                                      ? Iconsax.repeat
                                      : Iconsax.location,
                                  color: AppColors.white,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${AppStrings.nextStop} · ${AppStrings.stopNofM(_stopNumber(route, targetIndex), _stopCount(route))}',
                                      style: AppTextStyles.bodySm.copyWith(
                                        color: AppColors.white.withValues(
                                          alpha: 0.72,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      target.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.h2.copyWith(
                                        color: AppColors.white,
                                      ),
                                    ),
                                    if (target.address != null &&
                                        target.address!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        target.address!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.bodySm.copyWith(
                                          color: AppColors.white.withValues(
                                            alpha: 0.62,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                distanceToTarget == null
                                    ? '—'
                                    : MetricFormat.distance(distanceToTarget),
                                style: AppTextStyles.h2.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GlassPanel(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        radius: 18,
                        child: StopTimeline(
                          points: route.orderedPoints,
                          currentTarget: targetIndex,
                          finished: state.navigationProgress >= 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // ── Bottom: stats + two big actions ──
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: GlassPanel(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    radius: 26,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _StatBlock(
                                label: AppStrings.remainingDistance,
                                value: MetricFormat.distance(remainingKm),
                              ),
                            ),
                            Container(
                              width: 0.8,
                              height: 34,
                              color: AppColors.border,
                            ),
                            Expanded(
                              child: _StatBlock(
                                label: AppStrings.liveLocation,
                                value: speedKmh == null
                                    ? '—'
                                    : '${speedKmh.round()} ${AppUnits.km}/${AppUnits.hour}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _BigAction(
                                icon: Iconsax.map_1,
                                label: AppStrings.googleMapsShort,
                                background: AppColors.surfaceAlt,
                                foreground: AppColors.textPrimary,
                                onTap: onOpenGoogleMaps,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _BigAction(
                                icon: Iconsax.close_circle,
                                label: AppStrings.endTrip,
                                background: AppColors.danger,
                                foreground: AppColors.white,
                                onTap: cubit.stopNavigation,
                              ),
                            ),
                          ],
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

  bool _isReturn(OptimizedRoute route, int index) {
    final p = route.orderedPoints[index];
    return p.isDepot && index == route.orderedPoints.length - 1;
  }

  int _stopNumber(OptimizedRoute route, int targetIndex) {
    var n = 0;
    for (var i = 0; i <= targetIndex; i++) {
      if (!route.orderedPoints[i].isDepot) n++;
    }
    return n == 0 ? _stopCount(route) : n;
  }

  int _stopCount(OptimizedRoute route) =>
      route.orderedPoints.where((p) => !p.isDepot).length;
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  const _StatBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: AppTextStyles.h3),
        const SizedBox(height: 1),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.mutedSm,
        ),
      ],
    );
  }
}

class _BigAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  const _BigAction({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.mediumImpact();
                onTap!();
              },
        child: SizedBox(
          height: 58,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 22),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMd.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
