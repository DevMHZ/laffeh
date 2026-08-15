import 'package:equatable/equatable.dart';

/// Relative window handed to the VRP solver: minutes counted from the
/// moment the driver leaves the depot, which is the only unit the
/// `/optimize` endpoint understands (`time_window_start` / `_end`).
class RelativeTimeWindow extends Equatable {
  final int startMinutes;
  final int endMinutes;

  const RelativeTimeWindow(this.startMinutes, this.endMinutes);

  @override
  List<Object?> get props => [startMinutes, endMinutes];
}

/// The clock time by which the driver must reach a stop.
///
/// Stored as minutes since midnight (0..1439) because that is what the
/// user actually picks — "be there between 14:00 and 15:30". The backend
/// wants minutes *relative to departure* instead, so [relativeTo] does the
/// conversion at optimize time, once the trip's departure clock is known.
class StopTimeWindow extends Equatable {
  static const int minutesPerDay = 24 * 60;

  /// Earliest acceptable arrival, minutes since midnight.
  final int startMinuteOfDay;

  /// Latest acceptable arrival, minutes since midnight. May be numerically
  /// smaller than [startMinuteOfDay] — that means the window runs past
  /// midnight (e.g. 23:00 → 01:00).
  final int endMinuteOfDay;

  const StopTimeWindow({
    required this.startMinuteOfDay,
    required this.endMinuteOfDay,
  });

  /// Minutes-since-midnight for a wall clock reading.
  static int minuteOfDay(DateTime t) => t.hour * 60 + t.minute;

  int get startHour => startMinuteOfDay ~/ 60;
  int get startMinute => startMinuteOfDay % 60;
  int get endHour => endMinuteOfDay ~/ 60;
  int get endMinute => endMinuteOfDay % 60;

  /// True when the window wraps around midnight.
  bool get spansMidnight => endMinuteOfDay < startMinuteOfDay;

  /// Convert to the solver's frame: minutes after departure.
  ///
  /// Both edges are pushed to the next day when they fall before the
  /// departure clock, so "I leave at 22:00 and must be there by 01:00"
  /// becomes `180..240` rather than a negative window.
  ///
  /// A window whose start has already passed at departure time (leaving at
  /// 08:00 into an 07:00–09:00 window) opens immediately instead of being
  /// pushed a full day out.
  RelativeTimeWindow relativeTo(int departureMinuteOfDay) {
    int end = endMinuteOfDay - departureMinuteOfDay;
    if (end < 0) end += minutesPerDay;

    int start = startMinuteOfDay - departureMinuteOfDay;
    if (start < 0) start += minutesPerDay;

    // Wrapping the start pushed it past the end → the window was already
    // open when the driver set off.
    if (start > end) start = 0;

    return RelativeTimeWindow(start, end);
  }

  /// Inverse of [relativeTo] — used to turn a computed ETA (minutes after
  /// departure) back into a wall clock reading.
  static int clockFromRelative(int departureMinuteOfDay, int relativeMinutes) {
    return (departureMinuteOfDay + relativeMinutes) % minutesPerDay;
  }

  StopTimeWindow copyWith({int? startMinuteOfDay, int? endMinuteOfDay}) {
    return StopTimeWindow(
      startMinuteOfDay: startMinuteOfDay ?? this.startMinuteOfDay,
      endMinuteOfDay: endMinuteOfDay ?? this.endMinuteOfDay,
    );
  }

  Map<String, dynamic> toJson() => {
    'start': startMinuteOfDay,
    'end': endMinuteOfDay,
  };

  /// Returns null for malformed / out-of-range payloads so a corrupt draft
  /// degrades to "no window" instead of throwing.
  static StopTimeWindow? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final start = raw['start'];
    final end = raw['end'];
    if (start is! num || end is! num) return null;
    final s = start.toInt();
    final e = end.toInt();
    if (s < 0 || s >= minutesPerDay || e < 0 || e >= minutesPerDay) return null;
    return StopTimeWindow(startMinuteOfDay: s, endMinuteOfDay: e);
  }

  @override
  List<Object?> get props => [startMinuteOfDay, endMinuteOfDay];
}
