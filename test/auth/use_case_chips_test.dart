import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/features/profile/presentation/widgets/use_case_chips.dart';

void main() {
  setUp(() => AppStrings.setLocale(const Locale('en')));

  testWidgets('multi-selects and shows a check on selected cards', (
    tester,
  ) async {
    final selected = <String>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: UseCaseChips(
                selected: selected,
                onToggle: (code) => setState(() {
                  if (!selected.add(code)) selected.remove(code);
                }),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.check_circle), findsNothing);

    await tester.tap(find.text(AppStrings.ucDelivery));
    await tester.pumpAndSettle();
    expect(selected, {'delivery'});
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await tester.tap(find.text(AppStrings.ucPersonalUse));
    await tester.pumpAndSettle();
    expect(selected, {'delivery', 'personal_use'});
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));

    // Toggling off removes it.
    await tester.tap(find.text(AppStrings.ucDelivery));
    await tester.pumpAndSettle();
    expect(selected, {'personal_use'});
  });
}
