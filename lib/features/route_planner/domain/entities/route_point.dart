import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

  /// Default payload weight for VRP. Most users won't care; we
  /// use a sane default from [AppConfig].
  final int weight;

  final RoutePointKind kind;

  /// Server-assigned index after optimization (null beforehand).
  final int? sequence;

  const RoutePoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.weight,
    required this.kind,
    this.address,
    this.sequence,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  bool get isDepot => kind == RoutePointKind.depot;

  RoutePoint copyWith({
    String? id,
    double? latitude,
    double? longitude,
    String? label,
    String? address,
    int? weight,
    RoutePointKind? kind,
    int? sequence,
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
    );
  }

  @override
  List<Object?> get props =>
      [id, latitude, longitude, label, address, weight, kind, sequence];
}
