/// Preview playback: which stop is done, which is current, which are ahead.
///
/// The regression these guard against: every stop showed as the current one
/// for the whole preview, then the entire round flipped to delivered at once
/// when the car got back to the depot.
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:laffeh/core/utils/marker_factory.dart';
import 'package:laffeh/core/utils/polyline_utils.dart';
import 'package:laffeh/features/route_planner/presentation/utils/sim_visit_states.dart';

/// depot, four stops, depot again — the shape of a round trip.
List<bool> get _roundTrip => [false, true, true, true, true, false];

void main() {
  group('simVisitStates', () {
    test('stops complete one at a time as the car passes them', () {
      const fractions = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0];

      final early = simVisitStates(
        fractions: fractions,
        progress: 0.1,
        finished: false,
        isStop: _roundTrip,
      );
      expect(early[1], StopVisitState.visiting);
      expect(early.sublist(2, 5), everyElement(StopVisitState.upcoming));

      final middle = simVisitStates(
        fractions: fractions,
        progress: 0.5,
        finished: false,
        isStop: _roundTrip,
      );
      expect(middle[1], StopVisitState.visited);
      expect(middle[2], StopVisitState.visited);
      expect(middle[3], StopVisitState.visiting);
      expect(middle[4], StopVisitState.upcoming);
    });

    test('exactly one stop is ever the current one', () {
      const fractions = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0];
      for (var p = 0.0; p < 1.0; p += 0.02) {
        final states = simVisitStates(
          fractions: fractions,
          progress: p,
          finished: false,
          isStop: _roundTrip,
        );
        final visiting =
            states.where((s) => s == StopVisitState.visiting).length;
        expect(visiting, lessThanOrEqualTo(1), reason: 'progress $p');
      }
    });

    // ── The regression ──────────────────────────────────────────────────

    test('tied fractions still mark only one stop as current', () {
      // Every stop saturated to 1.0 — what a degenerate polyline produces.
      // Matching on the fraction *value* marked all four; matching on the
      // index marks one.
      const tied = [0.0, 1.0, 1.0, 1.0, 1.0, 1.0];
      final states = simVisitStates(
        fractions: tied,
        progress: 0.3,
        finished: false,
        isStop: _roundTrip,
      );
      final visiting = states.where((s) => s == StopVisitState.visiting);
      expect(visiting.length, 1, reason: 'the whole round read as current');
      expect(states[1], StopVisitState.visiting);
      expect(states.sublist(2, 5), everyElement(StopVisitState.upcoming));
    });

    test('a short polyline really does tie the fractions', () {
      // The root cause, held down so it stays understood: two vertices are
      // not enough to separate four stops, so they all land on the end.
      final path = [const LatLng(0, 0), const LatLng(0.05, 0)];
      final stops = [
        const LatLng(0, 0),
        const LatLng(0.01, 0),
        const LatLng(0.02, 0),
        const LatLng(0.03, 0),
        const LatLng(0.04, 0),
        const LatLng(0, 0),
      ];
      final fractions = PolylineUtils.stopFractions(path, stops);
      final distinct = fractions.sublist(1, 5).toSet();
      expect(distinct.length, lessThan(4),
          reason: 'if this ever separates them the tie case is gone');

      // And with those real tied fractions, the rule still behaves.
      final states = simVisitStates(
        fractions: fractions,
        progress: 0.3,
        finished: false,
        isStop: _roundTrip,
      );
      expect(
        states.where((s) => s == StopVisitState.visiting).length,
        lessThanOrEqualTo(1),
      );
    });

    test('a well-formed polyline separates them properly', () {
      final path = [for (var i = 0; i <= 100; i++) LatLng(i * 0.0005, 0)];
      final stops = [
        const LatLng(0, 0),
        const LatLng(0.01, 0),
        const LatLng(0.02, 0),
        const LatLng(0.03, 0),
        const LatLng(0.04, 0),
        const LatLng(0.05, 0),
      ];
      final fractions = PolylineUtils.stopFractions(path, stops);
      expect(fractions.sublist(1, 5).toSet().length, 4);
    });

    // ── Edges ───────────────────────────────────────────────────────────

    test('finishing marks every stop visited and none current', () {
      final states = simVisitStates(
        fractions: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
        progress: 1.0,
        finished: true,
        isStop: _roundTrip,
      );
      expect(states[1], StopVisitState.visited);
      expect(states[4], StopVisitState.visited);
      expect(states, isNot(contains(StopVisitState.visiting)));
    });

    test('depots are never given a visit state', () {
      final states = simVisitStates(
        fractions: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
        progress: 0.5,
        finished: false,
        isStop: _roundTrip,
      );
      expect(states.first, isNull);
      expect(states.last, isNull);
    });

    test('no fractions means no playback state at all', () {
      final states = simVisitStates(
        fractions: const [],
        progress: 0.5,
        finished: false,
        isStop: _roundTrip,
      );
      expect(states, everyElement(isNull));
    });

    test('fewer fractions than points does not throw', () {
      final states = simVisitStates(
        fractions: const [0.0, 0.3],
        progress: 0.5,
        finished: false,
        isStop: _roundTrip,
      );
      expect(states.length, _roundTrip.length);
      expect(
        states.where((s) => s == StopVisitState.visiting).length,
        lessThanOrEqualTo(1),
      );
    });
  });
}
