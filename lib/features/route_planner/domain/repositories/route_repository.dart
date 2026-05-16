import '../../../../core/network/api_result.dart';
import '../entities/optimized_route.dart';
import '../entities/route_point.dart';

/// Domain contract for everything route-related.
///
/// The implementation lives in `data/repositories/route_repository_impl.dart`
/// and is wired through GetIt in `core/di/service_locator.dart`.
abstract class RouteRepository {
  /// Optimize a set of user-picked points and (when possible) fetch
  /// driveable geometry from Google Directions for the polylines.
  ///
  /// [points] must include exactly one depot at index 0; the rest
  /// are delivery stops. The cubit guarantees this invariant.
  Future<ApiResult<OptimizedRoute>> optimize({
    required List<RoutePoint> points,
    String routingMode,
  });
}
