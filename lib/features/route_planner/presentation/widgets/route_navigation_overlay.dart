import 'dart:async';

import 'package:flutter/foundation.dart';
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
/// Built for a phone mounted in a vehicle:
///   * Dark high-contrast banner at the top — next stop name huge and
///     readable in sunlight, with real-time distance from GPS.
///   * Horizontal stop timeline: done = green check, current = orange
///     pulsing, upcoming = white outlined. All unchecked on entry.
///   * Bottom panel: a big primary "Arrived" button (the most-used
///     action), plus Maps and End Trip as secondary actions.
///   * GPS auto-advances the current target when within 150 m; the
///     driver can also tap "Arrived" to confirm manually.
class RouteNavigationOverlay extends StatefulWidget {
  final VoidCallback? onOpenGoogleMaps;

  const RouteNavigationOverlay({super.key, this.onOpenGoogleMaps});

  @override
  State<RouteNavigationOverlay> createState() =>
      _RouteNavigationOverlayState();
}

class _RouteNavigationOverlayState extends State<RouteNavigationOverlay> {
  /// When true the HUD collapses to an eyes-on-road minimum: only the slim
  /// next-stop banner and an exit control remain, so the map fills the screen.
  bool _focusMode = false;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoutePlannerCubit, RoutePlannerState>(
      buildWhen: (a, b) =>
          a.navigationProgress != b.navigationProgress ||
          a.navigationStopIndex != b.navigationStopIndex ||
          a.userLocation != b.userLocation ||
          a.optimizedRoute != b.optimizedRoute,
      builder: (context, state) {
        final route = state.optimizedRoute;
        if (route == null || route.orderedPoints.isEmpty) {
          return const SizedBox.shrink();
        }
        final cubit = context.read<RoutePlannerCubit>();

        final count = route.orderedPoints.length;
        final targetIndex = state.navigationStopIndex.clamp(0, count - 1);
        final target = route.orderedPoints[targetIndex];
        final isReturn = _isReturn(route, targetIndex);

        // The trip is never "finished" while navigation is active — the
        // driver must tap the button at the return depot to end it.
        const finished = false;

        final loc = state.userLocation;
        final distanceToTarget =
            loc == null ? null : DistanceUtils.haversineKm(loc, target.latLng);
        final remainingKm =
            (route.metrics.totalDistanceKm ?? 0) *
            (1 - state.navigationProgress);

        return Positioned.fill(
          child: Column(
            children: [
              // ── Top: next-stop banner + timeline ──
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: Column(
                    children: [
                      // Dark banner — maximum contrast for in-car use.
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.asphalt.withValues(alpha: 0.97),
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
                              // Icon badge.
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  isReturn
                                      ? Iconsax.repeat
                                      : Iconsax.location,
                                  color: AppColors.white,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              // Stop info.
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isReturn
                                          ? AppStrings.endTrip
                                          : '${AppStrings.nextStop} · ${AppStrings.stopNofM(_stopNumber(route, targetIndex), _stopCount(route))}',
                                      style: AppTextStyles.bodySm.copyWith(
                                        color: AppColors.white.withValues(
                                          alpha: 0.70,
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
                                            alpha: 0.55,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Live distance to target.
                              if (distanceToTarget != null)
                                Text(
                                  MetricFormat.distance(distanceToTarget),
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
                      if (!_focusMode) ...[
                        const SizedBox(height: 8),
                        // Timeline strip.
                        GlassPanel(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 6,
                          ),
                          radius: 18,
                          child: StopTimeline(
                            points: route.orderedPoints,
                            currentTarget: targetIndex,
                            finished: finished,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // ── Bottom: full panel, or a slim exit bar in focus mode ──
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: _focusMode
                      ? _FocusExitBar(
                          remaining: MetricFormat.distance(remainingKm),
                          onExit: () => setState(() => _focusMode = false),
                        )
                      : GlassPanel(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                          radius: 26,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Header: remaining distance + focus toggle.
                              Row(
                                children: [
                                  const Icon(
                                    Iconsax.routing,
                                    size: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 7),
                                  Text(
                                    MetricFormat.distance(remainingKm),
                                    style: AppTextStyles.titleSm,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    AppStrings.remainingShort,
                                    style: AppTextStyles.mutedSm,
                                  ),
                                  const Spacer(),
                                  _FocusToggleButton(
                                    onTap: () =>
                                        setState(() => _focusMode = true),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Primary action: "Arrived" at every stop. At the
                              // return depot it becomes "End Trip" — the driver
                              // must physically arrive and tap to finish.
                              SizedBox(
                                width: double.infinity,
                                child: _BigAction(
                                  icon: isReturn
                                      ? Iconsax.flag
                                      : Iconsax.tick_circle,
                                  label: isReturn
                                      ? AppStrings.endTrip
                                      : AppStrings.arrivedHere,
                                  background: AppColors.primary,
                                  foreground: AppColors.white,
                                  onTap: isReturn
                                      ? cubit.stopNavigation
                                      : cubit.markCurrentStopDone,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Secondary actions.
                              Row(
                                children: [
                                  Expanded(
                                    child: _BigAction(
                                      icon: Iconsax.map_1,
                                      label: AppStrings.googleMapsShort,
                                      background: AppColors.surfaceAlt,
                                      foreground: AppColors.textPrimary,
                                      onTap: widget.onOpenGoogleMaps,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _BigAction(
                                      icon: Iconsax.close_circle,
                                      label: AppStrings.endTrip,
                                      background: AppColors.danger
                                          .withValues(alpha: 0.10),
                                      foreground: AppColors.danger,
                                      onTap: cubit.stopNavigation,
                                    ),
                                  ),
                                ],
                              ),

                              // ── DEBUG ONLY — visible drive-test stepper,
                              // compiled out of release builds via [kDebugMode].
                              if (kDebugMode && !finished) ...[
                                const SizedBox(height: 8),
                                _DebugStepButton(
                                  onStep: cubit.debugStepForward,
                                ),
                              ],
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

/// Debug step button — visible only in debug builds.
///
/// Tap once  → advance 100 m along the planned route.
/// Long-press → auto-step every 250 ms until released (hands-free drive).
///
/// When the simulated position enters the 150 m arrival radius of a stop
/// the cubit auto-advances the stop index, same as the real GPS logic.
class _DebugStepButton extends StatefulWidget {
  final VoidCallback onStep;
  const _DebugStepButton({required this.onStep});

  @override
  State<_DebugStepButton> createState() => _DebugStepButtonState();
}

class _DebugStepButtonState extends State<_DebugStepButton> {
  Timer? _repeat;

  void _startHold() {
    widget.onStep();
    _repeat = Timer.periodic(const Duration(milliseconds: 250), (_) {
      widget.onStep();
    });
  }

  void _stopHold() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _startHold(),
      onLongPressEnd: (_) => _stopHold(),
      onLongPressCancel: _stopHold,
      child: Material(
        color: const Color(0xFFB45309), // amber-700
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onStep();
          },
          child: SizedBox(
            height: 58,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'تقدم خطوة',
                  style: AppTextStyles.titleMd.copyWith(color: Colors.white),
                ),
                const SizedBox(width: 10),
                Text(
                  'اضغط مطوّلاً للسير',
                  style: AppTextStyles.bodySm.copyWith(
                    color: Colors.white.withValues(alpha: 0.60),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact pill that switches the HUD into eyes-on-road focus mode.
class _FocusToggleButton extends StatelessWidget {
  final VoidCallback onTap;
  const _FocusToggleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.center_focus_strong_rounded,
                size: 17,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                AppStrings.focusMode,
                style:
                    AppTextStyles.titleSm.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slim bottom bar shown in focus mode: remaining distance plus a one-tap
/// control to leave focus mode. Kept minimal so the map dominates the screen.
class _FocusExitBar extends StatelessWidget {
  final String remaining;
  final VoidCallback onExit;
  const _FocusExitBar({required this.remaining, required this.onExit});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: AppColors.asphalt.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: () {
            HapticFeedback.selectionClick();
            onExit();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Iconsax.routing, size: 17, color: AppColors.white),
                const SizedBox(width: 8),
                Text(
                  remaining,
                  style:
                      AppTextStyles.titleSm.copyWith(color: AppColors.white),
                ),
                Container(
                  width: 1,
                  height: 16,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: AppColors.white.withValues(alpha: 0.25),
                ),
                const Icon(
                  Icons.fullscreen_exit_rounded,
                  size: 18,
                  color: AppColors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  AppStrings.exitFocus,
                  style:
                      AppTextStyles.titleSm.copyWith(color: AppColors.white),
                ),
              ],
            ),
          ),
        ),
      ),
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
