import '../../../../core/config/app_config.dart';
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
    String routingMode = AppConfig.defaultRoutingMode,
  }) async {
    if (points.length < 2) {
      return ApiFailure(
        ValidationFailure('يرجى اختيار نقطتين على الأقل'),
      );
    }
    final depotCount = points.where((p) => p.isDepot).length;
    if (depotCount != 1) {
      return ApiFailure(
        ValidationFailure('يجب تحديد نقطة انطلاق واحدة فقط'),
      );
    }
    return _repository.optimize(points: points, routingMode: routingMode);
  }
}
