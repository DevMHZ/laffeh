import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'vehicle_kind.dart';

/// Persists + broadcasts the selected playback/drive vehicle icon. Mirrors
/// [AppTheme]'s palette persistence pattern (see `app_theme.dart`).
class VehiclePrefs {
  VehiclePrefs._();

  static const String _prefsKey = 'laffeh.vehicle';

  static final ValueNotifier<VehicleKind> notifier = ValueNotifier<VehicleKind>(
    VehicleKind.vwBus,
  );

  static VehicleKind get current => notifier.value;

  /// Loads the persisted vehicle (if any) before first paint.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_prefsKey);
      if (id != null) notifier.value = VehicleKind.byId(id);
    } catch (_) {
      // Keep the default vehicle on any storage error.
    }
  }

  /// Switches the active vehicle live and persists the choice.
  static Future<void> setVehicle(VehicleKind kind) async {
    if (kind == notifier.value) return;
    notifier.value = kind;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, kind.id);
    } catch (_) {
      // Non-fatal: the vehicle still applies for this session.
    }
  }
}
