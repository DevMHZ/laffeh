import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_chevron.dart';
import '../../domain/entities/route_point.dart';
import '../../domain/entities/stop_time_window.dart';
import '../cubit/route_planner_cubit.dart';
import 'stop_time_window_sheet.dart';

/// Explains, per stop, why a requested arrival time can't be met — and
/// offers the ways out.
///
/// A red badge only says "something is wrong". This sheet answers the three
/// questions the driver actually has: which stop, by how much, and what can
/// I do about it. Every option here is one tap and re-solves the route, so
/// the user never has to work out a feasible time by hand.
///
/// Nothing here is ever reached for a stop the user set no availability on:
/// with no window there is no promise to break (see
/// [RoutePoint.timeWindowMissed]).
Future<void> showMissedTimeWindowSheet(BuildContext context) {
  final cubit = context.read<RoutePlannerCubit>();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) =>
        BlocProvider.value(value: cubit, child: const _MissedTimeWindowSheet()),
  );
}

/// The worst offender in [points] — the stop whose overshoot decides
/// whether this is a nudge or a re-plan.
RoutePoint _worstOffender(List<RoutePoint> points) {
  var worst = points.first;
  for (final p in points) {
    if ((p.latenessMinutes ?? 0) > (worst.latenessMinutes ?? 0)) worst = p;
  }
  return worst;
}

/// Shown after an optimization that couldn't honour every arrival time.
///
/// Deliberately two lines: the headline count, then the single worst stop
/// with the size of its overshoot. It used to list three stops and repeat
/// the sheet's content, which cost a third of the bottom sheet's height to
/// say what the sheet says better. A banner only has to be alarming enough
/// to open — the chevron and [showMissedTimeWindowSheet] carry the rest.
class MissedWindowBanner extends StatelessWidget {
  final List<RoutePoint> points;
  final VoidCallback onTap;

  const MissedWindowBanner({
    super.key,
    required this.points,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final worst = _worstOffender(points);

    return Material(
      color: AppColors.danger.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Iconsax.warning_2,
                  color: AppColors.danger,
                  size: 17,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.timeWindowMissedCount(points.length),
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 5),
                    // Which stop and by how much — the two facts that decide
                    // whether the driver opens this now or after loading up.
                    // Only the worst one: how many there are is already in
                    // the line above, and a "+2 more" tail here would eat the
                    // width the stop's own name needs.
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            worst.label,
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (worst.latenessMinutes != null) ...[
                          const SizedBox(width: 6),
                          LatenessPill(minutes: worst.latenessMinutes!),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              AppChevron(size: 20, color: AppColors.danger),
            ],
          ),
        ),
      ),
    );
  }
}

/// "25 min late", as a solid chip.
///
/// The one number in the whole flow that scales the problem, so it gets the
/// only fully-saturated fill on the card — everything around it is a tint.
class LatenessPill extends StatelessWidget {
  final int minutes;
  final bool compact;

  const LatenessPill({super.key, required this.minutes, this.compact = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        compact
            ? AppStrings.lateByShort(minutes)
            : AppStrings.lateByMinutes(minutes),
        style: AppTextStyles.bodySm.copyWith(
          color: AppColors.white,
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
      ),
    );
  }
}

class _MissedTimeWindowSheet extends StatelessWidget {
  const _MissedTimeWindowSheet();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RoutePlannerCubit>();
    final state = cubit.state;
    final late = state.missedTimeWindowPoints;
    if (late.isEmpty) return const SizedBox.shrink();

    final departureMinute = StopTimeWindow.minuteOfDay(
      state.departureAt ?? DateTime.now(),
    );
    final shift = cubit.requiredEarlierDepartureMinutes;
    final canLeaveEarlier = cubit.canDepartEarlier;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 30,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ── Headline: what happened, and that nothing was lost ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Iconsax.warning_2,
                      color: AppColors.danger,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppStrings.timeWindowMissedCount(late.length),
                          style: AppTextStyles.titleMd,
                        ),
                        const SizedBox(height: 3),
                        // Reassurance first: the route still contains every
                        // stop, so this is a scheduling choice, not a loss.
                        Text(
                          AppStrings.timeWindowMissedBody,
                          style: AppTextStyles.mutedSm,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── Per-stop breakdown: wanted vs. actual, and the gap ──
              for (final p in late) ...[
                _LateStopCard(point: p, departureMinute: departureMinute),
                const SizedBox(height: 8),
              ],

              const SizedBox(height: 10),
              _SectionLabel(AppStrings.howToFixIt),
              const SizedBox(height: 10),

              // Ordered by how little they cost the user: keep everything and
              // move the clock, then start sooner, then give up a stop.
              _FixOption(
                icon: Iconsax.clock,
                color: AppColors.primary,
                title: AppStrings.fixMoveDeadline,
                subtitle: AppStrings.fixMoveDeadlineWhy,
                onTap: () {
                  Navigator.pop(context);
                  cubit.relaxMissedTimeWindows();
                },
              ),
              const SizedBox(height: 8),
              if (canLeaveEarlier && shift != null)
                _FixOption(
                  icon: Iconsax.timer_start,
                  color: AppColors.info,
                  title: AppStrings.leaveEarlierBy(
                    shift,
                    TimeOfDay.fromDateTime(
                      state.departureAt!.subtract(Duration(minutes: shift)),
                    ).format(context),
                  ),
                  subtitle: AppStrings.fixLeaveEarlierWhy,
                  onTap: () {
                    Navigator.pop(context);
                    cubit.departEarlierToMakeWindows();
                  },
                )
              else
                // Departing "now" (or too soon) leaves no room to start
                // earlier, so the option is stated rather than offered.
                _FixOption(
                  icon: Iconsax.timer_start,
                  color: AppColors.textMuted,
                  title: AppStrings.fixLeaveEarlier,
                  subtitle: AppStrings.departureHint,
                  onTap: null,
                ),
              const SizedBox(height: 8),
              _FixOption(
                icon: Iconsax.eye_slash,
                color: AppColors.optionalOff,
                title: AppStrings.fixDropStop,
                subtitle: AppStrings.fixDropStopWhy,
                // More than one culprit means a second step (which stop?);
                // the chevron says so before the tap.
                showChevron: late.length > 1,
                onTap: () {
                  Navigator.pop(context);
                  // With one culprit there's nothing to choose between —
                  // skip it directly instead of asking which one.
                  if (late.length == 1) {
                    cubit.setPointIncluded(late.first.id, false);
                  } else {
                    _chooseStopToSkip(context, cubit, late);
                  }
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    AppStrings.keepAsIs,
                    style: AppTextStyles.titleSm.copyWith(
                      color: AppColors.textSecondary,
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

  /// Second step of "skip a stop" when more than one is running late.
  void _chooseStopToSkip(
    BuildContext context,
    RoutePlannerCubit cubit,
    List<RoutePoint> late,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
                child: Text(
                  AppStrings.fixDropStop,
                  style: AppTextStyles.titleMd,
                ),
              ),
              for (final p in late)
                ListTile(
                  leading: Icon(Iconsax.location, color: AppColors.optionalOff),
                  title: Text(p.label, style: AppTextStyles.titleSm),
                  subtitle: p.latenessMinutes == null
                      ? null
                      : Text(
                          AppStrings.lateByMinutes(p.latenessMinutes!),
                          style: AppTextStyles.mutedSm,
                        ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    cubit.setPointIncluded(p.id, false);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A quiet, all-caps-weight heading between the diagnosis and the fixes.
class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text, style: AppTextStyles.titleSm),
        const SizedBox(width: 10),
        Expanded(child: Divider(height: 1, color: AppColors.divider)),
      ],
    );
  }
}

/// One stop's story: what you asked for, what you'd actually get, and the
/// gap between them.
///
/// The two clocks sit side by side rather than stacked, because the whole
/// point is the comparison — "14:00 – 15:30" next to "15:55" makes the
/// overshoot readable without doing arithmetic.
class _LateStopCard extends StatelessWidget {
  final RoutePoint point;
  final int departureMinute;

  const _LateStopCard({required this.point, required this.departureMinute});

  @override
  Widget build(BuildContext context) {
    final window = point.timeWindow;
    final eta = point.etaMinutesFromDeparture;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  point.label,
                  style: AppTextStyles.titleSm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (point.latenessMinutes != null) ...[
                const SizedBox(width: 8),
                LatenessPill(minutes: point.latenessMinutes!, compact: false),
              ],
            ],
          ),
          if (window != null || eta != null) ...[
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The window the user entered, in full — the deadline alone
                  // hides half of what they asked for.
                  if (window != null)
                    Expanded(
                      child: _ClockColumn(
                        icon: Iconsax.tick_circle,
                        label: AppStrings.youWantedToArrive,
                        value: AppStrings.arrivalWindowRange(
                          formatMinuteOfDay(context, window.startMinuteOfDay),
                          formatMinuteOfDay(context, window.endMinuteOfDay),
                        ),
                        color: AppColors.textPrimary,
                      ),
                    ),
                  if (window != null && eta != null)
                    VerticalDivider(
                      width: 17,
                      thickness: 1,
                      color: AppColors.danger.withValues(alpha: 0.18),
                    ),
                  if (eta != null)
                    Expanded(
                      child: _ClockColumn(
                        icon: Iconsax.car,
                        label: AppStrings.youWouldArrive,
                        value: formatMinuteOfDay(
                          context,
                          StopTimeWindow.clockFromRelative(
                            departureMinute,
                            eta,
                          ),
                        ),
                        color: AppColors.danger,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One half of the comparison: a caption over the clock it describes.
class _ClockColumn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ClockColumn({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: AppColors.textMuted),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.mutedSm.copyWith(fontSize: 10.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            value,
            style: AppTextStyles.titleSm.copyWith(color: color),
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

/// One tappable way out. A null [onTap] renders it as a greyed-out
/// explanation — the option exists but doesn't apply to this trip.
class _FixOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool showChevron;
  final VoidCallback? onTap;

  const _FixOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: AppColors.surfaceAlt.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onTap!();
                }
              : null,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: AppTextStyles.titleSm),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppTextStyles.mutedSm),
                    ],
                  ),
                ),
                if (showChevron) ...[
                  const SizedBox(width: 6),
                  const AppChevron(size: 18),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
