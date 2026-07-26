import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/legal_config.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/services/consent_store.dart';
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
    ConsentStore? consent,
  }) : _consent = consent,
       super(
         AccountOnboardingState(
           step: startStep,
           country: country ?? Country.fallback,
           credentialsDone: credentialsDone,
           // A resumed flow already has an account, which could only have been
           // created by accepting the policies — so don't ask twice.
           acceptedTerms: credentialsDone,
         ),
       );

  final AuthRepository _auth;
  final ProfileRepository _profile;

  /// Records acceptance on-device. Null in tests / when storage is unavailable;
  /// the authoritative record is the one written by the onboarding RPC.
  final ConsentStore? _consent;

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

  void setAcceptedTerms(bool v) =>
      emit(state.copyWith(acceptedTerms: v, clearTermsError: true));

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

    // No account is created without an explicit acceptance of the policies.
    final termsErr = state.acceptedTerms ? null : 'termsRequired';

    if (phoneErr != null ||
        passErr != null ||
        confErr != null ||
        termsErr != null) {
      emit(
        state.copyWith(
          phoneError: phoneErr,
          passwordError: passErr,
          confirmError: confErr,
          termsError: termsErr,
          clearPhoneError: phoneErr == null,
          clearPasswordError: passErr == null,
          clearConfirmError: confErr == null,
          clearTermsError: termsErr == null,
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
    await result.when(
      success: (_) async {
        // Acceptance is recorded the moment the account exists, so it survives
        // even if the user drops out before finishing the profile steps.
        // Best-effort server-side: a failure here must not block a user who
        // already has a valid account — `save_onboarding` stamps it again at
        // the end of the flow.
        await _consent?.record(LegalConfig.termsVersion);
        await _profile.recordTermsAcceptance(LegalConfig.termsVersion);
        emit(
          state.copyWith(
            phase: OnbPhase.editing,
            credentialsDone: true,
            step: 1,
          ),
        );
      },
      failure: (f) async {
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
      // Stamps who accepted which policy version, server-side.
      termsVersion: LegalConfig.termsVersion,
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
