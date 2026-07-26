import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/config/legal_config.dart';
import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/features/auth/presentation/widgets/consent_checkbox.dart';

void main() {
  setUp(() => AppStrings.setLocale(const Locale('en')));
  tearDown(() => AppStrings.setLocale(const Locale('en')));

  Widget host({
    required bool value,
    required ValueChanged<bool> onChanged,
    String? errorText,
  }) => MaterialApp(
    home: Scaffold(
      body: ConsentCheckbox(
        value: value,
        onChanged: onChanged,
        errorText: errorText,
      ),
    ),
  );

  testWidgets('renders the policy names as part of the sentence', (
    tester,
  ) async {
    await tester.pumpWidget(host(value: false, onChanged: (_) {}));

    // The template's placeholders are replaced by the localized doc names.
    expect(find.textContaining(AppStrings.legalTerms), findsOneWidget);
    expect(find.textContaining(AppStrings.legalPrivacy), findsOneWidget);
    expect(find.textContaining('{terms}'), findsNothing);
    expect(find.textContaining('{privacy}'), findsNothing);
  });

  testWidgets('tapping the row toggles the value', (tester) async {
    var value = false;
    await tester.pumpWidget(host(value: value, onChanged: (v) => value = v));

    await tester.tap(find.byType(Checkbox));
    expect(value, isTrue);
  });

  testWidgets('shows the error message when given one', (tester) async {
    await tester.pumpWidget(
      host(
        value: false,
        onChanged: (_) {},
        errorText: AppStrings.valTermsRequired,
      ),
    );
    expect(find.text(AppStrings.valTermsRequired), findsOneWidget);
  });

  testWidgets('sentence follows the active language', (tester) async {
    AppStrings.setLocale(const Locale('ar'));
    await tester.pumpWidget(host(value: true, onChanged: (_) {}));
    expect(find.textContaining('سياسة الخصوصية'), findsOneWidget);
  });

  test('policy deep links target the doc and language', () {
    expect(
      LegalConfig.uriFor(LegalDoc.privacy, languageCode: 'en').toString(),
      '${LegalConfig.baseUrl}#privacy-policy/en',
    );
    expect(
      LegalConfig.uriFor(LegalDoc.terms, languageCode: 'ar').toString(),
      '${LegalConfig.baseUrl}#terms-of-service/ar',
    );
    expect(
      LegalConfig.uriFor(
        LegalDoc.accountDeletion,
        languageCode: 'fr',
      ).toString(),
      '${LegalConfig.baseUrl}#account-deletion/fr',
    );
    // Unpublished languages fall back to English rather than 404-ing.
    expect(
      LegalConfig.uriFor(LegalDoc.privacy, languageCode: 'de').toString(),
      '${LegalConfig.baseUrl}#privacy-policy/en',
    );
  });
}
