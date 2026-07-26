/// Phone-number helpers for turning a country dial code + a locally typed
/// national number into a canonical E.164 string (e.g. `+963944123456`).
///
/// Deliberately lightweight (no `libphonenumber` dependency): it does digit
/// sanitisation, leading-zero trimming and a permissive E.164 shape check.
/// It intentionally does NOT validate national number plans per country.
class PhoneUtils {
  PhoneUtils._();

  /// Keep digits only (drops spaces, dashes, parentheses, unicode digits…).
  static String digitsOnly(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      if (RegExp(r'[0-9]').hasMatch(ch)) buffer.write(ch);
    }
    return buffer.toString();
  }

  /// Builds an E.164 number from a dial code (`+963` or `963`) and a national
  /// number as typed. Trims the trunk `0` locals often prefix. Returns `null`
  /// when there aren't enough digits to be plausibly valid.
  static String? toE164({required String dialCode, required String national}) {
    final code = digitsOnly(dialCode);
    var body = digitsOnly(national);
    if (code.isEmpty || body.isEmpty) return null;

    // Drop leading trunk zeros (e.g. 0944… → 944…).
    body = body.replaceFirst(RegExp(r'^0+'), '');
    if (body.isEmpty) return null;

    final e164 = '+$code$body';
    return isValidE164(e164) ? e164 : null;
  }

  /// Permissive E.164 check: `+` then 7–15 digits, first digit non-zero.
  static bool isValidE164(String value) {
    return RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(value);
  }
}
