import '../../../core/constants/app_constants.dart';
import '../data/error/auth_error_mapper.dart';
import '../domain/country.dart';

/// Maps stable validation keys and auth error codes to localized copy.
/// Keeps the mapping in one place so widgets stay declarative.
class AuthMessages {
  AuthMessages._();

  /// A `FormValidators` key → localized message. Returns null for a null key
  /// (i.e. "valid").
  static String? validation(String? key) {
    switch (key) {
      case null:
        return null;
      case 'passwordRequired':
        return AppStrings.valPasswordRequired;
      case 'passwordTooShort':
        return AppStrings.valPasswordTooShort;
      case 'passwordConfirmRequired':
        return AppStrings.valPasswordConfirmRequired;
      case 'passwordMismatch':
        return AppStrings.valPasswordMismatch;
      case 'nameRequired':
        return AppStrings.valNameRequired;
      case 'nameTooShort':
        return AppStrings.valNameTooShort;
      case 'nameTooLong':
        return AppStrings.valNameTooLong;
      case 'nameNumeric':
        return AppStrings.valNameNumeric;
      case 'companyRequired':
        return AppStrings.valCompanyRequired;
      case 'companyTooShort':
        return AppStrings.valCompanyTooShort;
      case 'companyTooLong':
        return AppStrings.valCompanyTooLong;
      case 'phoneInvalid':
        return AppStrings.valPhoneInvalid;
      case 'termsRequired':
        return AppStrings.valTermsRequired;
      default:
        return AppStrings.errUnknownAuth;
    }
  }

  /// A phone validation key → copy naming the country and showing one of its
  /// numbers, so "invalid" always comes with what a valid number looks like.
  static String? phoneValidation(String? key, Country country) {
    if (key == null) return null;
    final template = switch (key) {
      'phoneRequired' => AppStrings.valPhoneRequired,
      'phoneTooShort' => AppStrings.valPhoneTooShort,
      'phoneTooLong' => AppStrings.valPhoneTooLong,
      'phoneNotMobile' => AppStrings.valPhoneNotMobile,
      _ => AppStrings.valPhoneInvalid,
    };
    return template
        .replaceAll('{country}', country.localizedName(AppStrings.languageCode))
        .replaceAll('{example}', country.example);
  }

  /// An [AuthErrorMapper] code → localized message.
  static String authError(String code) {
    switch (code) {
      case AuthErrorMapper.invalidCredentials:
        return AppStrings.errInvalidCredentials;
      case AuthErrorMapper.phoneInUse:
        return AppStrings.errPhoneInUse;
      case AuthErrorMapper.weakPassword:
        return AppStrings.errWeakPassword;
      case AuthErrorMapper.rateLimited:
        return AppStrings.errRateLimited;
      case AuthErrorMapper.network:
        return AppStrings.errAuthNetwork;
      case AuthErrorMapper.signupsDisabled:
        return AppStrings.errSignupsDisabled;
      case AuthErrorMapper.backendUnavailable:
        return AppStrings.errBackendUnavailable;
      // Server-side echoes of the form rules — same copy as the field errors,
      // so the user reads one message for one rule wherever it is caught.
      case AuthErrorMapper.serverNameRequired:
        return AppStrings.valNameRequired;
      case AuthErrorMapper.serverCompanyRequired:
        return AppStrings.valCompanyRequired;
      case AuthErrorMapper.serverUseCaseRequired:
        return AppStrings.useCaseSelectAtLeastOne;
      default:
        return AppStrings.errUnknownAuth;
    }
  }
}
