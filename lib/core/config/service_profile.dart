import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which way the vehicle's load moves over a round.
///
/// The solver orders stops by distance, and distance is indifferent to *when*
/// in the day a stop is served. The backend breaks that tie in the driver's
/// favour, but it can only do so if it is told which way the weight is going:
///
///   * [delivery] — the vehicle leaves full and empties. Serve early, so the
///     heaviest drops happen on the way out and the rest of the round is
///     driven light.
///   * [pickup] — the vehicle leaves empty and fills. Collect late, for the
///     same reason read from the other end.
///
/// Delivery is the default because it is what almost every round is.
enum ServiceProfile {
  delivery('delivery'),
  pickup('pickup');

  const ServiceProfile(this.wireValue);

  /// What the backend's `service_profile` field expects.
  final String wireValue;

  static ServiceProfile byId(String? id) => ServiceProfile.values.firstWhere(
    (p) => p.wireValue == id,
    orElse: () => ServiceProfile.delivery,
  );
}

/// The driver's saved choice of [ServiceProfile].
class ServiceProfilePrefs {
  ServiceProfilePrefs._();

  static const String _prefsKey = 'laffeh.serviceProfile';

  static final ValueNotifier<ServiceProfile> notifier =
      ValueNotifier<ServiceProfile>(ServiceProfile.delivery);

  static ServiceProfile get current => notifier.value;

  /// Loads the persisted profile (if any) before first paint.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_prefsKey);
      if (id != null) notifier.value = ServiceProfile.byId(id);
    } catch (_) {
      // Keep the default profile on any storage error.
    }
  }

  /// Switches the active profile and persists the choice.
  static Future<void> setProfile(ServiceProfile profile) async {
    if (profile == notifier.value) return;
    notifier.value = profile;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, profile.wireValue);
    } catch (_) {
      // Non-fatal: the profile still applies for this session.
    }
  }
}
