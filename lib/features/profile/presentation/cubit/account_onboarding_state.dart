part of 'account_onboarding_cubit.dart';

enum OnbPhase { editing, submitting, success }

class AccountOnboardingState extends Equatable {
  final int step; // 0=credentials, 1=name/company, 2=use-cases, 3=summary
  final Country country;
  final String national;
  final String password;
  final String confirm;
  final String fullName;
  final String company;
  final Set<String> useCases;
  final String otherText;

  /// True once the account has been created (sign-up succeeded / resuming).
  final bool credentialsDone;

  /// Whether the user ticked the policies consent box. Required before an
  /// account can be created; pre-set for resumed flows, where the account
  /// (and therefore the acceptance) already exists.
  final bool acceptedTerms;
  final OnbPhase phase;

  // Field-level validation error keys (mapped to copy by AuthMessages).
  final String? phoneError;
  final String? passwordError;
  final String? confirmError;
  final String? nameError;
  final String? companyError;
  final String? useCaseError;
  final String? termsError;

  /// Async (sign-up / save) error, as an AuthErrorMapper code.
  final String? submitErrorCode;

  const AccountOnboardingState({
    required this.step,
    required this.country,
    this.national = '',
    this.password = '',
    this.confirm = '',
    this.fullName = '',
    this.company = '',
    this.useCases = const {},
    this.otherText = '',
    this.credentialsDone = false,
    this.acceptedTerms = false,
    this.phase = OnbPhase.editing,
    this.phoneError,
    this.passwordError,
    this.confirmError,
    this.nameError,
    this.companyError,
    this.useCaseError,
    this.termsError,
    this.submitErrorCode,
  });

  static const int lastStep = 3;

  bool get isOtherSelected => useCases.contains(UseCaseOption.otherCode);
  bool get isBusy => phase != OnbPhase.editing;

  /// The typed number in E.164, or null when it doesn't fit the selected
  /// country's mobile plan.
  String? get phoneE164 => country.toE164(national);

  AccountOnboardingState copyWith({
    int? step,
    Country? country,
    String? national,
    String? password,
    String? confirm,
    String? fullName,
    String? company,
    Set<String>? useCases,
    String? otherText,
    bool? credentialsDone,
    bool? acceptedTerms,
    OnbPhase? phase,
    // Nullable fields use explicit "clear" flags so copyWith can reset them.
    String? phoneError,
    bool clearPhoneError = false,
    String? passwordError,
    bool clearPasswordError = false,
    String? confirmError,
    bool clearConfirmError = false,
    String? nameError,
    bool clearNameError = false,
    String? companyError,
    bool clearCompanyError = false,
    String? useCaseError,
    bool clearUseCaseError = false,
    String? termsError,
    bool clearTermsError = false,
    String? submitErrorCode,
    bool clearSubmitError = false,
  }) {
    return AccountOnboardingState(
      step: step ?? this.step,
      country: country ?? this.country,
      national: national ?? this.national,
      password: password ?? this.password,
      confirm: confirm ?? this.confirm,
      fullName: fullName ?? this.fullName,
      company: company ?? this.company,
      useCases: useCases ?? this.useCases,
      otherText: otherText ?? this.otherText,
      credentialsDone: credentialsDone ?? this.credentialsDone,
      acceptedTerms: acceptedTerms ?? this.acceptedTerms,
      phase: phase ?? this.phase,
      phoneError: clearPhoneError ? null : (phoneError ?? this.phoneError),
      passwordError: clearPasswordError
          ? null
          : (passwordError ?? this.passwordError),
      confirmError: clearConfirmError
          ? null
          : (confirmError ?? this.confirmError),
      nameError: clearNameError ? null : (nameError ?? this.nameError),
      companyError: clearCompanyError
          ? null
          : (companyError ?? this.companyError),
      useCaseError: clearUseCaseError
          ? null
          : (useCaseError ?? this.useCaseError),
      termsError: clearTermsError ? null : (termsError ?? this.termsError),
      submitErrorCode: clearSubmitError
          ? null
          : (submitErrorCode ?? this.submitErrorCode),
    );
  }

  @override
  List<Object?> get props => [
    step,
    country,
    national,
    password,
    confirm,
    fullName,
    company,
    useCases,
    otherText,
    credentialsDone,
    acceptedTerms,
    phase,
    phoneError,
    passwordError,
    confirmError,
    nameError,
    companyError,
    useCaseError,
    termsError,
    submitErrorCode,
  ];
}
