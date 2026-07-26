import '../../../../core/network/api_result.dart';
import '../entities/profile.dart';

abstract class ProfileRepository {
  /// The current user's profile, or null when no row exists yet.
  Future<ApiResult<Profile?>> fetchMyProfile();

  /// Convenience for routing: true only when a completed profile exists.
  /// Never throws — returns false on any error.
  Future<bool> isOnboardingComplete();

  /// Persists a whole onboarding submission atomically (server-side RPC).
  Future<ApiResult<void>> saveOnboarding({
    required String fullName,
    required String companyName,
    required List<String> useCaseCodes,
    String? otherText,
  });
}
