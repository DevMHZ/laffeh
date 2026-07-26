// Renders the auth screens (welcome / sign-in / create-account steps) in
// Arabic RTL and English LTR and saves them as goldens — a visual preview,
// not a regression gate.
// Run: flutter test test/auth_ui_preview_test.dart --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laffeh/core/constants/app_constants.dart';
import 'package:laffeh/core/di/service_locator.dart';
import 'package:laffeh/core/error/failures.dart';
import 'package:laffeh/core/network/api_result.dart';
import 'package:laffeh/core/theme/app_theme.dart';
import 'package:laffeh/features/auth/domain/entities/auth_user.dart';
import 'package:laffeh/features/auth/domain/repositories/auth_repository.dart';
import 'package:laffeh/features/auth/presentation/pages/sign_in_page.dart';
import 'package:laffeh/features/auth/presentation/pages/welcome_page.dart';
import 'package:laffeh/features/profile/domain/entities/profile.dart';
import 'package:laffeh/features/profile/domain/repositories/profile_repository.dart';
import 'package:laffeh/features/profile/presentation/pages/account_onboarding_page.dart';

class _StubAuthRepository implements AuthRepository {
  @override
  AuthUser? get currentUser => null;
  @override
  Stream<AuthUser?> authStateChanges() => const Stream<AuthUser?>.empty();
  @override
  Future<ApiResult<AuthUser>> signIn({
    required String phone,
    required String password,
  }) async => const ApiFailure<AuthUser>(AuthFailure('unknown'));
  @override
  Future<ApiResult<AuthUser>> signUp({
    required String phone,
    required String password,
  }) async => const ApiFailure<AuthUser>(AuthFailure('unknown'));
  @override
  Future<ApiResult<void>> signOut() async => const ApiSuccess<void>(null);
  @override
  Future<ApiResult<void>> deleteAccount() async => const ApiSuccess<void>(null);
}

class _StubProfileRepository implements ProfileRepository {
  @override
  Future<ApiResult<void>> saveOnboarding({
    required String fullName,
    required String companyName,
    required List<String> useCaseCodes,
    String? otherText,
  }) async => const ApiSuccess<void>(null);
  @override
  Future<ApiResult<Profile?>> fetchMyProfile() async =>
      const ApiSuccess<Profile?>(null);
  @override
  Future<bool> isOnboardingComplete() async => false;
}

Future<void> _loadFonts() async {
  final loader = FontLoader('Almarai')
    ..addFont(rootBundle.load('assets/fonts/Almarai-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Almarai-Bold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Almarai-ExtraBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Almarai-Light.ttf'));
  await loader.load();
}

Widget _app(Widget home, String lang) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.data,
  locale: Locale(lang),
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('en'), Locale('ar'), Locale('fr')],
  home: Directionality(
    textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
    child: home,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sl.registerSingleton<AuthRepository>(_StubAuthRepository());
    sl.registerSingleton<ProfileRepository>(_StubProfileRepository());
  });
  tearDownAll(sl.reset);
  tearDown(() => AppStrings.setLocale(const Locale('en')));

  Future<void> shoot(
    WidgetTester tester,
    Widget page,
    String lang,
    String name,
  ) async {
    await _loadFonts();
    AppStrings.setLocale(Locale(lang));
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(page, lang));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/auth_$name.png'),
    );
  }

  testWidgets('welcome — ar', (t) async {
    await shoot(t, const WelcomePage(), 'ar', 'welcome_ar');
  });

  testWidgets('sign in — ar', (t) async {
    await shoot(t, const SignInPage(), 'ar', 'sign_in_ar');
  });

  testWidgets('sign in — en', (t) async {
    await shoot(t, const SignInPage(), 'en', 'sign_in_en');
  });

  testWidgets('create account, credentials step — ar', (t) async {
    await shoot(t, const AccountOnboardingPage(), 'ar', 'credentials_ar');
  });

  testWidgets('create account, credentials step — en', (t) async {
    await shoot(t, const AccountOnboardingPage(), 'en', 'credentials_en');
  });

  testWidgets('credentials step, validation errors — ar', (t) async {
    await _loadFonts();
    AppStrings.setLocale(const Locale('ar'));
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(_app(const AccountOnboardingPage(), 'ar'));
    await t.pumpAndSettle();

    // A half-filled form: a too-short number and mismatched passwords.
    final fields = find.byType(TextField);
    await t.enterText(fields.at(0), '944');
    await t.enterText(fields.at(1), 'secret123');
    await t.enterText(fields.at(2), 'secret124');
    await t.tap(find.text(AppStrings.authContinue));
    await t.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/auth_credentials_errors_ar.png'),
    );
  });
}
