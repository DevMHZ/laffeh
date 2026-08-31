import 'dart:async';
import 'dart:ui' as ui show TextDirection;

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
import '../../../../core/widgets/whatsapp_glyph.dart';
import '../../domain/entities/optimized_route.dart';
import '../pages/route_planner_actions.dart';
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
///   * Slim next-stop bar + horizontal stop timeline underneath, with
///     one-tap WhatsApp / Call for whoever is waiting at that stop.
///   * Bottom info panel: remaining distance, time and arrival clock,
///     live speed, focus toggle, Maps / End-trip actions.
///   * An **arrival bar** — one line that appears once the driver reaches
///     the current stop: the button that marks it served, plus a circle
///     each for WhatsApp and Call when the stop has a number. Serving is
///     always the driver's own act; nothing completes a point on their
///     behalf, and the bar waits until they press it.
///
/// Arriving also *removes* things — the maneuver banner and the stop
/// timeline both stand down — because the screen a driver reads at a
/// customer's door is a map, not a dashboard.
class RouteNavigationOverlay extends StatefulWidget {
  final VoidCallback? onOpenGoogleMaps;

  const RouteNavigationOverlay({super.key, this.onOpenGoogleMaps});

  @override
  State<RouteNavigationOverlay> createState() => _RouteNavigationOverlayState();
}

class _RouteNavigationOverlayState extends State<RouteNavigationOverlay> {
  /// Portrait-only — the app's default everywhere outside drive mode.
  static const _portraitOnly = <DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ];

  /// All orientations — drive mode lets the driver turn a mounted phone
  /// sideways for a wide map at any time (not just in focus mode).
  /// Rotation stays the user's choice; we only permit it, never force it.
  static const _allOrientations = <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  /// When true the HUD collapses to an eyes-on-road minimum: only the slim
  /// instruction banner and an exit control remain, so the map fills the
  /// screen.
  bool _focusMode = false;

  void _setFocusMode(bool enabled) {
    if (_focusMode == enabled) return;
    setState(() => _focusMode = enabled);
  }

  @override
  void initState() {
    super.initState();
    // The whole drive is rotatable: this overlay is only mounted while
    // navigation is active, so unlocking here scopes landscape to drive
    // mode exactly.
    SystemChrome.setPreferredOrientations(_allOrientations);
  }

  @override
  void dispose() {
    // The trip can end from anywhere (Point Served at the last stop, End
    // Trip, a stream error). Always restore the portrait lock so the rest
    // of the app is never left rotatable.
    SystemChrome.setPreferredOrientations(_portraitOnly);
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
          a.navigationStopRouteDistanceMeters !=
              b.navigationStopRouteDistanceMeters ||
          a.navigationSpeedMps != b.navigationSpeedMps ||
          a.maneuverFractions != b.maneuverFractions ||
          a.userLocation != b.userLocation ||
          a.optimizedRoute != b.optimizedRoute ||
          a.isRerouting != b.isRerouting,
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
        // A depot and one place to be: this is a plain drive somewhere, so
        // the HUD says so. "Next stop · 1 of 1" and "Point served" are the
        // vocabulary of a round the driver never asked for.
        final soleDestination =
            route.orderedPoints.length == 2 && !route.orderedPoints[1].isDepot;

        // The trip is never "finished" while navigation is active — the
        // driver must serve the final point to end it.
        const finished = false;

        // Live distance to the current service point — how far there is
        // left to *drive*, measured along the planned route, so U-turns,
        // one-ways and detours are all in the number. The straight line is
        // only a fallback: off-route (no trustworthy projection) and before
        // the first fix, when nothing better exists.
        final loc = state.userLocation;
        final routeMeters = state.navigationStopRouteDistanceMeters;
        final distanceToTarget = routeMeters != null
            ? routeMeters / 1000
            : (state.navigationStopDistanceMeters != null
                  ? state.navigationStopDistanceMeters! / 1000
                  : (loc == null
                        ? null
                        : DistanceUtils.haversineKm(loc, target.latLng)));
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
            : soleDestination
            ? AppStrings.destinationTitle
            : '${AppStrings.nextStop} · '
                  '${AppStrings.stopNofM(_stopNumber(route, targetIndex), _stopCount(route))}';

        // The button that finishes the leg. Serving the last point already
        // ends the trip (see the cubit's service machine) — this only makes
        // the word match what it does.
        final serveLabel = isReturn
            ? AppStrings.endTrip
            : soleDestination
            ? AppStrings.arrivedHere
            : AppStrings.pointServed;
        final serveIcon = isReturn ? Iconsax.flag : Iconsax.tick_circle;

        // ── Reaching whoever is waiting ────────────────────────────
        //
        // A *driving* task, not a planning one: "I'm five minutes away",
        // "nobody is answering the gate", "which building is it?". The
        // number is already on the stop; the HUD just has to offer it.
        //
        // Two moments, and they want different things:
        //
        //   * **on the way** — the controls ride on the next-stop pill,
        //     beside the name they belong to, and WhatsApp opens saying "I'm
        //     on my way";
        //   * **at the stop** — they move down into their own card above
        //     "Point served", because that is where the driver's eye and
        //     thumb already are once they have parked, and WhatsApp opens
        //     saying "I've arrived".
        //
        // The pill gives them up while arrived rather than showing both: one
        // pair of buttons on screen, always the pair for right now.
        final arrived = state.navigationArrived;
        final phone = target.hasPhone ? target.phone! : null;

        VoidCallback? reach(Future<void> Function(BuildContext, String) via) =>
            phone == null ? null : () => via(context, phone);
        final onCallStop = reach(RoutePlannerActions.callStop);
        final onWhatsappStop = phone == null
            ? null
            : () => RoutePlannerActions.messageStopOnWhatsapp(
                context,
                phone,
                message: arrived
                    ? AppStrings.stopWhatsappArrived
                    : AppStrings.stopWhatsappOnTheWay,
              );

        // Nothing here offers to *add* a number. Most stops carry none —
        // one dropped on the map or found by search never does — and the
        // drive HUD used to answer that with a card saying so and a button
        // opening a keypad. On the screen a driver reads at a customer's
        // door, the common case was a paragraph about an absence. Typing a
        // number is planning work; it lives on the stop, in the planning
        // sheet, where there is a keyboard and no engine running.

        // Landscape is available for the whole drive. A full-width banner
        // across a wide screen would bury the map, so the HUD docks on the
        // leading edge instead: a full column of the same cards outside
        // focus mode, or the super-thin rail inside it.
        final isLandscape =
            MediaQuery.orientationOf(context) == Orientation.landscape;
        if (isLandscape) {
          if (_focusMode) {
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
                      speedMps: state.navigationSpeedMps,
                      arrived: state.navigationArrived,
                      serveLabel: serveLabel,
                      onServe: cubit.servePoint,
                      onWhatsapp: onWhatsappStop,
                      onCall: onCallStop,
                      onExitFocus: () => _setFocusMode(false),
                    ),
                  ),
                ),
              ),
            );
          }
          // Landscape, full HUD: everything the portrait layout offers,
          // stacked in a side column so the map keeps most of the width.
          return Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 330),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (instruction != null && !arrived)
                          _InstructionBanner(instruction: instruction),
                        if (instruction != null && !arrived)
                          const SizedBox(height: 6),
                        _NextStopBar(
                          isReturn: isReturn,
                          arrived: arrived,
                          subtitle: subtitle,
                          label: target.label,
                          distanceToTarget: distanceToTarget,
                          onLongPress: cubit.servePoint,
                          onWhatsapp: arrived ? null : onWhatsappStop,
                          onCall: arrived ? null : onCallStop,
                        ),
                        _ReroutingNotice(visible: state.isRerouting),
                        const Spacer(),
                        _ArrivedBar(
                          visible: arrived,
                          label: serveLabel,
                          icon: serveIcon,
                          onServe: cubit.servePoint,
                          onWhatsapp: onWhatsappStop,
                          onCall: onCallStop,
                        ),
                        _BottomPanel(
                          remainingKm: remainingKm,
                          remainingMinutes: remainingMinutes,
                          speedMps: state.navigationSpeedMps,
                          onFocus: () => _setFocusMode(true),
                          onOpenGoogleMaps: widget.onOpenGoogleMaps,
                          onReoptimize: cubit.reoptimizeRemaining,
                          onEndTrip: cubit.stopNavigation,
                        ),
                      ],
                    ),
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
                      // Arriving retires the maneuver banner. There is no
                      // next turn at a customer's door, and the biggest,
                      // darkest panel on the screen was spending the top of
                      // the map saying so.
                      if (instruction != null && !arrived) ...[
                        _InstructionBanner(instruction: instruction),
                        const SizedBox(height: 6),
                      ],
                      _NextStopBar(
                        isReturn: isReturn,
                        arrived: arrived,
                        subtitle: subtitle,
                        label: target.label,
                        distanceToTarget: distanceToTarget,
                        // Escape hatch: a long-press serves the point even
                        // when GPS never registers the 10 m radius.
                        onLongPress: cubit.servePoint,
                        onWhatsapp: arrived ? null : onWhatsappStop,
                        onCall: arrived ? null : onCallStop,
                      ),
                      // Subtle live notice while a deviation triggers a
                      // background route recalculation.
                      _ReroutingNotice(visible: state.isRerouting),
                      // The timeline is a picture of a sequence. With one
                      // place to be there is no sequence to picture, so it
                      // stays away and the map keeps the room — and at the
                      // stop the sequence is not the question either.
                      if (!_focusMode && !soleDestination && !arrived) ...[
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
                      // Everything arriving needs, on one line: the button
                      // that closes the leg, and — only if there is somebody
                      // to reach — the two ways to reach them.
                      _ArrivedBar(
                        visible: arrived,
                        label: serveLabel,
                        icon: serveIcon,
                        onServe: cubit.servePoint,
                        onWhatsapp: onWhatsappStop,
                        onCall: onCallStop,
                      ),
                      _focusMode
                          ? _FocusExitBar(
                              speedMps: state.navigationSpeedMps,
                              onExit: () => _setFocusMode(false),
                            )
                          : _BottomPanel(
                              remainingKm: remainingKm,
                              remainingMinutes: remainingMinutes,
                              speedMps: state.navigationSpeedMps,
                              onFocus: () => _setFocusMode(true),
                              onOpenGoogleMaps: widget.onOpenGoogleMaps,
                              onReoptimize: cubit.reoptimizeRemaining,
                              onEndTrip: cubit.stopNavigation,
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
///
/// When the stop carries a phone number the pill grows a second line: one
/// full-width button per channel, WhatsApp and Call, side by side.
///
/// Two buttons rather than one that opens a chooser, and no hiding them
/// behind a tap on the pill. This is a HUD in a moving vehicle: every extra
/// step is a second longer looking down, and a hidden control is one the
/// driver has to remember exists. They are also deliberately sized like the
/// serve button rather than like icons — a thumb aiming at a phone clipped
/// to a windscreen is not a thumb aiming at a 20 px target.
class _NextStopBar extends StatelessWidget {
  final bool isReturn;

  /// At the stop the pill stops being a heading and becomes an answer:
  /// a tick, the word for it, and the name. The distance goes — "0 m" to
  /// somewhere the driver is standing is noise — and so does the contact
  /// row, which has moved down to the arrival bar where the thumb is.
  final bool arrived;

  final String subtitle;
  final String label;
  final double? distanceToTarget;
  final VoidCallback onLongPress;

  /// Null when the stop has no number — which is also the depot's answer on
  /// the leg home.
  final VoidCallback? onWhatsapp;
  final VoidCallback? onCall;

  const _NextStopBar({
    required this.isReturn,
    required this.arrived,
    required this.subtitle,
    required this.label,
    required this.distanceToTarget,
    required this.onLongPress,
    this.onWhatsapp,
    this.onCall,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: arrived ? AppColors.success : AppColors.primary,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      arrived
                          ? Iconsax.tick_circle
                          : isReturn
                          ? Iconsax.repeat
                          : Iconsax.location,
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
                          arrived ? AppStrings.arrivedHere : subtitle,
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
                  if (distanceToTarget != null && !arrived) ...[
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
              if (onWhatsapp != null || onCall != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (onWhatsapp != null)
                      Expanded(
                        child: _ContactButton(
                          // The real mark, not a generic chat bubble: at a
                          // glance in a moving car, the logo is read before
                          // the word underneath it ever is.
                          glyph: const WhatsappGlyph(
                            size: 19,
                            color: AppColors.white,
                          ),
                          label: AppStrings.stopWhatsapp,
                          // White on a green wash rather than green text:
                          // the tint is what separates the two buttons, and
                          // white is the one foreground that survives every
                          // palette on asphalt.
                          background: AppColors.success.withValues(alpha: 0.28),
                          onTap: onWhatsapp!,
                        ),
                      ),
                    if (onWhatsapp != null && onCall != null)
                      const SizedBox(width: 8),
                    if (onCall != null)
                      Expanded(
                        child: _ContactButton(
                          glyph: const Icon(
                            Iconsax.call,
                            size: 19,
                            color: AppColors.white,
                          ),
                          label: AppStrings.stopCall,
                          background: AppColors.white.withValues(alpha: 0.13),
                          onTap: onCall!,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One channel to the stop's contact, sized for a thumb in a moving car.
///
/// Height, radius and weight are borrowed from the serve button rather than
/// from anything in the planning sheet: on this screen a control is either
/// hittable without aiming or it may as well not be there.
class _ContactButton extends StatelessWidget {
  final Widget glyph;
  final String label;
  final Color background;

  final VoidCallback onTap;

  /// Sized for the next-stop pill, its one home: tall enough for a thumb
  /// aiming at a windscreen mount, short enough that the pill stays a pill.
  static const double _height = 46;

  const _ContactButton({
    required this.glyph,
    required this.label,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          height: _height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              glyph,
              const SizedBox(width: 8),
              // Arabic "واتساب" beside a logo on half a narrow phone is
              // tight; shrink the word rather than clip it.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: AppTextStyles.titleSm.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slim live pill shown while a deviation-triggered route recalculation is
/// in flight: spinner + "recalculating route". Collapses to nothing the
/// moment the fresh route lands, so a fast reroute barely registers.
class _ReroutingNotice extends StatelessWidget {
  final bool visible;
  const _ReroutingNotice({required this.visible});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: !visible
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 6),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.asphalt.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AppStrings.rerouting,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.white.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w700,
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

/// Everything arriving needs, on one line.
///
/// What used to be here was a card and a button: a titled panel naming the
/// stop, repeating its number, offering to take one when there wasn't
/// one — and under it a full-width "Point served". Together they took a
/// third of the screen at the exact moment the driver is parked at a door
/// trying to see which building it is on the map.
///
/// So it collapses to a single row: the button that closes the leg takes
/// the width, and the two ways to reach the customer become plain circles
/// beside it. Nothing is written that the driver already knows — the name
/// is on the pill at the top, the number is on the phone once it dials —
/// and when the stop has nobody to call, the row is only the button.
///
/// It appears once the driver is at the stop and does not leave again
/// until they press it. Serving is theirs to declare now: the app no
/// longer decides a point was done because the vehicle drove away from it.
class _ArrivedBar extends StatelessWidget {
  final bool visible;
  final String label;
  final IconData icon;
  final VoidCallback onServe;

  /// Null when the stop has no number, which is most stops — then the row
  /// is the serve button alone, and says nothing about the absence.
  final VoidCallback? onWhatsapp;
  final VoidCallback? onCall;

  const _ArrivedBar({
    required this.visible,
    required this.label,
    required this.icon,
    required this.onServe,
    required this.onWhatsapp,
    required this.onCall,
  });

  /// One height for the whole row, so the circles read as siblings of the
  /// button rather than as decoration on it.
  static const double _height = 60;

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
                child: Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(18),
                        elevation: 8,
                        shadowColor: AppColors.shadow,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            onServe();
                          },
                          child: SizedBox(
                            height: _height,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(icon, color: AppColors.white, size: 24),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      label,
                                      maxLines: 1,
                                      style: AppTextStyles.h3.copyWith(
                                        color: AppColors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (onWhatsapp != null) ...[
                      const SizedBox(width: 8),
                      _RoundContact(
                        background: AppColors.success,
                        onTap: onWhatsapp!,
                        child: const WhatsappGlyph(
                          size: 24,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                    if (onCall != null) ...[
                      const SizedBox(width: 8),
                      _RoundContact(
                        background: AppColors.asphalt,
                        onTap: onCall!,
                        child: const Icon(
                          Iconsax.call,
                          size: 24,
                          color: AppColors.white,
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

/// One way to reach the customer, at the stop: a glyph in a circle, no
/// label under it.
///
/// The word was worth having on the next-stop pill, where the buttons are
/// an offer the driver has not thought about yet. Here they have parked in
/// front of the address; a green WhatsApp mark and a handset are read
/// faster than either word, and the two saved lines are map.
class _RoundContact extends StatelessWidget {
  final Widget child;
  final Color background;
  final VoidCallback onTap;

  const _RoundContact({
    required this.child,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      elevation: 6,
      shadowColor: AppColors.shadow,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          width: _ArrivedBar._height,
          height: _ArrivedBar._height,
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Bottom glass panel — the drive HUD's status + controls dock.
///
/// Two clearly separated tiers so nothing has to compete for room:
///   * A **stat strip** — remaining distance, remaining time (with the
///     arrival clock as its caption) and live speed, each a number over a
///     small label inside one shared tray, with the focus toggle beside it.
///     Numbers scale down rather than truncate, so a long duration or a
///     large text-scale setting never clips a digit.
///   * An **action row** — Maps / Re-optimize / End trip, stacked
///     icon-over-label so each button owns its full width. Arabic labels
///     are far too long to survive an icon sitting next to them at a third
///     of the screen, which is exactly why the old side-by-side row read as
///     "خرائط Goo…".
class _BottomPanel extends StatelessWidget {
  final double remainingKm;
  final double? remainingMinutes;
  final double? speedMps;
  final VoidCallback onFocus;
  final VoidCallback? onOpenGoogleMaps;
  final VoidCallback onReoptimize;
  final VoidCallback onEndTrip;

  const _BottomPanel({
    required this.remainingKm,
    required this.remainingMinutes,
    required this.speedMps,
    required this.onFocus,
    required this.onOpenGoogleMaps,
    required this.onReoptimize,
    required this.onEndTrip,
  });

  @override
  Widget build(BuildContext context) {
    final eta = remainingMinutes != null
        ? DateFormat('HH:mm').format(
            DateTime.now().add(Duration(minutes: remainingMinutes!.round())),
          )
        : null;

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      radius: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Tier 1: the numbers the driver glances at ──
          Row(
            children: [
              Expanded(
                child: Container(
                  height: _kStatTrayHeight,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          value: MetricFormat.distance(remainingKm),
                          label: AppStrings.remainingShort,
                        ),
                      ),
                      const _StatDivider(),
                      Expanded(
                        child: _Stat(
                          value: remainingMinutes != null
                              ? MetricFormat.duration(remainingMinutes!)
                              : '--',
                          // The clock rides along as the caption: it
                          // answers "when", the number above answers
                          // "how long".
                          label: eta != null
                              ? '${AppStrings.arrivalLabel} $eta'
                              : AppStrings.remainingTime,
                        ),
                      ),
                      const _StatDivider(),
                      Expanded(
                        child: _Stat(
                          value: '${_kmh(speedMps)}',
                          label: AppStrings.speedUnitKmh,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _FocusToggleButton(onTap: onFocus),
            ],
          ),
          const SizedBox(height: 10),

          // ── Tier 2: the controls ──
          // Serving happens with the big Point Served button (only shown
          // at the stop), so the panel stays minimal.
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
              const SizedBox(width: 8),
              // Mid-trip re-plan: re-optimizes the unserved stops from the
              // current position and drops straight back into the drive.
              Expanded(
                child: _BigAction(
                  icon: Iconsax.refresh,
                  label: AppStrings.reoptimize,
                  background: AppColors.primary.withValues(alpha: 0.10),
                  foreground: AppColors.primary,
                  onTap: onReoptimize,
                ),
              ),
              const SizedBox(width: 8),
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

          // ── DEBUG ONLY — the synthetic drive simulator controls,
          // compiled out of release builds via [kDebugMode].
          // Deliberately non-const: the steer chips recolour when the
          // driver leaves/rejoins the road, so the bar must rebuild with
          // the panel on every tick.
          if (kDebugMode) ...[
            const SizedBox(height: 8),
            // ignore: prefer_const_constructors
            _DebugSimBar(),
          ],
        ],
      ),
    );
  }
}

/// Height of the stat tray — shared with the focus toggle so the two sit
/// as a matched pair on one line.
const double _kStatTrayHeight = 52;

/// One cell of the stat tray: a number with its caption underneath.
///
/// Both lines shrink to fit instead of ellipsizing. In a HUD a clipped
/// number is worse than a slightly smaller one, and Arabic captions
/// ("الوصول 17:18") are long enough that a fixed size would clip on a
/// narrow phone or at a large text-scale setting.
class _Stat extends StatelessWidget {
  final String value;
  final String label;

  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: AppTextStyles.titleLg.copyWith(height: 1.1),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: AppTextStyles.mutedSm.copyWith(height: 1.1),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hairline between two stat cells.
class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 26,
      color: AppColors.border.withValues(alpha: 0.7),
    );
  }
}

/// Super-thin landscape rail for focus mode.
///
/// A single narrow vertical strip on the leading edge — icons and numbers
/// stacked, no text labels — so it occupies almost no width and stays clear
/// of the driver's view. Shows: the upcoming maneuver (icon + distance),
/// next-stop distance, current speed, a serve control while at the stop,
/// and an icon-only exit back to portrait.
///
/// Tapping the next-stop badge expands the rail to reveal the stop name (and
/// "Next stop · N of M" heading); tapping again collapses it. The expand state
/// is local — width animates so the map is uncovered again the moment it closes.
///
/// Contact keeps its place here too, as two stacked circles. Focus mode is
/// where a driver spends the long stretches between stops, so it is exactly
/// where "call ahead" happens — sending them back to portrait for it would
/// undo the point of the rail.
class _LandscapeHudRail extends StatefulWidget {
  final bool isReturn;
  final String subtitle;
  final String label;
  final String? address;
  final NavInstruction? instruction;
  final double? distanceToTarget;
  final double? speedMps;
  final bool arrived;

  /// What the serve button says — "point served", "arrived", or "end trip"
  /// on the leg home. The rail used to say nothing at all, which made the
  /// one irreversible control on the screen the only unlabelled one.
  final String serveLabel;
  final VoidCallback onServe;
  final VoidCallback? onWhatsapp;
  final VoidCallback? onCall;
  final VoidCallback onExitFocus;

  const _LandscapeHudRail({
    required this.isReturn,
    required this.subtitle,
    required this.label,
    required this.address,
    required this.instruction,
    required this.distanceToTarget,
    required this.speedMps,
    required this.arrived,
    required this.serveLabel,
    required this.onServe,
    required this.onWhatsapp,
    required this.onCall,
    required this.onExitFocus,
  });

  @override
  State<_LandscapeHudRail> createState() => _LandscapeHudRailState();
}

class _LandscapeHudRailState extends State<_LandscapeHudRail> {
  bool _expanded = false;

  /// The rail is a sliver by choice — eyes on the road, map everywhere
  /// else. Arriving is the one moment that choice stops being right: the
  /// driver has parked, and what they need now is a button they can hit
  /// without aiming and a name on it telling them what it does. So the
  /// rail opens itself, whether or not they ever tapped it open.
  bool get _open => _expanded || widget.arrived;

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
        constraints: BoxConstraints(maxWidth: _open ? 200 : 58),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.asphalt.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(_open ? 22 : 28),
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
              horizontal: _open ? 12 : 6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Upcoming maneuver — the primary in-drive information,
                // and beside a customer's door, no information at all.
                if (instruction != null && !widget.arrived) ...[
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

                // Stop name + heading — whenever the rail is open.
                if (_open) ...[
                  const SizedBox(height: 2),
                  Text(
                    // The same answer the portrait pill gives: at the door,
                    // "next stop · 1 of 4" is describing a queue the driver
                    // has already reached the front of.
                    widget.arrived ? AppStrings.arrivedHere : widget.subtitle,
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

                // Live distance to the target — the big number, until
                // there is no distance left to run.
                if (widget.distanceToTarget != null && !widget.arrived) ...[
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

                // Contact — above the serve control, because it is the
                // one that matters *before* arriving. Collapsed the rail is
                // 58 wide, so the two circles sit on one line; open, they
                // grow to the size a parked thumb expects.
                if (widget.onWhatsapp != null || widget.onCall != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.onWhatsapp != null)
                        _RailCircleButton(
                          background: widget.arrived
                              ? AppColors.success
                              : AppColors.success.withValues(alpha: 0.30),
                          big: widget.arrived,
                          onTap: widget.onWhatsapp!,
                          child: WhatsappGlyph(
                            size: widget.arrived ? 22 : 18,
                            color: AppColors.white,
                          ),
                        ),
                      if (widget.onWhatsapp != null && widget.onCall != null)
                        SizedBox(width: widget.arrived ? 10 : 6),
                      if (widget.onCall != null)
                        _RailCircleButton(
                          background: widget.arrived
                              ? AppColors.white.withValues(alpha: 0.22)
                              : AppColors.white.withValues(alpha: 0.13),
                          big: widget.arrived,
                          onTap: widget.onCall!,
                          child: Icon(
                            Iconsax.call,
                            size: widget.arrived ? 22 : 18,
                            color: AppColors.white,
                          ),
                        ),
                    ],
                  ),
                ],

                // Serve control — only once the driver has reached the
                // stop, and then as a named button across the whole rail
                // rather than a tick in a circle. Focus mode is a smaller
                // HUD, not a more cryptic one: the control that closes the
                // leg has to say what it does here exactly as it does in
                // the full HUD, and be as easy to hit.
                if (widget.arrived) ...[
                  const SizedBox(height: 12),
                  Material(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        widget.onServe();
                      },
                      child: SizedBox(
                        height: 50,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              widget.isReturn
                                  ? Iconsax.flag
                                  : Iconsax.tick_circle,
                              size: 20,
                              color: AppColors.white,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  widget.serveLabel,
                                  maxLines: 1,
                                  style: AppTextStyles.titleSm.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
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
                // Speedometer — the one number worth a glance in focus
                // mode besides the turn ahead.
                _RailSpeed(speedMps: widget.speedMps),
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

/// One round control on the landscape rail.
///
/// The rail's own serve and exit buttons predate it and are still written
/// out by hand; this exists because the two contact circles are a *pair*
/// and had to be identical, which is exactly the case a shared widget is
/// for.
class _RailCircleButton extends StatelessWidget {
  final Widget child;
  final Color background;

  /// True at the stop, where the rail is open and the thumb is not on a
  /// steering wheel — 52 px across instead of a glance-sized 38.
  final bool big;

  final VoidCallback onTap;

  const _RailCircleButton({
    required this.child,
    required this.background,
    required this.onTap,
    this.big = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          width: big ? 52 : 38,
          height: big ? 52 : 38,
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// DEBUG ONLY — control bar for the synthetic drive simulator.
///
/// Inactive: one button that hands the trip to the fake driver (real GPS
/// off, synthetic fixes through the full pipeline). Active, GTA-style:
///   * a speed chip cycling 0 → 20 → 40 → 60 → 90 km/h (0 = standing),
///   * يسار / يمين buttons that steer the driver 90° off its heading —
///     it leaves the road, the automatic reroute fires, and the car hops
///     onto the recalculated road as soon as it passes underneath.
class _DebugSimBar extends StatefulWidget {
  const _DebugSimBar();

  @override
  State<_DebugSimBar> createState() => _DebugSimBarState();
}

class _DebugSimBarState extends State<_DebugSimBar> {
  static const _speeds = <double>[0, 20, 40, 60, 90];

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RoutePlannerCubit>();

    if (!cubit.debugDriveSimActive) {
      return _chip(
        background: const Color(0xFF0E7490), // cyan-700
        expand: true,
        icon: Icons.smart_toy_outlined,
        label: 'محاكاة القيادة',
        onTap: () {
          cubit.debugStartDriveSim();
          setState(() {});
        },
      );
    }

    final kmh = cubit.debugDriveSimSpeedKmh;
    final free = cubit.debugDriveSimFreeDriving;
    final steerColor = free
        ? const Color(0xFFB91C1C) // red-700 — off the road
        : const Color(0xFFB45309); // amber-700

    // Forced LTR so "يسار" sits physically left and "يمين" physically
    // right regardless of the app's RTL layout — it's a steering wheel.
    return Row(
      textDirection: ui.TextDirection.ltr,
      children: [
        Expanded(
          child: _chip(
            background: steerColor,
            icon: Icons.turn_left_rounded,
            label: 'يسار',
            onTap: () {
              cubit.debugTurnDriveSim(-90);
              setState(() {});
            },
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _chip(
            background: const Color(0xFF334155), // slate-700
            icon: Icons.speed_rounded,
            label: '${kmh.round()} كم/س',
            onTap: () {
              final i = _speeds.indexWhere((s) => s > kmh + 0.5);
              cubit.debugSetDriveSimSpeed(i >= 0 ? _speeds[i] : _speeds.first);
              setState(() {});
            },
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _chip(
            background: steerColor,
            icon: Icons.turn_right_rounded,
            label: 'يمين',
            onTap: () {
              cubit.debugTurnDriveSim(90);
              setState(() {});
            },
          ),
        ),
      ],
    );
  }

  Widget _chip({
    required Color background,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool expand = false,
  }) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          height: 40,
          width: expand ? double.infinity : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.mutedSm.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Switches the HUD into eyes-on-road focus mode.
///
/// Sized and cornered to match the stat tray it sits beside, so the two
/// read as one line rather than a pill floating next to a box.
class _FocusToggleButton extends StatelessWidget {
  final VoidCallback onTap;
  const _FocusToggleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: SizedBox(
          height: _kStatTrayHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.center_focus_strong_rounded,
                  size: 19,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    AppStrings.focusMode,
                    maxLines: 1,
                    style: AppTextStyles.mutedSm.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
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

/// Slim bottom bar shown in focus mode: current speed plus a one-tap
/// control to leave focus mode. Kept minimal so the map dominates the screen.
class _FocusExitBar extends StatelessWidget {
  final double? speedMps;
  final VoidCallback onExit;
  const _FocusExitBar({required this.speedMps, required this.onExit});

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
                const Icon(
                  Iconsax.speedometer,
                  size: 17,
                  color: AppColors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_kmh(speedMps)}',
                  style: AppTextStyles.titleSm.copyWith(color: AppColors.white),
                ),
                const SizedBox(width: 4),
                Text(
                  AppStrings.speedUnitKmh,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.white.withValues(alpha: 0.70),
                  ),
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

/// Whole km/h from a metres-per-second fix. A missing or negative reading
/// reads as 0 rather than blanking the slot: in a fixed-height HUD an empty
/// speedometer looks broken, a standing 0 looks parked.
int _kmh(double? speedMps) {
  if (speedMps == null || !speedMps.isFinite || speedMps <= 0) return 0;
  return (speedMps * 3.6).round();
}

/// Focus-rail speedometer: the number large enough to read at a glance,
/// its unit tucked underneath.
class _RailSpeed extends StatelessWidget {
  final double? speedMps;
  const _RailSpeed({required this.speedMps});

  @override
  Widget build(BuildContext context) {
    final white70 = AppColors.white.withValues(alpha: 0.70);
    return Column(
      children: [
        Text(
          '${_kmh(speedMps)}',
          textAlign: TextAlign.center,
          style: AppTextStyles.titleMd.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        Text(
          AppStrings.speedUnitKmh,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySm.copyWith(color: white70, height: 1.1),
        ),
      ],
    );
  }
}

/// One of the panel's three drive actions.
///
/// Icon over label, not beside it: at a third of the screen the label is
/// the part that has to survive, and Arabic ("خرائط Google", "إعادة
/// التحسين") is long enough that an icon on the same line steals the room
/// it needs. Stacked, the text gets the button's whole width, and it
/// shrinks to fit rather than ellipsizing so a large text-scale setting
/// never leaves a driver reading half a word.
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground, size: 21),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleSm.copyWith(
                    color: foreground,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
