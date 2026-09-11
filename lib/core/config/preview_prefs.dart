import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Automatic route preview is optional and never overrides Reduce Motion.
class PreviewPrefs {
  PreviewPrefs._();

  static const storageKey = 'laffeh.auto_preview';
  static final notifier = ValueNotifier<bool>(true);
  static bool get enabled => notifier.value;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      notifier.value = prefs.getBool(storageKey) ?? true;
    } catch (_) {
      // Keep the session preference if storage is unavailable.
    }
  }

  static Future<void> setEnabled(bool enabled) async {
    notifier.value = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(storageKey, enabled);
    } catch (_) {
      // The preference still applies for this session.
    }
  }
}
