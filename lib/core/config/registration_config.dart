/// When creating an account stops being optional.
///
/// Sign-up is deliberately skippable so a first-time user can plan a route
/// without filling anything in — but the grace that buys is finite. A user who
/// skips gets [gracePeriod] of full access; after that the app asks for an
/// account before it opens the planner again.
class RegistrationConfig {
  RegistrationConfig._();

  /// How long the app stays usable after the user chose to skip sign-up.
  static const Duration gracePeriod = Duration(days: 7);

  /// Once the remaining trial is this short, the account nudge starts naming
  /// the deadline instead of staying a generic invitation.
  static const Duration countdownFrom = Duration(days: 3);
}
