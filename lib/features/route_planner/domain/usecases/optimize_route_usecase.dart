import '../../../../core/config/routing_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/api_result.dart';
import '../entities/optimized_route.dart';
import '../entities/route_point.dart';
import '../repositories/route_repository.dart';

class OptimizeRouteUseCase {
  final RouteRepository _repository;
  const OptimizeRouteUseCase(this._repository);

  Future<ApiResult<OptimizedRoute>> call({
    required List<RoutePoint> points,
    String routingMode = RoutingConfig.defaultRoutingMode,
  }) async {
    if (points.length < 2) {
      return ApiFailure(ValidationFailure(AppStrings.errMinTwoPoints));
    }
    final depotCount = points.where((p) => p.isDepot).length;
    if (depotCount != 1) {
      return ApiFailure(ValidationFailure(AppStrings.errOneDepotRequired));
    }
    return _repository.optimize(points: points, routingMode: routingMode);
  }
}
