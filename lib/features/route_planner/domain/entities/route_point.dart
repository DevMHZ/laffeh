import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// Role of a point in the planned route.
///
/// The depot is the start/end anchor for VRP. All other points
/// are delivery / waypoint stops. Returning is conceptually the
/// same as visiting the depot at the end.
enum RoutePointKind { depot, stop }

/// Domain entity for a user-selected point on the map.
///
/// Pure Dart, no Flutter / serialization concerns — those live
/// in the data layer.
class RoutePoint extends Equatable {
  /// Stable id (we use a millisecond timestamp + index suffix).
  final String id;

  final double latitude;
  final double longitude;

  /// Optional Arabic label (`نقطة الانطلاق`, `نقطة 1`...).
  final String label;

  /// Optional human address. Set after reverse-geocoding.
  final String? address;

  /// Default payload weight for VRP, defaulted from `RoutingConfig`.
  final int weight;

  final RoutePointKind kind;

  /// Server-assigned index after optimization (null beforehand).
  final int? sequence;

  /// Whether the user flagged this as an *optional* stop — one that the
  /// optimizer may include or skip. Optional points can be toggled
  /// [active]/inactive without being deleted. Depots are never optional.
  final bool optional;

  /// Whether this point currently participates in routing / optimization.
  /// Always true for mandatory stops and the depot. An optional point that
  /// the user deactivated has `active == false`, so it stays in the list
  /// (and on the map, dimmed) but is excluded from the optimize request.
  final bool active;

  const RoutePoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.weight,
    required this.kind,
    this.address,
    this.sequence,
    this.optional = false,
    this.active = true,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  bool get isDepot => kind == RoutePointKind.depot;

  /// True when this point should be sent to the optimizer: every mandatory
  /// point, plus optional points the user left active.
  bool get isRoutable => !optional || active;

  /// True for an optional point the user has switched off.
  bool get isDeactivated => optional && !active;

  RoutePoint copyWith({
    String? id,
    double? latitude,
    double? longitude,
    String? label,
    String? address,
    int? weight,
    RoutePointKind? kind,
    int? sequence,
    bool? optional,
    bool? active,
    bool clearSequence = false,
    bool clearAddress = false,
  }) {
    return RoutePoint(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      label: label ?? this.label,
      address: clearAddress ? null : (address ?? this.address),
      weight: weight ?? this.weight,
      kind: kind ?? this.kind,
      sequence: clearSequence ? null : (sequence ?? this.sequence),
      optional: optional ?? this.optional,
      active: active ?? this.active,
    );
  }

  @override
  List<Object?> get props => [
    id,
    latitude,
    longitude,
    label,
    address,
    weight,
    kind,
    sequence,
    optional,
    active,
  ];
}
