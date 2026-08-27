// The language switch has to reach screens that are already on the stack.
// Copy is read from AppStrings statics, so nothing below the Navigator
// subscribes to the change — and the app must not be re-keyed to force it
// (that tears down the planner's native map). See [markSubtreeForRebuild].
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/core/utils/tree_refresh.dart';

/// Reads its copy the way the app does: a static getter, no InheritedWidget,
/// and `const` so a parent rebuild alone can never reach it.
class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) => Text(AppStrings.settings);
}

void main() {
  tearDown(() => AppStrings.setLocale(const Locale('en')));

  testWidgets('a language change reaches a screen already built', (
    tester,
  ) async {
    AppStrings.setLocale(const Locale('en'));
    late BuildContext root;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            root = context;
            return const _Screen();
          },
        ),
      ),
    );
    final english = AppStrings.settings;
    expect(find.text(english), findsOneWidget);

    AppStrings.setLocale(const Locale('ar'));
    final arabic = AppStrings.settings;
    expect(arabic, isNot(english));

    // Without the refresh the screen is stranded on the old language —
    // this is the bug the helper exists for.
    await tester.pump();
    expect(find.text(english), findsOneWidget);

    markSubtreeForRebuild(root);
    await tester.pump();

    expect(find.text(arabic), findsOneWidget);
    expect(find.text(english), findsNothing);
  });
}
