import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/features/auth/presentation/widgets/password_field.dart';

void main() {
  setUp(() => AppStrings.setLocale(const Locale('en')));

  testWidgets('toggles between hidden and visible', (tester) async {
    final controller = TextEditingController(text: 'secret123');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PasswordField(controller: controller)),
      ),
    );

    // Starts obscured → the "show" (eye) icon is present.
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();

    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });

  testWidgets('never shows a strength meter', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PasswordField(controller: controller)),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Passw0rd!x');
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('renders the error line when one is given', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PasswordField(
            controller: controller,
            errorText: 'Password is too short',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Password is too short'), findsOneWidget);
  });
}
