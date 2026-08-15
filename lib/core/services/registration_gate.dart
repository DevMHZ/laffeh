import 'package:shared_preferences/shared_preferences.dart';

import '../config/registration_config.dart';
import '../constants/app_constants.dart';

/// Tracks the trial the app grants a user who skipped sign-up, and answers the
/// one question the routing needs: may this user still go on without an
/// account?
///
/// The clock starts on the *first* skip and is stored on-device only — there is
/// no account to hang it off, which is the whole point. Signing in or finishing
/// sign-up clears it, so a user who later signs out and skips again starts a
/// fresh grace period rather than being locked out immediately.
class RegistrationGate {
  RegistrationGate(this._prefs);

  final SharedPreferences _prefs;

  /// When the user first chose to keep using the app without an account, or
  /// null while they never did (the clock has not started).
  DateTime? get skippedAt {
    final raw = _prefs.getString(AppStrings.registrationSkippedAtKey);
    return raw == null ? null : DateTime.tryParse(raw)?.toUtc();
  }

  /// Starts the clock — the first call wins, so re-visiting the welcome screen
  /// and skipping again cannot extend the trial.
  Future<void> markSkipped() async {
    if (skippedAt != null) return;
    await _prefs.setString(
      AppStrings.registrationSkippedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  /// Stops the clock. Call after a successful sign-in / sign-up.
  Future<void> clear() async {
    await _prefs.remove(AppStrings.registrationSkippedAtKey);
  }

  /// What is left of the trial, or null while the clock has not started.
  ///
  /// Clamped at both ends: a device clock that jumped forward can only ever
  /// end the trial, and one that jumped back (or was ahead when the timestamp
  /// was written) can never stretch it past [RegistrationConfig.gracePeriod].
  Duration? get remaining {
    final start = skippedAt;
    if (start == null) return null;
    final elapsed = DateTime.now().toUtc().difference(start);
    if (elapsed >= RegistrationConfig.gracePeriod) return Duration.zero;
    if (elapsed.isNegative) return RegistrationConfig.gracePeriod;
    return RegistrationConfig.gracePeriod - elapsed;
  }

  /// True once a skipped user's week is up: an account is now required to get
  /// past the welcome screen.
  bool get isRequired => remaining == Duration.zero;

  /// True while the user is inside the trial and close enough to the end that
  /// the nudge should name the deadline.
  bool get isCountingDown {
    final left = remaining;
    return left != null &&
        left > Duration.zero &&
        left <= RegistrationConfig.countdownFrom;
  }

  /// Whole days left, rounded up, so the final hours still read as "1 day"
  /// rather than "0 days".
  int get daysLeft {
    final left = remaining;
    if (left == null) return RegistrationConfig.gracePeriod.inDays;
    return (left.inMinutes / Duration.minutesPerDay).ceil();
  }
}
