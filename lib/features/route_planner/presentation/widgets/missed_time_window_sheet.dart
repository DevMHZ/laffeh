import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
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
Future<void> showMissedTimeWindowSheet(BuildContext context) {
  final cubit = context.read<RoutePlannerCubit>();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: const _MissedTimeWindowSheet(),
    ),
  );
}

/// Shown after an optimization that couldn't honour every arrival time.
///
/// Names each late stop *with how late it is*, then hands off to
/// [showMissedTimeWindowSheet] for the fixes. A colour alone tells the user
/// something is wrong without telling them how bad it is or what to do, so
/// the banner leads with the number and ends in a call to action.
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
    return Material(
      color: AppColors.danger.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.26)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Iconsax.warning_2, color: AppColors.danger, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppStrings.timeWindowMissedCount(points.length),
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Per stop: the name and the size of the overshoot, so the
              // banner alone answers "which one, and by how much".
              for (final p in points.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.label,
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (p.latenessMinutes != null)
                        Text(
                          AppStrings.lateByMinutes(p.latenessMinutes!),
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              if (points.length > 3)
                Text(
                  AppStrings.pointsCount(points.length - 3),
                  style: AppTextStyles.mutedSm,
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Iconsax.magic_star,
                    size: 14,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    AppStrings.seeDetails,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
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
                    child: Text(
                      AppStrings.timeWindowMissedCount(late.length),
                      style: AppTextStyles.titleMd,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Per-stop breakdown: wanted vs. actual, and the gap ──
              for (final p in late) ...[
                _LateStopCard(point: p, departureMinute: departureMinute),
                const SizedBox(height: 8),
              ],

              const SizedBox(height: 8),
              Text(AppStrings.howToFixIt, style: AppTextStyles.titleMd),
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
                trailing: late.length == 1 ? null : Icons.arrow_forward_rounded,
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
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    AppStrings.keepAsIs,
                    style: TextStyle(color: AppColors.textSecondary),
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

/// One stop's story: what you asked for, what you'd actually get, and the
/// gap between them.
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
        color: AppColors.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.22)),
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
              if (point.latenessMinutes != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    AppStrings.lateByMinutes(point.latenessMinutes!),
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // The window the user entered, in full — the deadline alone hides
          // half of what they asked for.
          if (window != null)
            _ComparisonLine(
              icon: Iconsax.tick_circle,
              label: AppStrings.youWantedToArrive,
              value: AppStrings.arrivalWindowRange(
                formatMinuteOfDay(context, window.startMinuteOfDay),
                formatMinuteOfDay(context, window.endMinuteOfDay),
              ),
              color: AppColors.textPrimary,
            ),
          if (eta != null) ...[
            const SizedBox(height: 3),
            _ComparisonLine(
              icon: Iconsax.car,
              label: AppStrings.youWouldArrive,
              value: formatMinuteOfDay(
                context,
                StopTimeWindow.clockFromRelative(departureMinute, eta),
              ),
              color: AppColors.danger,
            ),
          ],
        ],
      ),
    );
  }
}

class _ComparisonLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ComparisonLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodySm.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.titleSm.copyWith(color: color),
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
  final IconData? trailing;
  final VoidCallback? onTap;

  const _FixOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
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
                if (trailing != null) ...[
                  const SizedBox(width: 6),
                  Icon(trailing, size: 16, color: AppColors.textMuted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
