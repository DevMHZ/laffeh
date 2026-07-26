import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/location_tracking/domain/repositories/location_ping_repository.dart';
import '../config/supabase_config.dart';
import '../utils/debug_log.dart';
import '../utils/device_id.dart';

/// Captures the user's location once per app launch and stores it in the
/// backend (`device_locations`), keyed by a stable [DeviceId] plus the
/// signed-in user id when a session exists.
///
/// Design rules:
///   * **One row per device, not a history.** The write is an upsert on
///     `device_id`, so each launch overwrites the previous fix in place.
///   * **Exactly one write per app launch.** [ping] is called from several
///     places (planner entry, app resume) — those are *attempts*, not extra
///     samples. The first one that actually reaches the backend latches
///     [_capturedThisLaunch] and every later call this process is a no-op.
///     The row is only refreshed after the process is killed and relaunched.
///   * Best-effort — never throws, never blocks the UI. Call [ping] and forget.
///   * Never prompts for permission. The location permission is requested by
///     the first-run walkthrough; here we only read a fix when access is
///     already granted, otherwise we silently skip.
///   * Failed attempts (no permission yet, no fix) leave the latch open so a
///     later resume can still land the launch's ping, throttled by
///     [_retryInterval] so a permanently denied permission can't spin.
///   * No-op when Supabase is unconfigured.
class LocationPingService {
  LocationPingService(this._prefs, this._repo);

  final SharedPreferences _prefs;
  final LocationPingRepository _repo;

  /// Minimum gap between *failed* attempts. Successful ones are latched, so
  /// this never throttles a real capture.
  static const Duration _retryInterval = Duration(seconds: 45);
  DateTime? _lastAttemptAt;
  bool _inFlight = false;
  bool _capturedThisLaunch = false;

  /// Whether this launch's single ping has already been stored.
  bool get capturedThisLaunch => _capturedThisLaunch;

  /// Fire-and-forget: grabs a location fix (if permitted) and records it.
  /// Does nothing once this launch's ping has landed.
  Future<void> ping() async {
    if (!SupabaseConfig.isReady) return;
    if (_capturedThisLaunch) return;
    if (_inFlight) return;

    final now = DateTime.now();
    if (_lastAttemptAt != null &&
        now.difference(_lastAttemptAt!) < _retryInterval) {
      return;
    }
    _lastAttemptAt = now;

    _inFlight = true;
    try {
      final position = await _readFixIfPermitted();
      if (position == null) return;

      final deviceId = await DeviceId.getOrCreate(_prefs);
      final userId = SupabaseConfig.client.auth.currentUser?.id;

      final result = await _repo.recordPing(
        deviceId: deviceId,
        userId: userId,
        lat: position.latitude,
        lng: position.longitude,
        accuracy: position.accuracy,
      );
      // Latch only on a stored row — a network failure stays retryable.
      if (result.isSuccess) _capturedThisLaunch = true;
    } catch (e) {
      DebugLog.loc('LocationPingService.ping failed (non-fatal): $e');
    } finally {
      _inFlight = false;
    }
  }

  /// Reads a position only when location services are on AND permission is
  /// already granted. Returns null (no prompt) otherwise. Prefers a fresh fix
  /// but falls back to the OS's last-known position.
  Future<Position?> _readFixIfPermitted() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    final permission = await Geolocator.checkPermission();
    final granted =
        permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
    if (!granted) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 12),
      );
    } catch (_) {
      // Fall back to a cached fix rather than dropping the ping entirely.
      return Geolocator.getLastKnownPosition();
    }
  }
}
