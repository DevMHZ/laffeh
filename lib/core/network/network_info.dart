import 'dart:io';

/// Minimal connectivity probe used by repositories to short-circuit
/// API calls with a friendlier error when offline.
///
/// We avoid pulling in `connectivity_plus` (extra plugin permissions)
/// and instead do a cheap DNS lookup. It's good enough as a heuristic;
/// Dio's own error handling covers the real failure cases.
class NetworkInfo {
  Future<bool> get isConnected async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
