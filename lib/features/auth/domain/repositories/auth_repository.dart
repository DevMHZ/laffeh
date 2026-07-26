import '../../../../core/network/api_result.dart';
import '../entities/auth_user.dart';

/// Phone + password authentication over Supabase Auth (no OTP).
///
/// Implementations convert provider errors into typed [AuthFailure]s via the
/// error mapper; they never leak raw Supabase exceptions or Session objects.
abstract class AuthRepository {
  /// The current user if a session exists, else null (synchronous snapshot).
  AuthUser? get currentUser;

  /// Emits on sign-in / sign-out / token refresh. Null means signed out.
  Stream<AuthUser?> authStateChanges();

  /// Creates an account. With phone confirmations disabled server-side this
  /// returns an active session immediately (no OTP).
  Future<ApiResult<AuthUser>> signUp({
    required String phone,
    required String password,
  });

  Future<ApiResult<AuthUser>> signIn({
    required String phone,
    required String password,
  });

  Future<ApiResult<void>> signOut();

  /// Permanently deletes the signed-in account and its data, then ends the
  /// session. Irreversible — there is no recovery path.
  Future<ApiResult<void>> deleteAccount();
}
