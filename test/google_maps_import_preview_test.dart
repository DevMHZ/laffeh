// Visual preview of the "add a stop from Google Maps" demo, beat by beat —
// the animation behind the Google Maps chip.
// Run: flutter test test/google_maps_import_preview_test.dart --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/core/theme/app_colors.dart';
import 'package:laffeh/core/theme/app_theme.dart';
import 'package:laffeh/features/onboarding/presentation/widgets/onboarding_mock.dart';

Future<void> _loadFonts() async {
  final loader = FontLoader('Almarai')
    ..addFont(rootBundle.load('assets/fonts/Almarai-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Almarai-Bold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Almarai-ExtraBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Almarai-Light.ttf'));
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(_loadFonts);
  tearDown(() => AppStrings.setLocale(const Locale('en')));

  /// The three beats of the 6.6s loop, at the moment each reads clearest:
  /// the place open in Google Maps with Share being tapped, Laffah waiting
  /// in the share sheet, and the stop landing on the route.
  const beats = <String, int>{
    'share_tap': 2000,
    'share_sheet': 3600,
    'landed': 5400,
  };

  for (final beat in beats.entries) {
    testWidgets('google maps import — ${beat.key}', (tester) async {
      AppStrings.setLocale(const Locale('ar'));
      tester.view.physicalSize = const Size(300 * 3, 460 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const SizedBox.shrink());

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.data,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              backgroundColor: AppColors.background,
              body: const Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: OnbPhoneFrame(child: OnbGoogleMapsDemo()),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(Duration(milliseconds: beat.value));
      await tester.pump();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/gmaps_import_${beat.key}.png'),
      );
    });
  }
}
