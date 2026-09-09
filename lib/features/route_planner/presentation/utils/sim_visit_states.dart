import '../../../../core/utils/marker_factory.dart';

/// Which stop is done, which is being driven to, and which are still ahead,
/// during preview playback.
///
/// Extracted from the map so it can be tested without a map. The rule it
/// encodes is small but was got wrong in a way no golden would catch: the
/// *current* stop is the first one still ahead **by index**, never "every
/// stop whose arc-length fraction equals the smallest one ahead".
///
/// Fractions tie. [PolylineUtils.stopFractions] separates stops by walking a
/// polyline, and when that polyline is too short or too coarse to tell them
/// apart — a straight-line fallback, a restored draft with clipped geometry —
/// several stops land on the same value, usually 1.0. Matching on the value
/// then marks all of them at once, so the whole round shows as "driving to
/// this one" and nothing completes until playback ends and they all flip
/// together at the depot.
List<StopVisitState?> simVisitStates({
  required List<double> fractions,
  required double progress,
  required bool finished,
  required List<bool> isStop,
}) {
  final n = isStop.length;
  final states = List<StopVisitState?>.filled(n, null);
  if (fractions.isEmpty) return states;

  // The first stop still ahead of the vehicle. One index, so one stop.
  int? nextAhead;
  if (!finished) {
    var best = double.infinity;
    for (var i = 0; i < n && i < fractions.length; i++) {
      if (!isStop[i]) continue;
      final f = fractions[i];
      if (f > progress && f < best) {
        best = f;
        nextAhead = i;
      }
    }
  }

  for (var i = 0; i < n; i++) {
    if (!isStop[i]) continue;
    final f = i < fractions.length ? fractions[i] : 1.0;
    if (finished || progress >= f) {
      states[i] = StopVisitState.visited;
    } else if (nextAhead == i) {
      states[i] = StopVisitState.visiting;
    } else {
      states[i] = StopVisitState.upcoming;
    }
  }
  return states;
}
