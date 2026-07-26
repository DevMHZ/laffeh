import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/constants/app_constants.dart';

void main() {
  tearDown(() => AppStrings.setLocale(const Locale('en')));

  test('auth copy resolves in all three languages', () {
    AppStrings.setLocale(const Locale('en'));
    expect(AppStrings.welcomeCreateAccount, 'Create account');
    expect(AppStrings.errPhoneInUse, contains('already'));

    AppStrings.setLocale(const Locale('ar'));
    expect(AppStrings.welcomeCreateAccount, 'إنشاء حساب');
    expect(AppStrings.whatsappForgotMessage, 'لقد نسيت كلمة المرور');

    AppStrings.setLocale(const Locale('fr'));
    expect(AppStrings.welcomeCreateAccount, 'Créer un compte');
    expect(AppStrings.signInButton, 'Se connecter');
  });

  test('use-case labels are present for every seeded code', () {
    AppStrings.setLocale(const Locale('en'));
    for (final label in [
      AppStrings.ucDelivery,
      AppStrings.ucPersonalUse,
      AppStrings.ucNavigation,
      AppStrings.ucDriver,
      AppStrings.ucDeliveryDriver,
      AppStrings.ucFleetManagement,
      AppStrings.ucBusinessManagement,
      AppStrings.ucRoutePlanning,
      AppStrings.ucFieldOperations,
      AppStrings.ucFieldSales,
      AppStrings.ucOther,
    ]) {
      expect(label, isNotEmpty);
    }
  });
}
