// Renders the new splash + loader at several animation timestamps and
// saves them as goldens — used as a visual preview, not a regression
// gate. Run: flutter test test/splash_preview_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laffeh/core/theme/app_theme.dart';
import 'package:laffeh/core/widgets/app_button.dart';
import 'package:laffeh/core/widgets/app_loading.dart';
import 'package:laffeh/features/route_planner/presentation/pages/splash_page.dart';

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

  testWidgets('splash frames', (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const SplashPage(),
      ),
    );

    // Let the logo image decode.
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pump();

    var elapsed = 0;
    for (final ms in [400, 1000, 1600, 2300, 2800]) {
      await tester.pump(Duration(milliseconds: ms - elapsed));
      elapsed = ms;
      await expectLater(
        find.byType(SplashPage),
        matchesGoldenFile('goldens/splash_$ms.png'),
      );
    }

    // Drain the navigation timer harmlessly (state unmounted → no-op).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('loader and button frames', (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(390 * 3, 360 * 3);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppLoading(size: 64, label: 'Optimizing your laffeh...'),
                const SizedBox(height: 36),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: AppButton(label: 'Plan my route', onPressed: () {}),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/loader_button.png'),
    );
  });

  tearDownAll(() {
    // Confirm where the previews landed.
    stdout.writeln('Goldens in: ${Directory('test/goldens').absolute.path}');
  });
}
