import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// Normalized maneuver kinds the drive HUD knows how to render.
///
/// OSRM's free-form `type` + `modifier` pairs are folded into this closed
/// set when the route is fetched, so the presentation layer never has to
/// parse router-specific strings.
enum ManeuverKind {
  depart,
  arrive,
  turnLeft,
  turnRight,
  slightLeft,
  slightRight,
  sharpLeft,
  sharpRight,
  uTurn,
  straight,
  merge,
  keepLeft,
  keepRight,
  onRamp,
  offRamp,
  roundabout,
}

/// One turn-by-turn instruction along the optimized route.
///
/// Produced from OSRM step data (see `OsrmRoutingDataSource`), kept in
/// route order. The arc-length fraction of each maneuver along the full
/// polyline is computed separately (once per route) so live progress can
/// be turned into "turn right in 350 m" without re-scanning geometry.
class RouteManeuver extends Equatable {
  final ManeuverKind kind;
  final double latitude;
  final double longitude;

  /// Road the maneuver leads onto, when the router knows it.
  final String? roadName;

  /// Roundabout exit number (1-based); null for every other kind.
  final int? roundaboutExit;

  const RouteManeuver({
    required this.kind,
    required this.latitude,
    required this.longitude,
    this.roadName,
    this.roundaboutExit,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  @override
  List<Object?> get props => [
    kind,
    latitude,
    longitude,
    roadName,
    roundaboutExit,
  ];
}
