import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Greppable debug logger used to trace the **add-point** and
/// **drive / preview** flows while chasing the differences you see
/// between the iOS Simulator and a physical phone.
///
/// Why these flows differ device-to-device:
///   * Drive mode leans on real GPS — `heading` / `speed` / `accuracy`
///     and the stream cadence are all *fabricated* on the Simulator
///     (heading is usually `-1`, speed `0`), so the heading-up camera
///     and progress behave nothing like a real handset.
///   * Adding a point reads the live camera `target` and depends on the
///     device-pixel-ratio + platform-channel timing, which also differ.
///
/// Every line is gated behind [enabled] (defaults to [kDebugMode], so it
/// never ships in release) and carries:
///   * a short platform marker (`iOS` / `Android`) — so two pasted log
///     dumps stay self-describing,
///   * a category tag (`ADD`, `NAV`, `CAM`, `SIM`, `LOC`, `MAP`),
///   * a millisecond clock — so timing-sensitive issues (the tap
///     debounce, the GPS tick rate) jump out.
///
/// Filter a single stream from the `flutter run` console, e.g.:
///   flutter run | grep '\[NAV\]'
///   flutter run | grep 🐛
class DebugLog {
  DebugLog._();

  /// Master switch — flip to `false` to silence everything at once, or
  /// force `true` if you ever want these lines in a profile/release run.
  static bool enabled = kDebugMode;

  /// Monotonic clock so every line shows `+1.234s` since app start;
  /// makes the gap between two events (e.g. a stray double-add) obvious.
  static final Stopwatch _clock = Stopwatch()..start();

  static String get _platform {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    return '?';
  }

  static String get _t =>
      '+${(_clock.elapsedMilliseconds / 1000).toStringAsFixed(3)}s';

  /// Low-level sink. Prefer the tagged helpers below.
  static void log(String tag, String message) {
    if (!enabled) return;
    // debugPrint (not print) so long lines aren't truncated by the
    // platform log and it stays visible in `flutter run` / Xcode / logcat.
    debugPrint('🐛 $_platform [$tag] $_t · $message');
  }

  /// One-time context banner — call once at startup so each log dump is
  /// stamped with which build/platform produced it.
  static void banner(String label) {
    if (!enabled) return;
    debugPrint(
      '🐛 ──────── $label · platform=$_platform · '
      'debug=$kDebugMode ────────',
    );
  }

  // ── Tagged helpers for the flows under investigation ──────────────
  static void add(String message) => log('ADD', message); // add a point
  static void nav(String message) => log('NAV', message); // live drive mode
  static void cam(String message) => log('CAM', message); // camera moves
  static void sim(String message) => log('SIM', message); // trip preview
  static void loc(String message) => log('LOC', message); // GPS fixes
  static void map(String message) => log('MAP', message); // map lifecycle
}
