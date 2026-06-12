import 'package:latlong2/latlong.dart';

import '../../data/datasources/osrm_routing_datasource.dart';

/// Thin wrapper used by the cubit when it wants to refresh the
/// road geometry for an already-optimized order (e.g. user toggled
/// between car / bike modes after the fact).
class GetDirectionsUseCase {
  final OsrmRoutingDataSource _ds;
  const GetDirectionsUseCase(this._ds);

  Future<List<LatLng>> call({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
    String mode = 'driving',
  }) {
    return _ds.fetchPolyline(
      origin: origin,
      destination: destination,
      waypoints: waypoints,
      mode: mode,
    );
  }
}
