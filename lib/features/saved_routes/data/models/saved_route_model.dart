import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../route_planner/domain/entities/route_metrics.dart';
import '../../../route_planner/domain/entities/route_point.dart';
import '../../domain/entities/saved_route.dart';

/// JSON wire-model for [SavedRoute].
///
/// Persisted to `shared_preferences` as a JSON string per record.
/// We hand-roll the codec (no codegen) to keep the build pipeline
/// dependency-free and the schema obvious at a glance.
class SavedRouteModel {
  final String id;
  final String name;
  final String savedAtIso;
  final String routingMode;
  final List<PointDto> orderedPoints;
  final MetricsDto metrics;
  final List<List<double>> fullPolyline; // [[lat, lon], ...]
  final List<List<double>> goPolyline;
  final List<List<double>> returnPolyline;
  final bool hasRoadGeometry;

  const SavedRouteModel({
    required this.id,
    required this.name,
    required this.savedAtIso,
    required this.routingMode,
    required this.orderedPoints,
    required this.metrics,
    required this.fullPolyline,
    required this.goPolyline,
    required this.returnPolyline,
    required this.hasRoadGeometry,
  });

  // ── Entity ↔ Model ────────────────────────────────────

  factory SavedRouteModel.fromEntity(SavedRoute r) => SavedRouteModel(
    id: r.id,
    name: r.name,
    savedAtIso: r.savedAt.toIso8601String(),
    routingMode: r.routingMode,
    orderedPoints: r.orderedPoints
        .map(PointDto.fromEntity)
        .toList(growable: false),
    metrics: MetricsDto.fromEntity(r.metrics),
    fullPolyline: r.fullPolyline.map(_encodeLatLng).toList(growable: false),
    goPolyline: r.goPolyline.map(_encodeLatLng).toList(growable: false),
    returnPolyline: r.returnPolyline.map(_encodeLatLng).toList(growable: false),
    hasRoadGeometry: r.hasRoadGeometry,
  );

  SavedRoute toEntity() => SavedRoute(
    id: id,
    name: name,
    savedAt: DateTime.tryParse(savedAtIso) ?? DateTime.now(),
    routingMode: routingMode,
    orderedPoints: orderedPoints.map((p) => p.toEntity()).toList(),
    metrics: metrics.toEntity(),
    fullPolyline: fullPolyline.map(_decodeLatLng).toList(),
    goPolyline: goPolyline.map(_decodeLatLng).toList(),
    returnPolyline: returnPolyline.map(_decodeLatLng).toList(),
    hasRoadGeometry: hasRoadGeometry,
  );

  // ── JSON ──────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'savedAt': savedAtIso,
    'routingMode': routingMode,
    'orderedPoints': orderedPoints.map((p) => p.toJson()).toList(),
    'metrics': metrics.toJson(),
    'fullPolyline': fullPolyline,
    'goPolyline': goPolyline,
    'returnPolyline': returnPolyline,
    'hasRoadGeometry': hasRoadGeometry,
  };

  factory SavedRouteModel.fromJson(Map<String, dynamic> j) => SavedRouteModel(
    id: j['id']?.toString() ?? '',
    name: j['name']?.toString() ?? AppStrings.defaultRouteName,
    savedAtIso: j['savedAt']?.toString() ?? DateTime.now().toIso8601String(),
    routingMode: j['routingMode']?.toString() ?? 'car',
    orderedPoints: (j['orderedPoints'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(PointDto.fromJson)
        .toList(),
    metrics: MetricsDto.fromJson(
      (j['metrics'] as Map<String, dynamic>?) ?? const {},
    ),
    fullPolyline: _readPath(j['fullPolyline']),
    goPolyline: _readPath(j['goPolyline']),
    returnPolyline: _readPath(j['returnPolyline']),
    hasRoadGeometry: j['hasRoadGeometry'] == true,
  );

  static List<List<double>> _readPath(dynamic raw) {
    if (raw is! List) return const [];
    final out = <List<double>>[];
    for (final item in raw) {
      if (item is List && item.length >= 2) {
        final lat = (item[0] is num) ? (item[0] as num).toDouble() : 0.0;
        final lon = (item[1] is num) ? (item[1] as num).toDouble() : 0.0;
        out.add([lat, lon]);
      }
    }
    return out;
  }

  static List<double> _encodeLatLng(LatLng p) => [p.latitude, p.longitude];
  static LatLng _decodeLatLng(List<double> p) => LatLng(p[0], p[1]);
}

// ── Internal DTOs ─────────────────────────────────────────

class PointDto {
  final String id;
  final double lat;
  final double lon;
  final String label;
  final String? address;
  final int weight;
  final String kind; // 'depot' | 'stop'
  final int? sequence;
  final bool optional;
  final bool active;

  const PointDto({
    required this.id,
    required this.lat,
    required this.lon,
    required this.label,
    required this.address,
    required this.weight,
    required this.kind,
    required this.sequence,
    this.optional = false,
    this.active = true,
  });

  factory PointDto.fromEntity(RoutePoint p) => PointDto(
    id: p.id,
    lat: p.latitude,
    lon: p.longitude,
    label: p.label,
    address: p.address,
    weight: p.weight,
    kind: p.isDepot ? 'depot' : 'stop',
    sequence: p.sequence,
    optional: p.optional,
    active: p.active,
  );

  RoutePoint toEntity() => RoutePoint(
    id: id,
    latitude: lat,
    longitude: lon,
    label: label,
    address: address,
    weight: weight,
    kind: kind == 'depot' ? RoutePointKind.depot : RoutePointKind.stop,
    sequence: sequence,
    optional: optional,
    active: active,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'lat': lat,
    'lon': lon,
    'label': label,
    'address': address,
    'weight': weight,
    'kind': kind,
    'sequence': sequence,
    'optional': optional,
    'active': active,
  };

  factory PointDto.fromJson(Map<String, dynamic> j) => PointDto(
    id: j['id']?.toString() ?? '',
    lat: (j['lat'] is num) ? (j['lat'] as num).toDouble() : 0.0,
    lon: (j['lon'] is num) ? (j['lon'] as num).toDouble() : 0.0,
    label: j['label']?.toString() ?? '',
    address: j['address']?.toString(),
    weight: (j['weight'] is num) ? (j['weight'] as num).toInt() : 0,
    kind: j['kind']?.toString() ?? 'stop',
    sequence: (j['sequence'] is num) ? (j['sequence'] as num).toInt() : null,
    // Legacy drafts/saved routes predate these flags — default sensibly.
    optional: j['optional'] == true,
    active: j['active'] == null ? true : j['active'] == true,
  );
}

class MetricsDto {
  final double? totalDistanceKm;
  final double? estimatedDurationMinutes;
  final double? savedDistanceKm;
  final double? savedDurationMinutes;
  final double? fuelLiters;
  final int? vehiclesUsed;
  final double? totalLoad;

  const MetricsDto({
    this.totalDistanceKm,
    this.estimatedDurationMinutes,
    this.savedDistanceKm,
    this.savedDurationMinutes,
    this.fuelLiters,
    this.vehiclesUsed,
    this.totalLoad,
  });

  factory MetricsDto.fromEntity(RouteMetrics m) => MetricsDto(
    totalDistanceKm: m.totalDistanceKm,
    estimatedDurationMinutes: m.estimatedDurationMinutes,
    savedDistanceKm: m.savedDistanceKm,
    savedDurationMinutes: m.savedDurationMinutes,
    fuelLiters: m.fuelLiters,
    vehiclesUsed: m.vehiclesUsed,
    totalLoad: m.totalLoad,
  );

  RouteMetrics toEntity() => RouteMetrics(
    totalDistanceKm: totalDistanceKm,
    estimatedDurationMinutes: estimatedDurationMinutes,
    savedDistanceKm: savedDistanceKm,
    savedDurationMinutes: savedDurationMinutes,
    fuelLiters: fuelLiters,
    vehiclesUsed: vehiclesUsed,
    totalLoad: totalLoad,
  );

  Map<String, dynamic> toJson() => {
    'totalDistanceKm': totalDistanceKm,
    'estimatedDurationMinutes': estimatedDurationMinutes,
    'savedDistanceKm': savedDistanceKm,
    'savedDurationMinutes': savedDurationMinutes,
    'fuelLiters': fuelLiters,
    'vehiclesUsed': vehiclesUsed,
    'totalLoad': totalLoad,
  };

  factory MetricsDto.fromJson(Map<String, dynamic> j) {
    double? rd(String k) => (j[k] is num) ? (j[k] as num).toDouble() : null;
    int? ri(String k) => (j[k] is num) ? (j[k] as num).toInt() : null;
    return MetricsDto(
      totalDistanceKm: rd('totalDistanceKm'),
      estimatedDurationMinutes: rd('estimatedDurationMinutes'),
      savedDistanceKm: rd('savedDistanceKm'),
      savedDurationMinutes: rd('savedDurationMinutes'),
      fuelLiters: rd('fuelLiters'),
      vehiclesUsed: ri('vehiclesUsed'),
      totalLoad: rd('totalLoad'),
    );
  }
}
