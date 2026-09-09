// Visual preview of the round-type glyphs across their travel.
// Run: flutter test test/service_profile_glyph_preview_test.dart --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laffeh/core/config/service_profile.dart';
import 'package:laffeh/core/theme/app_colors.dart';
import 'package:laffeh/features/settings/presentation/widgets/service_profile_glyph.dart';

/// One column per profile, one row per moment in the loop — so a reviewer can
/// see the parcel travelling rather than guess from a single frame.
void main() {
  testWidgets('round type glyphs', (tester) async {
    tester.view.physicalSize = const Size(420 * 3, 600 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final p in ServiceProfile.values)
                      SizedBox(
                        width: 120,
                        child: Text(
                          p.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                for (var frame = 0; frame < 6; frame++) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final p in ServiceProfile.values)
                        SizedBox(
                          width: 120,
                          child: Center(
                            child: ServiceProfileGlyph(
                              key: ValueKey('$p-$frame'),
                              profile: p,
                              size: 64,
                              color: AppColors.primary,
                              // Every cell shares one controller cadence, so
                              // without an offset all four rows would show
                              // the same instant. This walks the loop across
                              // them.
                              phaseOffset: frame / 6,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    // One pump to start the tickers; the rows differ by phaseOffset, so the
    // four of them read as a flip-book of one parcel's travel.
    await tester.pump(const Duration(milliseconds: 16));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/service_profile_glyphs.png'),
    );
  });
}
