import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// Id suffix carried by the terminal point a custom finish produces in an
/// optimised route. The terminal is built as a depot-kind point so that every
/// renderer already treats it as "not a numbered stop"; this is how the few
/// places that care tell it apart from the departure it would otherwise look
/// exactly like.
const String kFinishPointIdSuffix = '_finish';

/// Where the driver's day ends.
///
/// The web console lets a dispatcher set this per driver; here there is only
/// ever one driver, so it is a single choice for the trip. Mirrors the
/// backend's `end_policy` (see backend/finish_policy.py).
enum RouteEndMode {
  /// Back to where the trip started. The historical behaviour, and default.
  depot,

  /// No return leg: the day ends wherever the last stop is.
  open,

  /// A place the driver picks, typically home.
  custom,
}

extension RouteEndModeWire on RouteEndMode {
  /// The `end_policy` value the API expects.
  String get wireValue {
    switch (this) {
      case RouteEndMode.depot:
        return 'depot';
      case RouteEndMode.open:
        return 'open';
      case RouteEndMode.custom:
        return 'custom';
    }
  }
}

/// The chosen ending, plus the place it points at when one is needed.
///
/// Deliberately *not* a [RoutePoint] in the planner's point list: everything
/// in that list is sent to the solver as a delivery to visit, and a finish
/// point is a terminal, not a stop. Keeping it separate means the request
/// builder cannot accidentally ask the driver to deliver to their own house.
class RouteFinish extends Equatable {
  final RouteEndMode mode;

  /// Only meaningful for [RouteEndMode.custom].
  final LatLng? location;

  /// What to call it in the route list, e.g. "Home".
  final String? label;

  const RouteFinish._(this.mode, this.location, this.label);

  const RouteFinish.depot() : this._(RouteEndMode.depot, null, null);
  const RouteFinish.open() : this._(RouteEndMode.open, null, null);

  const RouteFinish.at(LatLng location, {String? label})
    : this._(RouteEndMode.custom, location, label);

  /// True when the choice is complete enough to send. A `custom` finish with
  /// no place yet is treated as a round trip rather than failing the solve,
  /// matching what the backend does with an endpoint it cannot use.
  bool get isUsable => mode != RouteEndMode.custom || location != null;

  RouteEndMode get effectiveMode =>
      isUsable ? mode : RouteEndMode.depot;

  /// `driver_endpoints` payload, or null when the policy needs none.
  ///
  /// vehicle_id is always 1: this app plans for a single driver.
  Map<String, dynamic>? toEndpointJson() {
    if (effectiveMode != RouteEndMode.custom) return null;
    return {
      'vehicle_id': 1,
      if (label != null && label!.isNotEmpty) 'label': label,
      'lat': location!.latitude,
      'lon': location!.longitude,
    };
  }

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    if (location != null) 'lat': location!.latitude,
    if (location != null) 'lon': location!.longitude,
    if (label != null) 'label': label,
  };

  /// Null for anything malformed, so a corrupt draft degrades to a round trip
  /// rather than throwing.
  static RouteFinish? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final mode = RouteEndMode.values
        .where((m) => m.name == raw['mode'])
        .firstOrNull;
    if (mode == null) return null;
    if (mode != RouteEndMode.custom) {
      return mode == RouteEndMode.open
          ? const RouteFinish.open()
          : const RouteFinish.depot();
    }
    final lat = raw['lat'];
    final lon = raw['lon'];
    if (lat is! num || lon is! num) return null;
    return RouteFinish.at(
      LatLng(lat.toDouble(), lon.toDouble()),
      label: raw['label']?.toString(),
    );
  }

  @override
  List<Object?> get props => [mode, location, label];
}
