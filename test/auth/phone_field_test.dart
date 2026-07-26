import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/features/auth/domain/country.dart';
import 'package:laffeh/features/auth/presentation/widgets/phone_field.dart';

Country _c(String iso) => Country.all.firstWhere((c) => c.iso == iso);

void main() {
  setUp(() => AppStrings.setLocale(const Locale('en')));

  Future<TextEditingController> pump(
    WidgetTester tester,
    Country country, {
    ValueNotifier<String>? seen,
  }) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PhoneField(
            country: country,
            controller: controller,
            onCountryChanged: (_) {},
            onChanged: (v) => seen?.value = v,
          ),
        ),
      ),
    );
    return controller;
  }

  testWidgets('groups digits as they are typed', (tester) async {
    final controller = await pump(tester, _c('SY'));
    await tester.enterText(find.byType(TextField), '944123456');
    expect(controller.text, '944 123 456');
  });

  testWidgets('drops a trunk zero and caps at the country length', (
    tester,
  ) async {
    final controller = await pump(tester, _c('SY'));
    await tester.enterText(find.byType(TextField), '0944123456789');
    expect(controller.text, '944 123 456'); // 9 digits max, no leading 0
  });

  testWidgets('a pasted international number lands as a national one', (
    tester,
  ) async {
    final controller = await pump(tester, _c('SY'));
    await tester.enterText(find.byType(TextField), '+963 944 123 456');
    expect(controller.text, '944 123 456');
  });

  testWidgets('shows the completion check only once the number is valid', (
    tester,
  ) async {
    await pump(tester, _c('SY'));
    final check = find.byIcon(Icons.check_circle_rounded);

    await tester.enterText(find.byType(TextField), '944 123');
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(_scaleOf(tester, check)).scale, 0);

    await tester.enterText(find.byType(TextField), '944 123 456');
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(_scaleOf(tester, check)).scale, 1);
  });

  testWidgets('switching country re-masks the number and tells the parent', (
    tester,
  ) async {
    final seen = ValueNotifier<String>('');
    final controller = TextEditingController();
    var country = _c('SY');

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Column(
              children: [
                PhoneField(
                  country: country,
                  controller: controller,
                  onCountryChanged: (_) {},
                  onChanged: (v) => seen.value = v,
                ),
                TextButton(
                  onPressed: () => setState(() => country = _c('IQ')),
                  child: const Text('switch'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '944123456');
    expect(controller.text, '944 123 456'); // SY grouping 3-3-3

    await tester.tap(find.text('switch'));
    await tester.pumpAndSettle();
    expect(controller.text, '944 123 456'); // IQ grouping 3-3-4, 9 digits
    expect(seen.value, controller.text);
  });
}

/// The [AnimatedScale] wrapping [icon].
Finder _scaleOf(WidgetTester tester, Finder icon) => find.ancestor(
  of: icon,
  matching: find.byType(AnimatedScale),
);
