import '../constants/app_constants.dart';

/// The legal documents published for Laffah.
///
/// The slug matches the fragment the published page routes on.
enum LegalDoc {
  privacy('privacy-policy'),
  terms('terms-of-service'),
  accountDeletion('account-deletion');

  const LegalDoc(this.slug);

  /// Fragment slug used in the page's `#<slug>/<lang>` deep link.
  final String slug;
}

/// Where the published policies live, and which version the app asks users to
/// accept.
///
/// The page selects a document + language from its URL fragment — its router
/// matches `^#([a-z-]+)/([a-z]{2})$` — so `#privacy-policy/ar` opens the Arabic
/// privacy policy directly instead of dropping the user at the top of the page.
class LegalConfig {
  LegalConfig._();

  static const String baseUrl =
      'https://www.afdal.tech/policies/laffa-app.html';

  /// Effective date of the published documents, recorded alongside a user's
  /// acceptance so a future revision can tell who accepted what. Bump this
  /// whenever the published policies change materially.
  static const String termsVersion = '2026-07-25';

  static const Set<String> _supportedLangs = {'en', 'ar', 'fr'};

  /// Deep link to [doc] in [languageCode] (defaults to the app's active
  /// language, falling back to English for anything unpublished).
  static Uri uriFor(LegalDoc doc, {String? languageCode}) {
    final code = languageCode ?? AppStrings.languageCode;
    final lang = _supportedLangs.contains(code) ? code : 'en';
    return Uri.parse('$baseUrl#${doc.slug}/$lang');
  }

  static Uri get privacyUri => uriFor(LegalDoc.privacy);
  static Uri get termsUri => uriFor(LegalDoc.terms);
  static Uri get accountDeletionUri => uriFor(LegalDoc.accountDeletion);
}
