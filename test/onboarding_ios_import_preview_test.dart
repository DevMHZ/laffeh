// Visual preview of the iPhone WhatsApp-import walkthrough, beat by beat.
// The Android flow shares straight into Laffeh; iOS goes out through a map
// app, so the slide has four screens to show instead of two.
// Run: flutter test test/onboarding_ios_import_preview_test.dart --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/core/theme/app_colors.dart';
import 'package:laffeh/core/theme/app_text_styles.dart';
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

  /// The four beats of the 8.6s loop, at the moment each one reads clearest.
  const beats = <String, int>{
    'wa_tap': 1750,
    'maps_share': 3800,
    'share_sheet': 5500,
    'landed': 7950,
  };

  // The page itself picks the iOS variant from `Platform`, which is false on
  // a macOS test host — so the slide is composed here from the same public
  // pieces rather than driven through OnboardingPage.
  testWidgets('ios import — the slide as an iPhone driver reads it, ar', (
    tester,
  ) async {
    AppStrings.setLocale(const Locale('ar'));
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
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
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: OnbPhoneFrame(child: OnbWhatsappDemoIos()),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppStrings.onbImportTitleIos,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h2,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppStrings.onbImportBodyIos,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (final (i, step) in [
                      AppStrings.onbImportIosStep1,
                      AppStrings.onbImportIosStep2,
                      AppStrings.onbImportIosStep3,
                    ].indexed) ...[
                      if (i > 0) const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${i + 1}',
                              style: AppTextStyles.mutedSm.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              step,
                              style: AppTextStyles.bodySm.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 5500));
    await tester.pump();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/onb_ios_import_slide_ar.png'),
    );
  });

  for (final entry in beats.entries) {
    testWidgets('ios import — ${entry.key}', (tester) async {
      tester.view.physicalSize = const Size(430 * 3, 880 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const SizedBox.shrink());

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.data,
          home: const Scaffold(
            body: Center(child: OnbPhoneFrame(child: OnbWhatsappDemoIos())),
          ),
        ),
      );
      // Step to the beat, then one more frame so the capture is stable.
      await tester.pump(Duration(milliseconds: entry.value));
      await tester.pump();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/onb_ios_import_${entry.key}.png'),
      );
    });
  }
}
