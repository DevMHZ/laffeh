import '../../../../core/utils/marker_factory.dart';

/// Which stop the vehicle is heading to during preview playback, as an index
/// into `orderedPoints`.
///
/// Arc-length fractions are the good answer: they put a stop's completion at
/// the instant the car actually passes it, rather than at an even split of the
/// clock. But they are only usable when there is exactly one per ordered
/// point. A route restored from a draft, re-solved into a different shape, or
/// drawn on a straight-line fallback can arrive with a fraction list that does
/// not match, and reading it anyway produces nonsense — every stop pushed past
/// the playhead, so none of them ever completes and the whole round flips at
/// the depot.
///
/// So the length is checked, and an even split stands in when it fails. The
/// preview timeline has always done this; the map did not, which is why the
/// two disagreed about the same trip.
int simTargetIndex(List<double> fractions, int orderedCount, double progress) {
  if (orderedCount < 2) return 0;
  if (fractions.length == orderedCount) {
    for (var i = 1; i < orderedCount; i++) {
      if (fractions[i] > progress) return i;
    }
    return orderedCount - 1;
  }
  final segments = orderedCount - 1;
  return ((progress * segments).floor() + 1).clamp(1, orderedCount - 1);
}

/// Which stops are done, which one is being driven to, and which are still
/// ahead — keyed off [simTargetIndex] so the map and the timeline cannot
/// disagree about the same moment of the same trip.
///
/// [isStop] marks which entries are real stops; depots and deactivated points
/// get no state and are drawn as themselves.
List<StopVisitState?> simVisitStates({
  required List<double> fractions,
  required int orderedCount,
  required double progress,
  required bool finished,
  required List<bool> isStop,
}) {
  final states = List<StopVisitState?>.filled(isStop.length, null);
  final target = simTargetIndex(fractions, orderedCount, progress);

  for (var i = 0; i < isStop.length; i++) {
    if (!isStop[i]) continue;
    if (finished || i < target) {
      states[i] = StopVisitState.visited;
    } else if (i == target) {
      states[i] = StopVisitState.visiting;
    } else {
      states[i] = StopVisitState.upcoming;
    }
  }
  return states;
}
