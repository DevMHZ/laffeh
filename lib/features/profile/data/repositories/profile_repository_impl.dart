import '../../../../core/error/failures.dart';
import '../../../../core/error/supabase_error_debug.dart';
import '../../../../core/network/api_result.dart';
import '../../../auth/data/error/auth_error_mapper.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._remote);

  final ProfileRemoteDataSource _remote;

  @override
  Future<ApiResult<Profile?>> fetchMyProfile() async {
    try {
      final profile = await _remote.fetchMyProfile();
      return ApiSuccess<Profile?>(profile);
    } catch (e) {
      final mapped = AuthErrorMapper.map(e, context: 'fetchMyProfile');
      return ApiFailure<Profile?>(AuthFailure(mapped.code, mapped.message));
    }
  }

  @override
  Future<bool> isOnboardingComplete() async {
    try {
      final profile = await _remote.fetchMyProfile();
      return profile?.onboardingCompleted ?? false;
    } catch (e) {
      // Swallowed on purpose (a backend hiccup must not lock the user out of
      // the app), which is exactly why the detail has to reach the console.
      SupabaseErrorDebug.dump(e, context: 'isOnboardingComplete');
      return false;
    }
  }

  @override
  Future<ApiResult<void>> recordTermsAcceptance(String termsVersion) async {
    try {
      await _remote.recordTermsAcceptance(termsVersion);
      return const ApiSuccess<void>(null);
    } catch (e) {
      final mapped = AuthErrorMapper.map(e, context: 'record_terms_acceptance');
      return ApiFailure<void>(AuthFailure(mapped.code, mapped.message));
    }
  }

  @override
  Future<ApiResult<void>> saveOnboarding({
    required String fullName,
    required String companyName,
    required List<String> useCaseCodes,
    String? otherText,
    String? termsVersion,
  }) async {
    try {
      await _remote.saveOnboarding(
        fullName: fullName,
        companyName: companyName,
        useCaseCodes: useCaseCodes,
        otherText: otherText,
        termsVersion: termsVersion,
      );
      return const ApiSuccess<void>(null);
    } catch (e) {
      final mapped = AuthErrorMapper.map(e, context: 'save_onboarding');
      return ApiFailure<void>(AuthFailure(mapped.code, mapped.message));
    }
  }
}
