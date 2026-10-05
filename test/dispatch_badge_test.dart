import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/features/route_planner/presentation/pages/route_planner_top_bar.dart';

void main() {
  testWidgets('My routes button shows unread trips and remains tappable', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TopIconButton(
            tooltip: 'My routes',
            icon: Icons.route,
            unread: 3,
            onPressed: () => taps++,
          ),
        ),
      ),
    );

    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.byTooltip('My routes'));
    expect(taps, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TopIconButton(
            tooltip: 'My routes',
            icon: Icons.route,
            onPressed: () {},
          ),
        ),
      ),
    );
    expect(find.text('3'), findsNothing);
  });
}
