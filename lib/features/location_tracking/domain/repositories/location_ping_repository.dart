import '../../../../core/network/api_result.dart';

/// Stores a device's last known location, overwriting the previous one.
///
/// Best-effort: callers treat failures as non-fatal (see
/// `LocationPingService`). Implementations must never throw.
abstract class LocationPingRepository {
  Future<ApiResult<void>> recordPing({
    required String deviceId,
    String? userId,
    required double lat,
    required double lng,
    double? accuracy,
  });
}
