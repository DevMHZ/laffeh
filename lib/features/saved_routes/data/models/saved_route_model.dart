import 'package:google_maps_flutter/google_maps_flutter.dart';

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
  final List<_PointDto> orderedPoints;
  final _MetricsDto metrics;
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
        orderedPoints:
            r.orderedPoints.map(_PointDto.fromEntity).toList(growable: false),
        metrics: _MetricsDto.fromEntity(r.metrics),
        fullPolyline: r.fullPolyline.map(_encodeLatLng).toList(growable: false),
        goPolyline: r.goPolyline.map(_encodeLatLng).toList(growable: false),
        returnPolyline:
            r.returnPolyline.map(_encodeLatLng).toList(growable: false),
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
        name: j['name']?.toString() ?? 'مسار',
        savedAtIso: j['savedAt']?.toString() ?? DateTime.now().toIso8601String(),
        routingMode: j['routingMode']?.toString() ?? 'car',
        orderedPoints: (j['orderedPoints'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(_PointDto.fromJson)
            .toList(),
        metrics: _MetricsDto.fromJson(
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

class _PointDto {
  final String id;
  final double lat;
  final double lon;
  final String label;
  final String? address;
  final int weight;
  final String kind; // 'depot' | 'stop'
  final int? sequence;

  const _PointDto({
    required this.id,
    required this.lat,
    required this.lon,
    required this.label,
    required this.address,
    required this.weight,
    required this.kind,
    required this.sequence,
  });

  factory _PointDto.fromEntity(RoutePoint p) => _PointDto(
        id: p.id,
        lat: p.latitude,
        lon: p.longitude,
        label: p.label,
        address: p.address,
        weight: p.weight,
        kind: p.isDepot ? 'depot' : 'stop',
        sequence: p.sequence,
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
      };

  factory _PointDto.fromJson(Map<String, dynamic> j) => _PointDto(
        id: j['id']?.toString() ?? '',
        lat: (j['lat'] is num) ? (j['lat'] as num).toDouble() : 0.0,
        lon: (j['lon'] is num) ? (j['lon'] as num).toDouble() : 0.0,
        label: j['label']?.toString() ?? '',
        address: j['address']?.toString(),
        weight: (j['weight'] is num) ? (j['weight'] as num).toInt() : 0,
        kind: j['kind']?.toString() ?? 'stop',
        sequence: (j['sequence'] is num) ? (j['sequence'] as num).toInt() : null,
      );
}

class _MetricsDto {
  final double? totalDistanceKm;
  final double? estimatedDurationMinutes;
  final double? savedDistanceKm;
  final double? savedDurationMinutes;
  final double? fuelLiters;
  final int? vehiclesUsed;
  final double? totalLoad;

  const _MetricsDto({
    this.totalDistanceKm,
    this.estimatedDurationMinutes,
    this.savedDistanceKm,
    this.savedDurationMinutes,
    this.fuelLiters,
    this.vehiclesUsed,
    this.totalLoad,
  });

  factory _MetricsDto.fromEntity(RouteMetrics m) => _MetricsDto(
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

  factory _MetricsDto.fromJson(Map<String, dynamic> j) {
    double? rd(String k) => (j[k] is num) ? (j[k] as num).toDouble() : null;
    int? ri(String k) => (j[k] is num) ? (j[k] as num).toInt() : null;
    return _MetricsDto(
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
