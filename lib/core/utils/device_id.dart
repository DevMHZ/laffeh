import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';

/// A stable, anonymous per-install identifier.
///
/// Used to attach location pings to a device even when the user has not
/// signed in (the login flow is optional). Generated once on first access
/// and persisted; it is a random UUID with no personal information.
class DeviceId {
  DeviceId._();

  static String? _cached;

  /// Returns the persisted device id, creating and storing one on first call.
  static Future<String> getOrCreate(SharedPreferences prefs) async {
    if (_cached != null) return _cached!;

    final existing = prefs.getString(AppStrings.deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      _cached = existing;
      return existing;
    }

    final fresh = const Uuid().v4();
    await prefs.setString(AppStrings.deviceIdKey, fresh);
    _cached = fresh;
    return fresh;
  }
}
