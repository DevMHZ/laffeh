// Visual previews of the optimization-overlay animations.
// Run: flutter test test/fun_animations_preview_test.dart --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laffeh/core/theme/app_colors.dart';
import 'package:laffeh/core/theme/app_theme.dart';
import 'package:laffeh/core/widgets/fun_loading_animations.dart';

Future<void> _loadFonts() async {
  final loader = FontLoader('Almarai')
    ..addFont(rootBundle.load('assets/fonts/Almarai-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Almarai-Bold.ttf'));
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('optimization animation variants', (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(340 * 3, 860 * 3);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Scaffold(
          backgroundColor: AppColors.asphalt,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var v = 0; v < FunOptimizationAnimation.variantCount; v++)
                  Container(
                    width: 200,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: FunOptimizationAnimation(variant: v, size: 120),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    // Mid-animation moment so every variant shows its character.
    await tester.pump(const Duration(milliseconds: 2150));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/fun_animations.png'),
    );
  });
}
