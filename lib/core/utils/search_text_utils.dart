/// Text folding for search matching.
///
/// Arabic is written a dozen ways for the same word. A driver types
/// "صيدليه" for صيدلية, "الشام" with or without the article, "المزه" for
/// المزّة, and OSM holds whichever spelling the mapper used that day. None
/// of those differences mean anything to the person searching, so none of
/// them should count against a match. Everything here folds the *noise* out
/// of a string and leaves the word.
class SearchTextUtils {
  SearchTextUtils._();

  /// Tashkeel (harakat) and the superscript alef — decoration, never
  /// typed into a search box, occasionally present in map data.
  static final RegExp _diacritics = RegExp(r'[ً-ْٰـ]');

  static final RegExp _punctuation = RegExp(
    r'''[.,،؛;:!؟?()\[\]{}"'’‘“”\-_/\\|]''',
  );

  static final RegExp _whitespace = RegExp(r'\s+');

  /// Arabic-Indic and Eastern Arabic-Indic digits, in order 0-9.
  static const _arabicDigits = '٠١٢٣٤٥٦٧٨٩';
  static const _persianDigits = '۰۱۲۳۴۵۶۷۸۹';

  /// Folds a string down to what it actually says: lower-cased, stripped of
  /// diacritics and punctuation, with the interchangeable Arabic letter
  /// forms collapsed onto one spelling each and digits in ASCII.
  static String fold(String input) {
    if (input.isEmpty) return '';
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final ch = String.fromCharCode(rune);
      switch (ch) {
        // Every hamza-carrying alef is the same alef to someone typing fast.
        case 'أ':
        case 'إ':
        case 'آ':
        case 'ٱ':
        case 'ٲ':
        case 'ٳ':
          buffer.write('ا');
        case 'ة':
          buffer.write('ه');
        case 'ى':
        case 'ﻯ':
          buffer.write('ي');
        case 'ئ':
          buffer.write('ي');
        case 'ؤ':
          buffer.write('و');
        case 'ء':
          break; // bare hamza carries no sound worth matching on
        default:
          var digit = _arabicDigits.indexOf(ch);
          if (digit < 0) digit = _persianDigits.indexOf(ch);
          buffer.write(digit >= 0 ? '$digit' : ch);
      }
    }

    return buffer
        .toString()
        .toLowerCase()
        .replaceAll(_diacritics, '')
        .replaceAll(_punctuation, ' ')
        .replaceAll(_whitespace, ' ')
        .trim();
  }

  /// [fold], then drop the definite article from each word. "شارع الثورة"
  /// and "شارع ثورة" are the same street; so are "Al Mazzeh" and "Mazzeh".
  /// Only used for the loosest matching tier — the article is dropped for
  /// *comparison*, never from anything shown to the driver.
  static String foldLoose(String input) {
    final folded = fold(input);
    if (folded.isEmpty) return '';
    return folded
        .split(' ')
        .map((word) {
          if (word.length > 3 && word.startsWith('ال')) {
            return word.substring(2);
          }
          if (word.length > 4 &&
              (word.startsWith('al ') || word.startsWith('el '))) {
            return word.substring(3);
          }
          return word;
        })
        .where((w) => w.isNotEmpty && w != 'al' && w != 'el')
        .join(' ');
  }

  /// Folded, non-empty words of a query.
  static List<String> tokens(String input) {
    final folded = fold(input);
    if (folded.isEmpty) return const [];
    return folded.split(' ').where((t) => t.isNotEmpty).toList();
  }

  /// Cheap edit-distance ceiling test: true when [a] and [b] are within
  /// [maxDistance] single-character edits. Used for the last-resort "they
  /// probably meant this" tier, where a full Levenshtein over every result
  /// would cost more than the match is worth.
  static bool isNearMatch(String a, String b, {int maxDistance = 1}) {
    if (a == b) return true;
    if ((a.length - b.length).abs() > maxDistance) return false;
    if (a.isEmpty || b.isEmpty) return false;

    var i = 0;
    var j = 0;
    var edits = 0;
    while (i < a.length && j < b.length) {
      if (a[i] == b[j]) {
        i++;
        j++;
        continue;
      }
      if (++edits > maxDistance) return false;
      if (a.length > b.length) {
        i++; // deletion from a
      } else if (a.length < b.length) {
        j++; // insertion into a
      } else {
        i++;
        j++; // substitution
      }
    }
    return edits + (a.length - i) + (b.length - j) <= maxDistance;
  }
}
