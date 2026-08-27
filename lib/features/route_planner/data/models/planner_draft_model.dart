import '../../../saved_routes/data/models/saved_route_model.dart';
import '../../../saved_routes/domain/entities/saved_route.dart';
import '../../domain/entities/optimized_route.dart';
import '../../domain/entities/route_point.dart';

/// Local snapshot of the in-progress planner so the user never loses
/// work — points, their names, their active/deactivated/optional state,
/// and any already-computed optimized route survive an app close, a
/// crash, or coming back the next day. Mirrors the Google-Forms style
/// "your draft is saved" behaviour requested for offline use.
class PlannerDraftModel {
  /// The editable working list (depot first). May differ from
  /// [optimized] while the user is still adding / tweaking points.
  final List<PointDto> points;

  /// Snapshot of the last successful optimization, or null if the user
  /// hasn't optimized yet (or invalidated it by editing).
  final SavedRouteModel? optimized;

  /// Which leg the map was showing: 'full' | 'go' | 'returnLeg'.
  final String displaySegment;

  /// The trip's planned departure, or null for "leaving now". Kept because
  /// it's the anchor every stop's time window is measured from — restoring
  /// the windows without it would shift the whole plan.
  final DateTime? departureAt;

  final String updatedAtIso;

  const PlannerDraftModel({
    required this.points,
    required this.optimized,
    required this.displaySegment,
    required this.updatedAtIso,
    this.departureAt,
  });

  bool get isEmpty => points.isEmpty;

  Map<String, dynamic> toJson() => {
    'points': points.map((p) => p.toJson()).toList(),
    'optimized': optimized?.toJson(),
    'displaySegment': displaySegment,
    'departureAt': departureAt?.toIso8601String(),
    'updatedAt': updatedAtIso,
  };

  factory PlannerDraftModel.fromJson(Map<String, dynamic> j) {
    final rawOptimized = j['optimized'];
    return PlannerDraftModel(
      points: (j['points'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(PointDto.fromJson)
          .toList(),
      optimized: rawOptimized is Map<String, dynamic>
          ? SavedRouteModel.fromJson(rawOptimized)
          : null,
      displaySegment: j['displaySegment']?.toString() ?? 'full',
      departureAt: DateTime.tryParse(j['departureAt']?.toString() ?? ''),
      updatedAtIso:
          j['updatedAt']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  // ── Entity bridges ────────────────────────────────────────────────

  /// Build a draft from live planner values. [optimizedRoute] is wrapped
  /// in a [SavedRouteModel] purely to reuse its polyline/metrics codec.
  factory PlannerDraftModel.fromState({
    required List<RoutePoint> points,
    required OptimizedRoute? optimizedRoute,
    required String displaySegment,
    required String routingMode,
    DateTime? departureAt,
  }) {
    SavedRouteModel? optimized;
    if (optimizedRoute != null) {
      optimized = SavedRouteModel.fromEntity(
        SavedRoute(
          id: 'draft',
          name: 'draft',
          savedAt: DateTime.now(),
          routingMode: routingMode,
          orderedPoints: optimizedRoute.orderedPoints,
          metrics: optimizedRoute.metrics,
          fullPolyline: optimizedRoute.fullPolyline,
          goPolyline: optimizedRoute.goPolyline,
          returnPolyline: optimizedRoute.returnPolyline,
          hasRoadGeometry: optimizedRoute.hasRoadGeometry,
          maneuvers: optimizedRoute.maneuvers,
        ),
      );
    }
    return PlannerDraftModel(
      points: points.map(PointDto.fromEntity).toList(),
      optimized: optimized,
      displaySegment: displaySegment,
      departureAt: departureAt,
      updatedAtIso: DateTime.now().toIso8601String(),
    );
  }

  List<RoutePoint> toPoints() => points.map((p) => p.toEntity()).toList();

  OptimizedRoute? toOptimizedRoute() =>
      optimized?.toEntity().toOptimizedRoute();
}
