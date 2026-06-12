import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/constants/app_constants.dart';

void main() {
  test('localization resolves English by default and supports ar/fr', () {
    AppStrings.setLocale(const Locale('es'));
    expect(AppStrings.languageCode, 'en');
    expect(AppStrings.settings, 'Settings');

    AppStrings.setLocale(const Locale('ar'));
    expect(AppStrings.languageCode, 'ar');
    expect(AppStrings.settings, 'الإعدادات');

    AppStrings.setLocale(const Locale('fr'));
    expect(AppStrings.languageCode, 'fr');
    expect(AppStrings.settings, 'Parametres');

    AppStrings.setLocale(const Locale('en'));
  });
}
