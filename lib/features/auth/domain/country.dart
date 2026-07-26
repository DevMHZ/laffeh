import 'dart:math';

import '../../../core/utils/phone_utils.dart';

/// One rule in a country's mobile numbering plan: a national number starting
/// with any of [prefixes] must be exactly [length] digits long.
class MobileRule {
  const MobileRule(this.prefixes, this.length);

  final List<String> prefixes;
  final int length;
}

/// A country choice for the phone-number field.
///
/// A curated (not exhaustive) list focused on the app's regions — MENA, the
/// Levant, the Gulf, the Maghreb, plus France and a few common others. Keeping
/// it local avoids a heavyweight i18n/phone dependency.
///
/// Each entry carries its **mobile** numbering plan ([mobile]) and a formatted
/// [example], which together drive validation, the live input mask, the digit
/// limit and the field's hint — one source of truth per country.
class Country {
  final String iso; // ISO 3166-1 alpha-2
  final String dialCode; // e.g. +963
  final String flag; // emoji
  final String nameEn;
  final String nameAr;
  final String nameFr;

  /// Accepted mobile shapes. Landlines are deliberately not accepted: the
  /// account *is* the phone number, and support reaches users on it.
  final List<MobileRule> mobile;

  /// A real-looking national number, grouped the way locals write it. Doubles
  /// as the field hint and as the input mask's grouping.
  final String example;

  const Country({
    required this.iso,
    required this.dialCode,
    required this.flag,
    required this.nameEn,
    required this.nameAr,
    required this.nameFr,
    required this.mobile,
    required this.example,
  });

  String localizedName(String languageCode) {
    switch (languageCode) {
      case 'ar':
        return nameAr;
      case 'fr':
        return nameFr;
      default:
        return nameEn;
    }
  }

  /// Matches a free-text search against name (any language), ISO or dial code.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return nameEn.toLowerCase().contains(q) ||
        nameAr.contains(query.trim()) ||
        nameFr.toLowerCase().contains(q) ||
        iso.toLowerCase().contains(q) ||
        dialCode.contains(q);
  }

  // ── Numbering plan ──────────────────────────────────────

  /// Longest national number this country accepts — the field's digit cap.
  int get maxNationalDigits =>
      mobile.map((r) => r.length).reduce((a, b) => max(a, b));

  int get _minNationalDigits =>
      mobile.map((r) => r.length).reduce((a, b) => min(a, b));

  /// Digit-group sizes taken from [example], e.g. `944 123 456` → `[3, 3, 3]`.
  List<int> get groups =>
      example.split(' ').map((g) => g.length).toList(growable: false);

  /// Validates a national number as typed (spaces and a trunk `0` are fine).
  ///
  /// Returns `null` when valid, else one of `phoneRequired`, `phoneTooShort`,
  /// `phoneTooLong`, `phoneNotMobile`. With [strict] false only the length is
  /// enforced — used on **sign-in**, where an existing account must not be
  /// locked out by a prefix our curated plan doesn't know about.
  String? validateNational(String raw, {bool strict = true}) {
    final digits = _trunkStripped(raw);
    if (digits.isEmpty) return 'phoneRequired';

    final matching = mobile
        .where((r) => r.prefixes.any(digits.startsWith))
        .toList(growable: false);

    if (matching.isEmpty) {
      if (!strict) {
        // Prefix ignored: any of the country's mobile lengths will do.
        final lengths = mobile.map((r) => r.length).toSet();
        if (lengths.contains(digits.length)) return null;
        return _lengthError(digits, _minNationalDigits);
      }
      // A prefix the user hasn't finished typing counts as short, not wrong.
      final stillPlausible = mobile.any(
        (r) => r.prefixes.any((p) => p.startsWith(digits)),
      );
      return stillPlausible ? 'phoneTooShort' : 'phoneNotMobile';
    }

    final lengths = matching.map((r) => r.length).toSet();
    if (lengths.contains(digits.length)) return null;
    return _lengthError(digits, lengths.reduce(min));
  }

  bool isValidNational(String raw, {bool strict = true}) =>
      validateNational(raw, strict: strict) == null;

  /// The E.164 form (`+963944123456`), or `null` when [raw] isn't valid.
  String? toE164(String raw, {bool strict = true}) {
    if (!isValidNational(raw, strict: strict)) return null;
    return '$dialCode${_trunkStripped(raw)}';
  }

  /// Groups [digits] the way [example] is grouped, e.g. `944123456` →
  /// `944 123 456`. Digits past the pattern are appended as a final group.
  String formatNational(String digits) {
    final out = StringBuffer();
    var i = 0;
    for (final size in groups) {
      if (i >= digits.length) break;
      if (i > 0) out.write(' ');
      out.write(digits.substring(i, min(i + size, digits.length)));
      i += size;
    }
    if (i < digits.length) out.write(' ${digits.substring(i)}');
    return out.toString();
  }

  /// Best-effort cleanup of a *pasted* number: drops an international prefix
  /// (`00963…`, `963…`) or a trunk `0` — but only when that turns an
  /// otherwise-invalid number into a valid one, so a legitimate national
  /// number that happens to start with its own dial code survives.
  String normalizeNational(String raw) {
    final digits = PhoneUtils.digitsOnly(raw);
    // Compared as typed (no trunk-zero stripping), so a leading 0 is still
    // seen as something to remove rather than as an already-valid number.
    if (digits.isEmpty || _fitsPlan(digits)) return digits;

    final code = PhoneUtils.digitsOnly(dialCode);
    for (final prefix in ['00$code', code, '0']) {
      if (!digits.startsWith(prefix)) continue;
      final stripped = digits.substring(prefix.length);
      if (_fitsPlan(stripped)) return stripped;
    }
    return _trunkStripped(digits);
  }

  /// Whether [digits] matches a rule exactly, as given.
  bool _fitsPlan(String digits) => mobile.any(
    (r) => r.length == digits.length && r.prefixes.any(digits.startsWith),
  );

  String _trunkStripped(String raw) =>
      PhoneUtils.digitsOnly(raw).replaceFirst(RegExp('^0+'), '');

  String _lengthError(String digits, int expected) =>
      digits.length < expected ? 'phoneTooShort' : 'phoneTooLong';

  static const List<Country> all = <Country>[
    Country(
      iso: 'SY',
      dialCode: '+963',
      flag: '🇸🇾',
      nameEn: 'Syria',
      nameAr: 'سوريا',
      nameFr: 'Syrie',
      mobile: [
        MobileRule(['9'], 9),
      ],
      example: '944 123 456',
    ),
    Country(
      iso: 'LB',
      dialCode: '+961',
      flag: '🇱🇧',
      nameEn: 'Lebanon',
      nameAr: 'لبنان',
      nameFr: 'Liban',
      mobile: [
        MobileRule(['3'], 7),
        MobileRule(['70', '71', '76', '78', '79', '81'], 8),
      ],
      example: '71 123 456',
    ),
    Country(
      iso: 'JO',
      dialCode: '+962',
      flag: '🇯🇴',
      nameEn: 'Jordan',
      nameAr: 'الأردن',
      nameFr: 'Jordanie',
      mobile: [
        MobileRule(['7'], 9),
      ],
      example: '79 123 4567',
    ),
    Country(
      iso: 'PS',
      dialCode: '+970',
      flag: '🇵🇸',
      nameEn: 'Palestine',
      nameAr: 'فلسطين',
      nameFr: 'Palestine',
      mobile: [
        MobileRule(['5'], 9),
      ],
      example: '59 123 4567',
    ),
    Country(
      iso: 'IQ',
      dialCode: '+964',
      flag: '🇮🇶',
      nameEn: 'Iraq',
      nameAr: 'العراق',
      nameFr: 'Irak',
      mobile: [
        MobileRule(['7'], 10),
      ],
      example: '790 123 4567',
    ),
    Country(
      iso: 'SA',
      dialCode: '+966',
      flag: '🇸🇦',
      nameEn: 'Saudi Arabia',
      nameAr: 'السعودية',
      nameFr: 'Arabie saoudite',
      mobile: [
        MobileRule(['5'], 9),
      ],
      example: '50 123 4567',
    ),
    Country(
      iso: 'AE',
      dialCode: '+971',
      flag: '🇦🇪',
      nameEn: 'United Arab Emirates',
      nameAr: 'الإمارات',
      nameFr: 'Émirats arabes unis',
      mobile: [
        MobileRule(['5'], 9),
      ],
      example: '50 123 4567',
    ),
    Country(
      iso: 'QA',
      dialCode: '+974',
      flag: '🇶🇦',
      nameEn: 'Qatar',
      nameAr: 'قطر',
      nameFr: 'Qatar',
      mobile: [
        MobileRule(['3', '5', '6', '7'], 8),
      ],
      example: '3312 3456',
    ),
    Country(
      iso: 'KW',
      dialCode: '+965',
      flag: '🇰🇼',
      nameEn: 'Kuwait',
      nameAr: 'الكويت',
      nameFr: 'Koweït',
      mobile: [
        MobileRule(['5', '6', '9'], 8),
      ],
      example: '5012 3456',
    ),
    Country(
      iso: 'BH',
      dialCode: '+973',
      flag: '🇧🇭',
      nameEn: 'Bahrain',
      nameAr: 'البحرين',
      nameFr: 'Bahreïn',
      mobile: [
        MobileRule(['3', '6'], 8),
      ],
      example: '3612 3456',
    ),
    Country(
      iso: 'OM',
      dialCode: '+968',
      flag: '🇴🇲',
      nameEn: 'Oman',
      nameAr: 'عُمان',
      nameFr: 'Oman',
      mobile: [
        MobileRule(['7', '9'], 8),
      ],
      example: '9212 3456',
    ),
    Country(
      iso: 'YE',
      dialCode: '+967',
      flag: '🇾🇪',
      nameEn: 'Yemen',
      nameAr: 'اليمن',
      nameFr: 'Yémen',
      mobile: [
        MobileRule(['7'], 9),
      ],
      example: '73 123 4567',
    ),
    Country(
      iso: 'EG',
      dialCode: '+20',
      flag: '🇪🇬',
      nameEn: 'Egypt',
      nameAr: 'مصر',
      nameFr: 'Égypte',
      mobile: [
        MobileRule(['1'], 10),
      ],
      example: '100 123 4567',
    ),
    Country(
      iso: 'DZ',
      dialCode: '+213',
      flag: '🇩🇿',
      nameEn: 'Algeria',
      nameAr: 'الجزائر',
      nameFr: 'Algérie',
      mobile: [
        MobileRule(['5', '6', '7'], 9),
      ],
      example: '551 234 567',
    ),
    Country(
      iso: 'MA',
      dialCode: '+212',
      flag: '🇲🇦',
      nameEn: 'Morocco',
      nameAr: 'المغرب',
      nameFr: 'Maroc',
      mobile: [
        MobileRule(['6', '7'], 9),
      ],
      example: '612 345 678',
    ),
    Country(
      iso: 'TN',
      dialCode: '+216',
      flag: '🇹🇳',
      nameEn: 'Tunisia',
      nameAr: 'تونس',
      nameFr: 'Tunisie',
      mobile: [
        MobileRule(['2', '4', '5', '9'], 8),
      ],
      example: '20 123 456',
    ),
    Country(
      iso: 'LY',
      dialCode: '+218',
      flag: '🇱🇾',
      nameEn: 'Libya',
      nameAr: 'ليبيا',
      nameFr: 'Libye',
      mobile: [
        MobileRule(['9'], 9),
      ],
      example: '91 234 5678',
    ),
    Country(
      iso: 'SD',
      dialCode: '+249',
      flag: '🇸🇩',
      nameEn: 'Sudan',
      nameAr: 'السودان',
      nameFr: 'Soudan',
      mobile: [
        MobileRule(['1', '9'], 9),
      ],
      example: '91 123 4567',
    ),
    Country(
      iso: 'FR',
      dialCode: '+33',
      flag: '🇫🇷',
      nameEn: 'France',
      nameAr: 'فرنسا',
      nameFr: 'France',
      mobile: [
        MobileRule(['6', '7'], 9),
      ],
      example: '6 12 34 56 78',
    ),
    Country(
      iso: 'TR',
      dialCode: '+90',
      flag: '🇹🇷',
      nameEn: 'Turkey',
      nameAr: 'تركيا',
      nameFr: 'Turquie',
      mobile: [
        MobileRule(['5'], 10),
      ],
      example: '501 234 5678',
    ),
    Country(
      iso: 'DE',
      dialCode: '+49',
      flag: '🇩🇪',
      nameEn: 'Germany',
      nameAr: 'ألمانيا',
      nameFr: 'Allemagne',
      mobile: [
        MobileRule(['15', '16', '17'], 10),
        MobileRule(['15', '16', '17'], 11),
      ],
      example: '160 1234567',
    ),
    Country(
      iso: 'GB',
      dialCode: '+44',
      flag: '🇬🇧',
      nameEn: 'United Kingdom',
      nameAr: 'المملكة المتحدة',
      nameFr: 'Royaume-Uni',
      mobile: [
        MobileRule(['7'], 10),
      ],
      example: '7400 123456',
    ),
    Country(
      iso: 'US',
      dialCode: '+1',
      flag: '🇺🇸',
      nameEn: 'United States',
      nameAr: 'الولايات المتحدة',
      nameFr: 'États-Unis',
      mobile: [
        MobileRule(['2', '3', '4', '5', '6', '7', '8', '9'], 10),
      ],
      example: '415 555 0132',
    ),
  ];

  /// Sensible default (first in the list).
  static Country get fallback => all.first;
}
