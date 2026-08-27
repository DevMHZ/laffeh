import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/features/auth/presentation/pages/welcome_page.dart';

void main() {
  setUp(() => AppStrings.setLocale(const Locale('en')));
  tearDown(() => AppStrings.setLocale(const Locale('en')));

  Widget host({required bool required}) =>
      MaterialApp(home: WelcomePage(registrationRequired: required));

  testWidgets('offers the skip while the trial is still running', (
    tester,
  ) async {
    await tester.pumpWidget(host(required: false));

    expect(find.text(AppStrings.welcomeSkip), findsOneWidget);
    expect(find.text(AppStrings.welcomeTitle), findsOneWidget);
    expect(find.text(AppStrings.registrationRequiredTitle), findsNothing);
  });

  testWidgets('drops the skip once an account is required', (tester) async {
    await tester.pumpWidget(host(required: true));

    // The whole point: there is no way past this screen but the two CTAs.
    expect(find.text(AppStrings.welcomeSkip), findsNothing);
    expect(find.text(AppStrings.registrationRequiredTitle), findsOneWidget);
    expect(find.text(AppStrings.registrationRequiredBody), findsOneWidget);
    expect(find.text(AppStrings.welcomeCreateAccount), findsOneWidget);
    expect(find.text(AppStrings.welcomeSignInInstead), findsOneWidget);
  });

  testWidgets('the wall blocks the back gesture, the welcome does not', (
    tester,
  ) async {
    final blocked = find.byWidgetPredicate((w) => w is PopScope && !w.canPop);

    await tester.pumpWidget(host(required: true));
    expect(blocked, findsOneWidget);

    await tester.pumpWidget(host(required: false));
    expect(blocked, findsNothing);
  });
}
