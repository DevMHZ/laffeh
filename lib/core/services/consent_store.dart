import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// Local record of the user's acceptance of the published policies.
///
/// The authoritative copy lives in `profiles` (written by the onboarding RPC);
/// this on-device copy is what lets the app tell, offline, which version was
/// accepted — so a future policy revision can prompt again.
class ConsentStore {
  ConsentStore(this._prefs);

  final SharedPreferences _prefs;

  /// The policy version the user accepted, or null if they never did.
  String? get acceptedVersion => _prefs.getString(AppStrings.termsVersionKey);

  DateTime? get acceptedAt {
    final raw = _prefs.getString(AppStrings.termsAcceptedAtKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// True when the user has accepted exactly [version].
  bool hasAccepted(String version) => acceptedVersion == version;

  Future<void> record(String version) async {
    await _prefs.setString(AppStrings.termsVersionKey, version);
    await _prefs.setString(
      AppStrings.termsAcceptedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }
}
