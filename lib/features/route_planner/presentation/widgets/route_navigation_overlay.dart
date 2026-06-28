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
  State<RouteNavigationOverlay> createState() => _RouteNavigationOverlayState();
}

class _RouteNavigationOverlayState extends State<RouteNavigationOverlay> {
  /// Portrait-only — the app's default everywhere outside focus mode.
  static const _portraitOnly = <DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ];

  /// All orientations — focus mode lets the driver turn a mounted phone
  /// sideways for a wide map. Rotation stays the user's choice; we only
  /// permit it, never force it.
  static const _allOrientations = <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  /// When true the HUD collapses to an eyes-on-road minimum: only the slim
  /// next-stop banner and an exit control remain, so the map fills the screen.
  bool _focusMode = false;

  /// Enters/leaves focus mode and unlocks/relocks landscape with it. Leaving
  /// focus forces the device back to portrait even if held sideways.
  void _setFocusMode(bool enabled) {
    if (_focusMode == enabled) return;
    setState(() => _focusMode = enabled);
    SystemChrome.setPreferredOrientations(
      enabled ? _allOrientations : _portraitOnly,
    );
  }

  @override
  void dispose() {
    // Navigation can end while focus mode is still on (arrival auto-ends the
    // trip, or End Trip is tapped). Always restore the portrait lock so the
    // rest of the app is never left rotatable.
    if (_focusMode) {
      SystemChrome.setPreferredOrientations(_portraitOnly);
    }
    super.dispose();
  }

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
        final distanceToTarget = loc == null
            ? null
            : DistanceUtils.haversineKm(loc, target.latLng);
        final remainingKm =
            (route.metrics.totalDistanceKm ?? 0) *
            (1 - state.navigationProgress);

        // Landscape only happens inside focus mode (the app is portrait-locked
        // otherwise). A full-width banner across a wide screen would bury the
        // map, so we cap it and pin it to the leading edge — Maps/Waze style.
        final isLandscape =
            MediaQuery.orientationOf(context) == Orientation.landscape;

        // Landscape gets a wholly different shape: a super-thin vertical rail
        // hugging the leading edge, vertically centred — icons and numbers
        // only, no labels — so it takes almost no width and never sits in the
        // driver's line of sight. Landscape only ever happens in focus mode.
        if (isLandscape) {
          return Positioned.fill(
            child: SafeArea(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: _LandscapeHudRail(
                    isReturn: isReturn,
                    subtitle: isReturn
                        ? AppStrings.endTrip
                        : '${AppStrings.nextStop} · '
                              '${AppStrings.stopNofM(_stopNumber(route, targetIndex), _stopCount(route))}',
                    label: target.label,
                    address: target.address,
                    distanceToTarget: distanceToTarget,
                    remainingKm: remainingKm,
                    onExitFocus: () => _setFocusMode(false),
                  ),
                ),
              ),
            ),
          );
        }

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
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.shadow,
                              blurRadius: 18,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                          child: Row(
                            children: [
                              // Icon badge.
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isReturn ? Iconsax.repeat : Iconsax.location,
                                  color: AppColors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
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
                                      style: AppTextStyles.h3.copyWith(
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
                              const SizedBox(width: 8),
                              // Live distance to target.
                              if (distanceToTarget != null)
                                Text(
                                  MetricFormat.distance(distanceToTarget),
                                  style: AppTextStyles.h3.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              const SizedBox(width: 2),
                            ],
                          ),
                        ),
                      ),
                      if (!_focusMode) ...[
                        const SizedBox(height: 6),
                        // Timeline strip.
                        GlassPanel(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          radius: 14,
                          child: StopTimeline(
                            points: route.orderedPoints,
                            currentTarget: targetIndex,
                            finished: finished,
                            compact: true,
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
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: _focusMode
                      ? _FocusExitBar(
                          remaining: MetricFormat.distance(remainingKm),
                          onExit: () => _setFocusMode(false),
                        )
                      : GlassPanel(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                          radius: 20,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Header: remaining distance + focus toggle.
                              Row(
                                children: [
                                  const Icon(
                                    Iconsax.routing,
                                    size: 15,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    MetricFormat.distance(remainingKm),
                                    style: AppTextStyles.titleSm,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    AppStrings.remainingShort,
                                    style: AppTextStyles.mutedSm,
                                  ),
                                  const Spacer(),
                                  _FocusToggleButton(
                                    onTap: () => _setFocusMode(true),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

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
                              const SizedBox(height: 6),

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
                                      background: AppColors.danger.withValues(
                                        alpha: 0.10,
                                      ),
                                      foreground: AppColors.danger,
                                      onTap: cubit.stopNavigation,
                                    ),
                                  ),
                                ],
                              ),

                              // ── DEBUG ONLY — visible drive-test stepper,
                              // compiled out of release builds via [kDebugMode].
                              if (kDebugMode && !finished) ...[
                                const SizedBox(height: 6),
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

/// Super-thin landscape rail for focus mode.
///
/// A single narrow vertical strip on the leading edge — icons and numbers
/// stacked, no text labels — so it occupies almost no width and stays clear
/// of the driver's view. Shows: next-stop distance (the big number), remaining
/// trip distance, and an icon-only exit back to portrait.
///
/// Tapping the next-stop badge expands the rail to reveal the stop name (and
/// "Next stop · N of M" heading); tapping again collapses it. The expand state
/// is local — width animates so the map is uncovered again the moment it closes.
class _LandscapeHudRail extends StatefulWidget {
  final bool isReturn;
  final String subtitle;
  final String label;
  final String? address;
  final double? distanceToTarget;
  final double remainingKm;
  final VoidCallback onExitFocus;

  const _LandscapeHudRail({
    required this.isReturn,
    required this.subtitle,
    required this.label,
    required this.address,
    required this.distanceToTarget,
    required this.remainingKm,
    required this.onExitFocus,
  });

  @override
  State<_LandscapeHudRail> createState() => _LandscapeHudRailState();
}

class _LandscapeHudRailState extends State<_LandscapeHudRail> {
  bool _expanded = false;

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final white70 = AppColors.white.withValues(alpha: 0.70);
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _expanded ? 200 : 58),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.asphalt.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(_expanded ? 22 : 28),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: 12,
              horizontal: _expanded ? 12 : 6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Next-stop badge — tap to reveal/hide the stop name.
                GestureDetector(
                  onTap: _toggle,
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Icon(
                          widget.isReturn ? Iconsax.repeat : Iconsax.location,
                          color: AppColors.white,
                          size: 15,
                        ),
                      ),
                      // Tiny chevron hints the badge is tappable.
                      const SizedBox(height: 2),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: white70,
                      ),
                    ],
                  ),
                ),

                // Stop name + heading — only when expanded.
                if (_expanded) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.mutedSm.copyWith(color: white70),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleSm.copyWith(
                      color: AppColors.white,
                    ),
                  ),
                  // Textual address, mirroring the portrait banner.
                  if (widget.address != null && widget.address!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      widget.address!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ],

                // Live distance to the target — the big number.
                if (widget.distanceToTarget != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    MetricFormat.distance(widget.distanceToTarget!),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleMd.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.white.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 10),
                // Remaining trip distance.
                Icon(Iconsax.routing, size: 13, color: white70),
                const SizedBox(height: 4),
                Text(
                  MetricFormat.distance(widget.remainingKm),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySm.copyWith(
                    color: white70,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                // Exit focus → snaps back to portrait.
                Align(
                  child: Material(
                    color: AppColors.white.withValues(alpha: 0.10),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onExitFocus();
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(9),
                        child: Icon(
                          Icons.fullscreen_exit_rounded,
                          size: 18,
                          color: AppColors.white,
                        ),
                      ),
                    ),
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
            height: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'تقدم خطوة',
                  style: AppTextStyles.titleSm.copyWith(color: Colors.white),
                ),
                const SizedBox(width: 8),
                Text(
                  'اضغط مطوّلاً للسير',
                  style: AppTextStyles.mutedSm.copyWith(
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
                style: AppTextStyles.titleSm.copyWith(color: AppColors.primary),
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
                  style: AppTextStyles.titleSm.copyWith(color: AppColors.white),
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
                  style: AppTextStyles.titleSm.copyWith(color: AppColors.white),
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
          height: 46,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 18),
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
