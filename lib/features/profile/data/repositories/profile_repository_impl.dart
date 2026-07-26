import '../../../../core/error/failures.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/utils/debug_log.dart';
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
      final mapped = AuthErrorMapper.map(e);
      return ApiFailure<Profile?>(AuthFailure(mapped.code, mapped.message));
    }
  }

  @override
  Future<bool> isOnboardingComplete() async {
    try {
      final profile = await _remote.fetchMyProfile();
      return profile?.onboardingCompleted ?? false;
    } catch (e) {
      DebugLog.log('AUTH', 'isOnboardingComplete failed: $e');
      return false;
    }
  }

  @override
  Future<ApiResult<void>> saveOnboarding({
    required String fullName,
    required String companyName,
    required List<String> useCaseCodes,
    String? otherText,
  }) async {
    try {
      await _remote.saveOnboarding(
        fullName: fullName,
        companyName: companyName,
        useCaseCodes: useCaseCodes,
        otherText: otherText,
      );
      return const ApiSuccess<void>(null);
    } catch (e) {
      final mapped = AuthErrorMapper.map(e);
      return ApiFailure<void>(AuthFailure(mapped.code, mapped.message));
    }
  }
}
