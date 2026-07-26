/// Support / help channel configuration.
///
/// Kept here (not hard-coded in a widget) so the contact number lives in one
/// place. "Forgot password" routes to WhatsApp support since the phone-only
/// auth has no automatic recovery channel.
class SupportConfig {
  SupportConfig._();

  /// WhatsApp number in E.164 digits (no `+`, spaces or symbols) — the form
  /// `wa.me` expects. Displayed value: +33 7 83 71 94 27.
  static const String whatsappE164 = '33783719427';

  /// Builds a `wa.me` deep link with an optional prefilled [message].
  static Uri whatsappUri({String? message}) {
    final query = (message == null || message.isEmpty)
        ? ''
        : '?text=${Uri.encodeComponent(message)}';
    return Uri.parse('https://wa.me/$whatsappE164$query');
  }
}
