/// Pure, localisation-friendly form validators.
///
/// Each validator returns a **message key** (a stable string mapped to copy in
/// `AppStrings`) when invalid, or `null` when valid. Keeping them pure and
/// key-based makes them trivially unit-testable and independent of any
/// `BuildContext`.
class FormValidators {
  FormValidators._();

  static const int minPasswordLength = 8;
  static const int minNameLength = 2;
  static const int maxNameLength = 120;
  static const int maxCompanyLength = 160;

  // ── Password ────────────────────────────────────────────
  /// Returns `null` when acceptable, else a key:
  /// `passwordRequired` | `passwordTooShort`.
  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'passwordRequired';
    if (v.length < minPasswordLength) return 'passwordTooShort';
    return null;
  }

  /// `null` when the two match, else `passwordMismatch`.
  static String? passwordConfirm(String? password, String? confirm) {
    if ((confirm ?? '').isEmpty) return 'passwordConfirmRequired';
    if (password != confirm) return 'passwordMismatch';
    return null;
  }

  // ── Name ────────────────────────────────────────────────
  /// `null` when valid, else `nameRequired` | `nameTooShort` |
  /// `nameTooLong` | `nameNumeric`.
  static String? fullName(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'nameRequired';
    if (v.length < minNameLength) return 'nameTooShort';
    if (v.length > maxNameLength) return 'nameTooLong';
    // Reject an all-digits "name". Allows Arabic/Latin/accented letters,
    // spaces, hyphens, apostrophes and dots used in real names.
    if (RegExp(r'^[\d\s\-.]+$').hasMatch(v)) return 'nameNumeric';
    return null;
  }

  // ── Company ─────────────────────────────────────────────
  /// `null` when valid, else `companyRequired` | `companyTooLong`.
  static String? companyName(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'companyRequired';
    if (v.length > maxCompanyLength) return 'companyTooLong';
    return null;
  }
}
