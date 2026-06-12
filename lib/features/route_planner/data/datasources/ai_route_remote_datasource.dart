import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../models/route_request_model.dart';
import '../models/route_response_model.dart';

/// Talks to the Afdal VRP `/optimize` endpoint.
///
/// Base URL comes from `EnvConfig.aiRouteBaseUrl` (configured on the
/// shared Dio instance), so this datasource only knows the path.
class AiRouteRemoteDataSource {
  final Dio _dio;
  const AiRouteRemoteDataSource(this._dio);

  static const String _optimizePath = '/optimize';

  Future<RouteResponseModel> optimize(RouteRequestModel request) async {
    try {
      final response = await _dio.post<dynamic>(
        _optimizePath,
        data: request.toJson(),
      );

      final body = response.data;
      if (body is! Map<String, dynamic>) {
        throw InvalidResponseException(AppStrings.errInvalidResponse);
      }
      return RouteResponseModel.fromJson(body);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Exception _mapDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return NetworkException(AppStrings.errTimeout);
    }
    if (e.type == DioExceptionType.connectionError) {
      return NetworkException(AppStrings.errServerConnection);
    }

    final body = e.response?.data;
    String message = AppStrings.errRouteOptimizationFailed;
    if (body is Map && body['message'] != null) {
      message = body['message'].toString();
    } else if (body is Map && body['detail'] != null) {
      message = body['detail'].toString();
    }
    return ServerException(message, statusCode: e.response?.statusCode);
  }
}
