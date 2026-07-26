import '../../../../core/network/api_result.dart';
import '../entities/profile.dart';

abstract class ProfileRepository {
  /// The current user's profile, or null when no row exists yet.
  Future<ApiResult<Profile?>> fetchMyProfile();

  /// Convenience for routing: true only when a completed profile exists.
  /// Never throws — returns false on any error.
  Future<bool> isOnboardingComplete();

  /// Records that the signed-in user accepted policy version [termsVersion].
  ///
  /// Called right after sign-up so the acceptance is stored even if the user
  /// abandons the profile steps. Re-accepting the same version keeps the
  /// original timestamp.
  Future<ApiResult<void>> recordTermsAcceptance(String termsVersion);

  /// Persists a whole onboarding submission atomically (server-side RPC).
  ///
  /// [termsVersion] records which published policy version the user accepted
  /// when creating the account.
  Future<ApiResult<void>> saveOnboarding({
    required String fullName,
    required String companyName,
    required List<String> useCaseCodes,
    String? otherText,
    String? termsVersion,
  });
}
