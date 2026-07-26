import 'package:flutter_test/flutter_test.dart';
import 'package:laffeh/core/error/failures.dart';
import 'package:laffeh/core/network/api_result.dart';
import 'package:laffeh/features/auth/data/error/auth_error_mapper.dart';
import 'package:laffeh/features/auth/domain/entities/auth_user.dart';
import 'package:laffeh/features/auth/domain/repositories/auth_repository.dart';
import 'package:laffeh/features/profile/domain/entities/profile.dart';
import 'package:laffeh/features/profile/domain/repositories/profile_repository.dart';
import 'package:laffeh/features/profile/presentation/cubit/account_onboarding_cubit.dart';

class FakeAuthRepository implements AuthRepository {
  ApiResult<AuthUser> signUpResult = const ApiSuccess<AuthUser>(
    AuthUser(id: 'u1'),
  );
  int signUpCalls = 0;

  @override
  Future<ApiResult<AuthUser>> signUp({
    required String phone,
    required String password,
  }) async {
    signUpCalls++;
    return signUpResult;
  }

  @override
  AuthUser? get currentUser => null;
  @override
  Stream<AuthUser?> authStateChanges() => const Stream<AuthUser?>.empty();
  @override
  Future<ApiResult<AuthUser>> signIn({
    required String phone,
    required String password,
  }) async => signUpResult;
  @override
  Future<ApiResult<void>> signOut() async => const ApiSuccess<void>(null);
  @override
  Future<ApiResult<void>> deleteAccount() async => const ApiSuccess<void>(null);
}

class FakeProfileRepository implements ProfileRepository {
  ApiResult<void> saveResult = const ApiSuccess<void>(null);
  int saveCalls = 0;

  @override
  Future<ApiResult<void>> saveOnboarding({
    required String fullName,
    required String companyName,
    required List<String> useCaseCodes,
    String? otherText,
  }) async {
    saveCalls++;
    return saveResult;
  }

  @override
  Future<ApiResult<Profile?>> fetchMyProfile() async =>
      const ApiSuccess<Profile?>(null);
  @override
  Future<bool> isOnboardingComplete() async => false;
}

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profile;

  AccountOnboardingCubit build({int startStep = 0, bool credsDone = false}) =>
      AccountOnboardingCubit(
        auth,
        profile,
        startStep: startStep,
        credentialsDone: credsDone,
      );

  setUp(() {
    auth = FakeAuthRepository();
    profile = FakeProfileRepository();
  });

  void enterValidCredentials(AccountOnboardingCubit c) {
    c.setNational('944123456');
    c.setPassword('password1');
    c.setConfirm('password1');
  }

  test('starts on the credentials step', () {
    final c = build();
    expect(c.state.step, 0);
    expect(c.state.isBusy, isFalse);
  });

  test('invalid credentials block sign-up and set field errors', () async {
    final c = build();
    c.setNational(''); // invalid phone
    c.setPassword('short');
    await c.next();
    expect(c.state.step, 0);
    expect(c.state.phoneError, 'phoneRequired');
    expect(c.state.passwordError, 'passwordTooShort');
    expect(auth.signUpCalls, 0);
  });

  test('a number that fails the country plan blocks sign-up', () async {
    final c = build(); // defaults to Syria (+963)
    c.setNational('1234');
    c.setPassword('password1');
    c.setConfirm('password1');
    await c.next();
    expect(c.state.step, 0);
    expect(c.state.phoneError, 'phoneNotMobile');
    expect(auth.signUpCalls, 0);
  });

  test('valid credentials sign up and advance', () async {
    final c = build();
    enterValidCredentials(c);
    await c.next();
    expect(auth.signUpCalls, 1);
    expect(c.state.credentialsDone, isTrue);
    expect(c.state.step, 1);
  });

  test('phone-in-use surfaces the error and stays on step 0', () async {
    auth.signUpResult = const ApiFailure<AuthUser>(
      AuthFailure(AuthErrorMapper.phoneInUse),
    );
    final c = build();
    enterValidCredentials(c);
    await c.next();
    expect(c.state.step, 0);
    expect(c.state.submitErrorCode, AuthErrorMapper.phoneInUse);
  });

  test('name/company validation gates step 1', () async {
    final c = build(startStep: 1, credsDone: true);
    await c.next(); // empty name + company
    expect(c.state.step, 1);
    expect(c.state.nameError, isNotNull);
    expect(c.state.companyError, isNotNull);

    c.setFullName('Mohamad');
    c.setCompany('Afdal');
    await c.next();
    expect(c.state.step, 2);
  });

  test('use-case selection is required and multi-select works', () async {
    final c = build(startStep: 2, credsDone: true);
    await c.next(); // none selected
    expect(c.state.step, 2);
    expect(c.state.useCaseError, isNotNull);

    c.toggleUseCase('delivery');
    c.toggleUseCase('driver');
    expect(c.state.useCases, {'delivery', 'driver'});
    c.toggleUseCase('driver'); // toggle off
    expect(c.state.useCases, {'delivery'});

    await c.next();
    expect(c.state.step, 3);
  });

  test('submit persists and flips to success', () async {
    final c = build(startStep: 3, credsDone: true);
    c.setFullName('Mohamad');
    c.setCompany('Afdal');
    c.toggleUseCase('delivery');
    await c.submit();
    expect(profile.saveCalls, 1);
    expect(c.state.phase, OnbPhase.success);
  });

  test('submit failure surfaces an error, no success', () async {
    profile.saveResult = const ApiFailure<void>(
      AuthFailure(AuthErrorMapper.backendUnavailable),
    );
    final c = build(startStep: 3, credsDone: true);
    c.setFullName('Mohamad');
    c.setCompany('Afdal');
    c.toggleUseCase('delivery');
    await c.submit();
    expect(c.state.phase, OnbPhase.editing);
    expect(c.state.submitErrorCode, AuthErrorMapper.backendUnavailable);
  });
}
