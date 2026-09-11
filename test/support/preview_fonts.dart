import 'package:flutter/services.dart';

/// Widget tests do not load package icon fonts automatically. Load the same
/// glyphs the app uses so a missing icon cannot pass review as a square.
Future<void> loadPreviewIconFonts() async {
  final material = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  final iconsax = FontLoader('packages/iconsax/iconsax')
    ..addFont(rootBundle.load('packages/iconsax/lib/assets/fonts/iconsax.ttf'));
  await Future.wait([material.load(), iconsax.load()]);
}
