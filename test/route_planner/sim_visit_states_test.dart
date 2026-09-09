/// Preview playback: which stop is done, which is current, which are ahead.
///
/// Two regressions live here. First: every stop showed as the one being
/// driven to, and the whole round flipped to delivered at once at the depot.
/// Second, after that: the car reached stop 6 with stops 1–5 still marked as
/// not yet visited, because the map read a fraction list it should have
/// rejected while the timeline — checking the length first — quietly fell
/// back to an even split and got it right.
///
/// Which is the invariant worth holding: the map and the timeline are looking
/// at one trip and must never disagree about it.
import 'package:flutter_test/flutter_test.dart';

import 'package:laffeh/core/utils/marker_factory.dart';
import 'package:laffeh/features/route_planner/presentation/utils/sim_visit_states.dart';

/// depot, six stops, depot again — the shape of the round in the report.
const int _orderedCount = 8;
List<bool> get _roundTrip => [
  false,
  true,
  true,
  true,
  true,
  true,
  true,
]; // terminal stripped

void main() {
  group('simTargetIndex', () {
    const good = [0.0, 0.12, 0.26, 0.41, 0.55, 0.68, 0.82, 1.0];

    test('walks forward through the stops as the car goes', () {
      expect(simTargetIndex(good, _orderedCount, 0.0), 1);
      expect(simTargetIndex(good, _orderedCount, 0.20), 2);
      expect(simTargetIndex(good, _orderedCount, 0.50), 4);
      expect(simTargetIndex(good, _orderedCount, 0.70), 6);
    });

    test('never runs past the last point', () {
      expect(simTargetIndex(good, _orderedCount, 1.0), _orderedCount - 1);
      expect(simTargetIndex(good, _orderedCount, 5.0), _orderedCount - 1);
    });

    // ── The regression ──────────────────────────────────────────────────

    test('falls back to an even split when the fractions do not fit', () {
      // A fraction list of the wrong length is not a little bit wrong, it is
      // meaningless — the entries do not belong to these points. Reading it
      // anyway is what left every stop ahead of the playhead.
      const wrongLength = [0.0, 0.5, 1.0];
      expect(simTargetIndex(wrongLength, _orderedCount, 0.766), 6);
      expect(simTargetIndex(const [], _orderedCount, 0.766), 6);
    });

    test('the reported case: 77% of an eight-point round is stop 6', () {
      // 23:56 of 31:24, six stops, car between 5 and 6. Stops 1-5 done.
      final target = simTargetIndex(const [], _orderedCount, 23.93 / 31.4);
      expect(target, 6);
      final states = simVisitStates(
        fractions: const [],
        orderedCount: _orderedCount,
        progress: 23.93 / 31.4,
        finished: false,
        isStop: _roundTrip,
      );
      expect(states.sublist(1, 6), everyElement(StopVisitState.visited));
      expect(states[6], StopVisitState.visiting);
    });
  });

  group('simVisitStates', () {
    const good = [0.0, 0.12, 0.26, 0.41, 0.55, 0.68, 0.82, 1.0];

    test('stops complete one at a time as the car passes them', () {
      final early = simVisitStates(
        fractions: good,
        orderedCount: _orderedCount,
        progress: 0.05,
        finished: false,
        isStop: _roundTrip,
      );
      expect(early[1], StopVisitState.visiting);
      expect(early.sublist(2), everyElement(StopVisitState.upcoming));

      final later = simVisitStates(
        fractions: good,
        orderedCount: _orderedCount,
        progress: 0.60,
        finished: false,
        isStop: _roundTrip,
      );
      expect(later.sublist(1, 5), everyElement(StopVisitState.visited));
      expect(later[5], StopVisitState.visiting);
      expect(later[6], StopVisitState.upcoming);
    });

    test('exactly one stop is ever the current one', () {
      for (var p = 0.0; p < 1.0; p += 0.01) {
        final states = simVisitStates(
          fractions: good,
          orderedCount: _orderedCount,
          progress: p,
          finished: false,
          isStop: _roundTrip,
        );
        expect(
          states.where((s) => s == StopVisitState.visiting).length,
          lessThanOrEqualTo(1),
          reason: 'progress $p',
        );
      }
    });

    test('completion only ever moves forwards', () {
      var done = -1;
      for (var p = 0.0; p <= 1.0; p += 0.01) {
        final states = simVisitStates(
          fractions: good,
          orderedCount: _orderedCount,
          progress: p,
          finished: false,
          isStop: _roundTrip,
        );
        final count = states.where((s) => s == StopVisitState.visited).length;
        expect(count, greaterThanOrEqualTo(done), reason: 'un-completed at $p');
        done = count;
      }
    });

    test('tied fractions still mark only one stop as current', () {
      // What a degenerate polyline produces. Matching on the fraction *value*
      // marked all of them; going by index marks one.
      const tied = [0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0];
      final states = simVisitStates(
        fractions: tied,
        orderedCount: _orderedCount,
        progress: 0.3,
        finished: false,
        isStop: _roundTrip,
      );
      expect(states.where((s) => s == StopVisitState.visiting).length, 1);
    });

    test('finishing marks every stop visited and none current', () {
      final states = simVisitStates(
        fractions: good,
        orderedCount: _orderedCount,
        progress: 1.0,
        finished: true,
        isStop: _roundTrip,
      );
      expect(states.sublist(1), everyElement(StopVisitState.visited));
      expect(states, isNot(contains(StopVisitState.visiting)));
    });

    test('depots are never given a visit state', () {
      final states = simVisitStates(
        fractions: good,
        orderedCount: _orderedCount,
        progress: 0.5,
        finished: false,
        isStop: _roundTrip,
      );
      expect(states.first, isNull);
    });

    test('a deactivated point is left alone', () {
      final states = simVisitStates(
        fractions: good,
        orderedCount: _orderedCount,
        progress: 0.5,
        finished: false,
        isStop: [false, true, false, true, true, true, true],
      );
      expect(states[2], isNull);
    });
  });
}
