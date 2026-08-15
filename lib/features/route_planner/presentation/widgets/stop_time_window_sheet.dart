import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/stop_time_window.dart';

/// Outcome of the arrival-time sheet: either a window the user picked, or
/// an explicit "no constraint" when they cleared it. A dismissed sheet
/// returns null and changes nothing.
class TimeWindowChoice {
  final StopTimeWindow? window;
  const TimeWindowChoice(this.window);

  bool get isCleared => window == null;
}

/// Lets the user pin the clock window they must reach a stop in.
///
/// Two taps, two native time pickers: "from" and "to". The window is a
/// range because that's what the VRP solver takes — a single instant would
/// be unsatisfiable in practice, and a range lets the optimizer keep
/// finding a shorter route inside it.
Future<TimeWindowChoice?> showStopTimeWindowSheet(
  BuildContext context, {
  required String pointLabel,
  StopTimeWindow? initial,
}) {
  return showModalBottomSheet<TimeWindowChoice>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _StopTimeWindowSheet(pointLabel: pointLabel, initial: initial),
  );
}

/// Formats minutes-since-midnight using the device's 12/24-hour setting.
String formatMinuteOfDay(BuildContext context, int minuteOfDay) {
  final t = TimeOfDay(hour: minuteOfDay ~/ 60, minute: minuteOfDay % 60);
  return t.format(context);
}

class _StopTimeWindowSheet extends StatefulWidget {
  final String pointLabel;
  final StopTimeWindow? initial;

  const _StopTimeWindowSheet({required this.pointLabel, this.initial});

  @override
  State<_StopTimeWindowSheet> createState() => _StopTimeWindowSheetState();
}

class _StopTimeWindowSheetState extends State<_StopTimeWindowSheet> {
  late TimeOfDay _from;
  late TimeOfDay _to;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _from = TimeOfDay(hour: initial.startHour, minute: initial.startMinute);
      _to = TimeOfDay(hour: initial.endHour, minute: initial.endMinute);
    } else {
      // Default to a one-hour slot starting on the next round hour — the
      // most common "I have an appointment" shape, and never in the past.
      final now = TimeOfDay.now();
      _from = TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);
      _to = TimeOfDay(hour: (now.hour + 2) % 24, minute: 0);
    }
  }

  Future<void> _pick({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _from : _to,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _from = picked;
      } else {
        _to = picked;
      }
      _error = null;
    });
  }

  void _submit() {
    final start = _from.hour * 60 + _from.minute;
    final end = _to.hour * 60 + _to.minute;
    // Equal edges leave a zero-width window nothing can satisfy. Any other
    // pair is valid — an "end" before "start" simply runs past midnight.
    if (start == end) {
      setState(() => _error = AppStrings.sameTimeError);
      return;
    }
    Navigator.pop(
      context,
      TimeWindowChoice(
        StopTimeWindow(startMinuteOfDay: start, endMinuteOfDay: end),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spansMidnight =
        (_to.hour * 60 + _to.minute) < (_from.hour * 60 + _from.minute);

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
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
                    color: AppColors.info.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Iconsax.clock, color: AppColors.info, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppStrings.arrivalTime, style: AppTextStyles.titleMd),
                      Text(
                        widget.pointLabel,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _TimeField(
                    label: AppStrings.fromTime,
                    value: _from.format(context),
                    onTap: () => _pick(isStart: true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TimeField(
                    label: AppStrings.toTime,
                    value: _to.format(context),
                    // A window running past midnight is legitimate (leaving
                    // late at night), so it's annotated rather than blocked.
                    badge: spansMidnight ? '+1' : null,
                    onTap: () => _pick(isStart: false),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Iconsax.info_circle, size: 15, color: AppColors.danger),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _error!,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text(
              AppStrings.arrivalWindowHint,
              style: AppTextStyles.mutedSm,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                if (widget.initial != null) ...[
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => Navigator.pop(
                        context,
                        const TimeWindowChoice(null),
                      ),
                      icon: Icon(
                        Iconsax.close_circle,
                        size: 18,
                        color: AppColors.danger,
                      ),
                      label: Text(
                        AppStrings.anyTime,
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _submit();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(AppStrings.save),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final String value;
  final String? badge;
  final VoidCallback onTap;

  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceAlt.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.mutedSm),
              const SizedBox(height: 3),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      value,
                      style: AppTextStyles.titleMd,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge!,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.info,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
