import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/form_validators.dart';
import '../../../auth/data/error/auth_error_mapper.dart';
import '../../../auth/domain/country.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../domain/entities/use_case_option.dart';
import '../../domain/repositories/profile_repository.dart';

part 'account_onboarding_state.dart';

/// Drives the multi-step "create account" flow.
///
/// Step 0 creates the Supabase account (sign-up). Steps 1–2 collect the profile
/// locally. Step 3 (summary) persists everything atomically via the
/// `save_onboarding` RPC and flips to [OnbPhase.success].
class AccountOnboardingCubit extends Cubit<AccountOnboardingState> {
  AccountOnboardingCubit(
    this._auth,
    this._profile, {
    int startStep = 0,
    bool credentialsDone = false,
    Country? country,
  }) : super(
         AccountOnboardingState(
           step: startStep,
           country: country ?? Country.fallback,
           credentialsDone: credentialsDone,
         ),
       );

  final AuthRepository _auth;
  final ProfileRepository _profile;

  // ── Field setters (clear their own error as the user edits) ──
  void setCountry(Country c) =>
      emit(state.copyWith(country: c, clearPhoneError: true));
  void setNational(String v) =>
      emit(state.copyWith(national: v, clearPhoneError: true));
  void setPassword(String v) =>
      emit(state.copyWith(password: v, clearPasswordError: true));
  void setConfirm(String v) =>
      emit(state.copyWith(confirm: v, clearConfirmError: true));
  void setFullName(String v) =>
      emit(state.copyWith(fullName: v, clearNameError: true));
  void setCompany(String v) =>
      emit(state.copyWith(company: v, clearCompanyError: true));
  void setOtherText(String v) => emit(state.copyWith(otherText: v));

  void toggleUseCase(String code) {
    final next = Set<String>.from(state.useCases);
    if (!next.add(code)) next.remove(code);
    emit(state.copyWith(useCases: next, clearUseCaseError: true));
  }

  void back() {
    if (state.step > 0) emit(state.copyWith(step: state.step - 1));
  }

  /// Validates the current step and advances (creating the account on step 0).
  Future<void> next() async {
    if (state.isBusy) return;
    switch (state.step) {
      case 0:
        await _submitCredentials();
      case 1:
        _validateNameCompany();
      case 2:
        _validateUseCases();
      default:
        break;
    }
  }

  Future<void> _submitCredentials() async {
    final phoneErr = state.country.validateNational(state.national);
    final phone = state.phoneE164;
    final passErr = FormValidators.password(state.password);
    final confErr = FormValidators.passwordConfirm(
      state.password,
      state.confirm,
    );

    if (phoneErr != null || passErr != null || confErr != null) {
      emit(
        state.copyWith(
          phoneError: phoneErr,
          passwordError: passErr,
          confirmError: confErr,
          clearPhoneError: phoneErr == null,
          clearPasswordError: passErr == null,
          clearConfirmError: confErr == null,
        ),
      );
      return;
    }

    // Already created (e.g. returning after a back-and-forth) → just advance.
    if (state.credentialsDone) {
      emit(state.copyWith(step: 1, clearSubmitError: true));
      return;
    }

    emit(state.copyWith(phase: OnbPhase.submitting, clearSubmitError: true));
    final result = await _auth.signUp(phone: phone!, password: state.password);
    result.when(
      success: (_) => emit(
        state.copyWith(phase: OnbPhase.editing, credentialsDone: true, step: 1),
      ),
      failure: (f) {
        final code = f is AuthFailure ? f.code : AuthErrorMapper.unknown;
        emit(state.copyWith(phase: OnbPhase.editing, submitErrorCode: code));
      },
    );
  }

  void _validateNameCompany() {
    final nameErr = FormValidators.fullName(state.fullName);
    final companyErr = FormValidators.companyName(state.company);
    if (nameErr != null || companyErr != null) {
      emit(
        state.copyWith(
          nameError: nameErr,
          companyError: companyErr,
          clearNameError: nameErr == null,
          clearCompanyError: companyErr == null,
        ),
      );
      return;
    }
    emit(state.copyWith(step: 2));
  }

  void _validateUseCases() {
    if (state.useCases.isEmpty) {
      emit(state.copyWith(useCaseError: 'useCaseRequired'));
      return;
    }
    emit(state.copyWith(step: 3));
  }

  /// Final submit from the summary step.
  Future<void> submit() async {
    if (state.isBusy) return;
    emit(state.copyWith(phase: OnbPhase.submitting, clearSubmitError: true));

    final other = state.isOtherSelected ? state.otherText.trim() : null;
    final result = await _profile.saveOnboarding(
      fullName: state.fullName.trim(),
      companyName: state.company.trim(),
      useCaseCodes: state.useCases.toList(growable: false),
      otherText: (other == null || other.isEmpty) ? null : other,
    );

    result.when(
      success: (_) => emit(state.copyWith(phase: OnbPhase.success)),
      failure: (f) {
        final code = f is AuthFailure ? f.code : AuthErrorMapper.unknown;
        emit(state.copyWith(phase: OnbPhase.editing, submitErrorCode: code));
      },
    );
  }
}
