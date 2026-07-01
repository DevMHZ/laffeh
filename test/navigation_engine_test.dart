import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:laffeh/core/utils/polyline_utils.dart';
import 'package:laffeh/features/route_planner/domain/entities/optimized_route.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_maneuver.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_metrics.dart';
import 'package:laffeh/features/route_planner/domain/entities/route_point.dart';
import 'package:laffeh/features/route_planner/presentation/cubit/route_planner_state.dart';
import 'package:laffeh/features/route_planner/presentation/utils/navigation_instructions.dart';
import 'package:laffeh/features/saved_routes/data/models/saved_route_model.dart';

void main() {
  // A straight ~4.4 km north-bound polyline (each 0.01° lat ≈ 1.11 km).
  final path = [for (var i = 0; i <= 4; i++) LatLng(24.70 + i * 0.01, 46.60)];

  group('PolylineUtils.orderedFractionsAlong', () {
    test('returns monotonic fractions matching vertex positions', () {
      final targets = [
        const LatLng(24.71, 46.60), // vertex 1 → 0.25
        const LatLng(24.72, 46.60), // vertex 2 → 0.50
        const LatLng(24.74, 46.60), // vertex 4 → 1.00
      ];
      final fracs = PolylineUtils.orderedFractionsAlong(path, targets);
      expect(fracs, hasLength(3));
      expect(fracs[0], closeTo(0.25, 0.01));
      expect(fracs[1], closeTo(0.50, 0.01));
      expect(fracs[2], closeTo(1.00, 0.01));
      // Monotonic by construction.
      expect(fracs[0] <= fracs[1] && fracs[1] <= fracs[2], isTrue);
    });

    test('handles degenerate inputs', () {
      expect(PolylineUtils.orderedFractionsAlong(path, []), isEmpty);
      expect(
        PolylineUtils.orderedFractionsAlong(
          [path.first],
          [const LatLng(24.71, 46.60)],
        ),
        [0.0],
      );
    });
  });

  group('ManeuverDto codec', () {
    test('round-trips a maneuver through JSON', () {
      const m = RouteManeuver(
        kind: ManeuverKind.roundabout,
        latitude: 24.71,
        longitude: 46.61,
        roadName: 'King Fahd Rd',
        roundaboutExit: 2,
      );
      final back = ManeuverDto.fromJson(
        ManeuverDto.fromEntity(m).toJson(),
      ).toEntity();
      expect(back, m);
    });

    test('legacy saved-route JSON (no maneuvers key) decodes to empty', () {
      final model = SavedRouteModel.fromJson({
        'id': 'r1',
        'name': 'legacy',
        'orderedPoints': <dynamic>[],
        'fullPolyline': <dynamic>[],
        'goPolyline': <dynamic>[],
        'returnPolyline': <dynamic>[],
        'hasRoadGeometry': true,
      });
      expect(model.maneuvers, isEmpty);
      expect(model.toEntity().toOptimizedRoute().maneuvers, isEmpty);
    });
  });

  group('NavigationInstructions.compute', () {
    OptimizedRoute routeWith(List<RouteManeuver> maneuvers) => OptimizedRoute(
      orderedPoints: [
        const RoutePoint(
          id: 'd',
          latitude: 24.70,
          longitude: 46.60,
          label: 'Departure',
          weight: 0,
          kind: RoutePointKind.depot,
        ),
        const RoutePoint(
          id: 's1',
          latitude: 24.74,
          longitude: 46.60,
          label: 'Stop 1',
          weight: 0,
          kind: RoutePointKind.stop,
        ),
      ],
      fullPolyline: path,
      goPolyline: path,
      returnPolyline: const [],
      metrics: const RouteMetrics(totalDistanceKm: 4.4),
      hasRoadGeometry: true,
      maneuvers: maneuvers,
    );

    test('picks the first maneuver ahead and counts distance down', () {
      const turn = RouteManeuver(
        kind: ManeuverKind.turnRight,
        latitude: 24.72, // halfway → fraction 0.5
        longitude: 46.60,
        roadName: 'Olaya St',
      );
      final route = routeWith(const [turn]);
      final state = RoutePlannerState(
        optimizedRoute: route,
        navigationActive: true,
        navigationProgress: 0.25,
        maneuverFractions: PolylineUtils.orderedFractionsAlong(path, [
          turn.latLng,
        ]),
        stopFractions: const [0.0, 1.0],
      );

      final i1 = NavigationInstructions.compute(state)!;
      expect(i1.roadName, 'Olaya St');
      expect(i1.maneuverFraction, isNotNull);
      // ~25% of ~4.44 km ≈ 1.1 km to the turn.
      expect(i1.distanceMeters, closeTo(1110, 60));

      // Closer now — the distance keeps counting down.
      final i2 = NavigationInstructions.compute(
        state.copyWith(navigationProgress: 0.45),
      )!;
      expect(i2.distanceMeters, lessThan(i1.distanceMeters));

      // Past the turn — falls back to guiding toward the stop.
      final i3 = NavigationInstructions.compute(
        state.copyWith(navigationProgress: 0.6),
      )!;
      expect(i3.maneuverFraction, isNull);
      expect(i3.text, contains('Stop 1'));
    });

    test('falls back to continue-toward-stop when no maneuvers exist', () {
      final state = RoutePlannerState(
        optimizedRoute: routeWith(const []),
        navigationActive: true,
        navigationProgress: 0.5,
        navigationStopIndex: 1,
        stopFractions: const [0.0, 1.0],
      );
      final i = NavigationInstructions.compute(state)!;
      expect(i.maneuverFraction, isNull);
      expect(i.text, contains('Stop 1'));
      // Half the ~4.44 km route remains.
      expect(i.distanceMeters, closeTo(2220, 120));
    });

    test('returns null when navigation is inactive', () {
      final state = RoutePlannerState(optimizedRoute: routeWith(const []));
      expect(NavigationInstructions.compute(state), isNull);
    });
  });
}
