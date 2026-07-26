import '../../../../core/error/failures.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/utils/debug_log.dart';
import '../../domain/repositories/location_ping_repository.dart';
import '../datasources/location_ping_remote_datasource.dart';

class LocationPingRepositoryImpl implements LocationPingRepository {
  LocationPingRepositoryImpl(this._remote);

  final LocationPingRemoteDataSource _remote;

  @override
  Future<ApiResult<void>> recordPing({
    required String deviceId,
    String? userId,
    required double lat,
    required double lng,
    double? accuracy,
  }) async {
    try {
      await _remote.insert(
        deviceId: deviceId,
        userId: userId,
        lat: lat,
        lng: lng,
        accuracy: accuracy,
      );
      DebugLog.loc(
        'ping stored ($deviceId${userId != null ? ', user' : ''}) '
        '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}',
      );
      return const ApiSuccess<void>(null);
    } catch (e) {
      DebugLog.loc('ping failed (non-fatal): $e');
      return ApiFailure<void>(ServerFailure('LOCATION_PING_FAILED: $e'));
    }
  }
}
