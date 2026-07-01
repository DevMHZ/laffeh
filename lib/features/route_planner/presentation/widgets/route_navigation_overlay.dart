import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/distance_utils.dart';
import '../../domain/entities/optimized_route.dart';
import '../cubit/route_planner_cubit.dart';
import '../cubit/route_planner_state.dart';
import '../utils/navigation_instructions.dart';
import 'stop_timeline.dart';

/// Full-screen drive-mode HUD.
///
/// Built for a phone mounted in a vehicle:
///   * Top instruction banner — the upcoming maneuver (icon + localized
///     text + road name) with a continuously counting-down distance,
///     Google-Maps style. Falls back to "continue toward stop" when the
///     route carries no maneuver data.
///   * Slim next-stop bar + horizontal stop timeline underneath.
///   * Bottom info panel: remaining distance, time and arrival clock,
///     live speed, focus toggle, Maps / End-trip actions.
///   * "Point Served" — a large button that appears only while the driver
///     is inside the service radius of the current stop; serving advances
///     to the next stop instantly. Leaving the radius without tapping
///     auto-serves (see the cubit's service state machine) and flashes a
///     brief notice here.
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
  /// instruction banner and an exit control remain, so the map fills the
  /// screen.
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
          a.navigationArrived != b.navigationArrived ||
          a.navigationStopDistanceMeters != b.navigationStopDistanceMeters ||
          a.navigationSpeedMps != b.navigationSpeedMps ||
          a.maneuverFractions != b.maneuverFractions ||
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
        // driver must serve the final point to end it.
        const finished = false;

        // Live distance to the current service point: the GPS-derived
        // figure the service machine uses, falling back to a straight-line
        // estimate before the first tick.
        final loc = state.userLocation;
        final distanceToTarget = state.navigationStopDistanceMeters != null
            ? state.navigationStopDistanceMeters! / 1000
            : (loc == null
                  ? null
                  : DistanceUtils.haversineKm(loc, target.latLng));
        final remainingKm =
            (route.metrics.totalDistanceKm ?? 0) *
            (1 - state.navigationProgress);
        final remainingMinutes = route.metrics.estimatedDurationMinutes != null
            ? route.metrics.estimatedDurationMinutes! *
                  (1 - state.navigationProgress)
            : null;

        final instruction = NavigationInstructions.compute(state);

        final subtitle = isReturn
            ? AppStrings.endTrip
            : '${AppStrings.nextStop} · '
                  '${AppStrings.stopNofM(_stopNumber(route, targetIndex), _stopCount(route))}';

        // Landscape only happens inside focus mode (the app is portrait-locked
        // otherwise). A full-width banner across a wide screen would bury the
        // map, so the HUD becomes a super-thin vertical rail instead.
        final isLandscape =
            MediaQuery.orientationOf(context) == Orientation.landscape;
        if (isLandscape) {
          return Positioned.fill(
            child: SafeArea(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: 8),
                  child: _LandscapeHudRail(
                    isReturn: isReturn,
                    subtitle: subtitle,
                    label: target.label,
                    address: target.address,
                    instruction: instruction,
                    distanceToTarget: distanceToTarget,
                    remainingKm: remainingKm,
                    arrived: state.navigationArrived,
                    onServe: cubit.servePoint,
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
              // ── Top: instruction banner + next stop + timeline ──
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: Column(
                    children: [
                      if (instruction != null)
                        _InstructionBanner(instruction: instruction),
                      const SizedBox(height: 6),
                      _NextStopBar(
                        isReturn: isReturn,
                        subtitle: subtitle,
                        label: target.label,
                        distanceToTarget: distanceToTarget,
                        // Escape hatch: a long-press serves the point even
                        // when GPS never registers the 10 m radius.
                        onLongPress: cubit.servePoint,
                      ),
                      // One-shot "service point completed" notice for
                      // automatic completions.
                      const _AutoServeNotice(),
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

              // ── Bottom: Point Served + full panel (or slim focus bar) ──
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ServedButton(
                        visible: state.navigationArrived,
                        label: isReturn
                            ? AppStrings.endTrip
                            : AppStrings.pointServed,
                        icon: isReturn ? Iconsax.flag : Iconsax.tick_circle,
                        onTap: cubit.servePoint,
                      ),
                      _focusMode
                          ? _FocusExitBar(
                              remaining: MetricFormat.distance(remainingKm),
                              onExit: () => _setFocusMode(false),
                            )
                          : _BottomPanel(
                              remainingKm: remainingKm,
                              remainingMinutes: remainingMinutes,
                              speedMps: state.navigationSpeedMps,
                              onFocus: () => _setFocusMode(true),
                              onOpenGoogleMaps: widget.onOpenGoogleMaps,
                              onEndTrip: cubit.stopNavigation,
                              debugStep:
                                  kDebugMode ? cubit.debugStepForward : null,
                            ),
                    ],
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

/// Top maneuver banner: big icon, counting-down distance, localized
/// instruction and the road it leads onto — dark, high-contrast, readable
/// in sunlight at a glance.
class _InstructionBanner extends StatelessWidget {
  final NavInstruction instruction;
  const _InstructionBanner({required this.instruction});

  @override
  Widget build(BuildContext context) {
    final road = instruction.roadName;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.asphalt.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          children: [
            // Maneuver glyph — cross-fades when the maneuver changes so
            // transitions feel deliberate, not flickery.
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(scale: anim, child: child),
                ),
                child: Icon(
                  instruction.icon,
                  key: ValueKey(instruction.icon.codePoint),
                  color: AppColors.white,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The headline number: distance to the maneuver, updated
                  // on every progress tick.
                  Text(
                    MetricFormat.distance(instruction.distanceMeters / 1000),
                    style: AppTextStyles.h2.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    instruction.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleSm.copyWith(
                      color: AppColors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  if (road != null && road.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      road,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Slim pill under the instruction banner: which service point is next
/// (n of m + name) and how far it is. Long-press = manual serve escape
/// hatch when GPS can't register the service radius.
class _NextStopBar extends StatelessWidget {
  final bool isReturn;
  final String subtitle;
  final String label;
  final double? distanceToTarget;
  final VoidCallback onLongPress;

  const _NextStopBar({
    required this.isReturn,
    required this.subtitle,
    required this.label,
    required this.distanceToTarget,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        HapticFeedback.heavyImpact();
        onLongPress();
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.asphalt.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  isReturn ? Iconsax.repeat : Iconsax.location,
                  color: AppColors.white,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.mutedSm.copyWith(
                        color: AppColors.white.withValues(alpha: 0.65),
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleSm.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (distanceToTarget != null) ...[
                const SizedBox(width: 8),
                Text(
                  MetricFormat.distance(distanceToTarget!),
                  style: AppTextStyles.titleMd.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One-shot animated notice for automatic service completion:
/// "Service point completed. Navigating to next stop."
class _AutoServeNotice extends StatefulWidget {
  const _AutoServeNotice();

  @override
  State<_AutoServeNotice> createState() => _AutoServeNoticeState();
}

class _AutoServeNoticeState extends State<_AutoServeNotice> {
  bool _visible = false;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _flash() {
    _hideTimer?.cancel();
    setState(() => _visible = true);
    _hideTimer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RoutePlannerCubit, RoutePlannerState>(
      listenWhen: (a, b) =>
          b.autoServeCount > a.autoServeCount && b.navigationActive,
      listener: (_, __) => _flash(),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: !_visible
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(top: 6),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _visible ? 1 : 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 14,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Iconsax.tick_circle,
                            color: AppColors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppStrings.autoServedNotice,
                              maxLines: 2,
                              style: AppTextStyles.bodySm.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// The "Point Served" action: hidden until the driver is inside the
/// service radius, then springs in as a large, impossible-to-miss button
/// that's easy to hit while stopped.
class _ServedButton extends StatelessWidget {
  final bool visible;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ServedButton({
    required this.visible,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: !visible
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                scale: visible ? 1 : 0.8,
                child: Material(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(18),
                  elevation: 8,
                  shadowColor: AppColors.shadow,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onTap();
                    },
                    child: SizedBox(
                      height: 58,
                      width: double.infinity,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, color: AppColors.white, size: 24),
                          const SizedBox(width: 10),
                          Text(
                            label,
                            style: AppTextStyles.h3.copyWith(
                              color: AppColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

/// Bottom glass panel: trip stats (remaining distance / time / arrival
/// clock / live speed), the focus toggle, and Maps / End-trip actions.
class _BottomPanel extends StatelessWidget {
  final double remainingKm;
  final double? remainingMinutes;
  final double? speedMps;
  final VoidCallback onFocus;
  final VoidCallback? onOpenGoogleMaps;
  final VoidCallback onEndTrip;
  final VoidCallback? debugStep;

  const _BottomPanel({
    required this.remainingKm,
    required this.remainingMinutes,
    required this.speedMps,
    required this.onFocus,
    required this.onOpenGoogleMaps,
    required this.onEndTrip,
    required this.debugStep,
  });

  @override
  Widget build(BuildContext context) {
    final eta = remainingMinutes != null
        ? DateFormat('HH:mm').format(
            DateTime.now().add(Duration(minutes: remainingMinutes!.round())),
          )
        : null;
    final kmh = speedMps != null ? (speedMps! * 3.6).round() : null;

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      radius: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: remaining distance · time · arrival — plus live speed
          // and the focus toggle.
          Row(
            children: [
              Icon(Iconsax.routing, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      MetricFormat.distance(remainingKm),
                      style: AppTextStyles.titleSm,
                    ),
                    if (remainingMinutes != null) ...[
                      Text('·', style: AppTextStyles.mutedSm),
                      Text(
                        MetricFormat.duration(remainingMinutes!),
                        style: AppTextStyles.titleSm,
                      ),
                    ],
                    if (eta != null) ...[
                      Text('·', style: AppTextStyles.mutedSm),
                      Text(
                        '${AppStrings.arrivalLabel} $eta',
                        style: AppTextStyles.mutedSm,
                      ),
                    ],
                  ],
                ),
              ),
              if (kmh != null && kmh > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$kmh ${AppStrings.speedUnitKmh}',
                    style: AppTextStyles.mutedSm.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              _FocusToggleButton(onTap: onFocus),
            ],
          ),
          const SizedBox(height: 8),

          // Secondary actions. Serving happens with the big Point Served
          // button (only shown at the stop), so the panel stays minimal.
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
                  background: AppColors.danger.withValues(alpha: 0.10),
                  foreground: AppColors.danger,
                  onTap: onEndTrip,
                ),
              ),
            ],
          ),

          // ── DEBUG ONLY — visible drive-test stepper,
          // compiled out of release builds via [kDebugMode].
          if (debugStep != null) ...[
            const SizedBox(height: 6),
            _DebugStepButton(onStep: debugStep!),
          ],
        ],
      ),
    );
  }
}

/// Super-thin landscape rail for focus mode.
///
/// A single narrow vertical strip on the leading edge — icons and numbers
/// stacked, no text labels — so it occupies almost no width and stays clear
/// of the driver's view. Shows: the upcoming maneuver (icon + distance),
/// next-stop distance, remaining trip distance, a serve control while at
/// the stop, and an icon-only exit back to portrait.
///
/// Tapping the next-stop badge expands the rail to reveal the stop name (and
/// "Next stop · N of M" heading); tapping again collapses it. The expand state
/// is local — width animates so the map is uncovered again the moment it closes.
class _LandscapeHudRail extends StatefulWidget {
  final bool isReturn;
  final String subtitle;
  final String label;
  final String? address;
  final NavInstruction? instruction;
  final double? distanceToTarget;
  final double remainingKm;
  final bool arrived;
  final VoidCallback onServe;
  final VoidCallback onExitFocus;

  const _LandscapeHudRail({
    required this.isReturn,
    required this.subtitle,
    required this.label,
    required this.address,
    required this.instruction,
    required this.distanceToTarget,
    required this.remainingKm,
    required this.arrived,
    required this.onServe,
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
    final instruction = widget.instruction;
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
                // Upcoming maneuver — the primary in-drive information.
                if (instruction != null) ...[
                  Icon(instruction.icon, size: 22, color: AppColors.white),
                  const SizedBox(height: 2),
                  Text(
                    MetricFormat.distance(instruction.distanceMeters / 1000),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleSm.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.white.withValues(alpha: 0.15),
                  ),
                  const SizedBox(height: 8),
                ],
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

                // Serve control — only while inside the service radius.
                if (widget.arrived) ...[
                  const SizedBox(height: 10),
                  Align(
                    child: Material(
                      color: AppColors.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          widget.onServe();
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(11),
                          child: Icon(
                            Iconsax.tick_circle,
                            size: 20,
                            color: AppColors.white,
                          ),
                        ),
                      ),
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
/// When the simulated position crosses a stop's arc-length fraction the
/// cubit auto-advances the stop index, same as the real GPS logic.
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
              Icon(
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
