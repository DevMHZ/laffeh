import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/exceptions.dart' as core;
import '../error/auth_error_mapper.dart';

/// Thin wrapper over `supabase.auth`. Throws raw provider errors; the
/// repository catches and maps them.
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> authState() => _client.auth.onAuthStateChange;

  Future<User> signUp({required String phone, required String password}) async {
    final res = await _client.auth.signUp(phone: phone, password: password);
    final user = res.user;
    if (user == null) {
      // Phone confirmation is expected to be OFF; a null user here means the
      // project is misconfigured (would otherwise require an OTP step).
      throw const core.AuthException(
        AuthErrorMapper.unknown,
        'no user after signUp',
      );
    }
    return user;
  }

  Future<User> signIn({required String phone, required String password}) async {
    final res = await _client.auth.signInWithPassword(
      phone: phone,
      password: password,
    );
    final user = res.user;
    if (user == null) {
      throw const core.AuthException(
        AuthErrorMapper.invalidCredentials,
        'no user after signIn',
      );
    }
    return user;
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Permanently deletes the signed-in account and everything keyed to it.
  ///
  /// The RPC runs SECURITY DEFINER server-side (the anon key cannot write to
  /// `auth.users`) and always targets `auth.uid()`.
  Future<void> deleteAccount() async {
    await _client.rpc('delete_my_account');
    // The account is gone, but this device still holds its JWT. Clear it
    // locally — a normal (global) signOut would call a server endpoint that
    // now has no user to sign out, and fail.
    await _client.auth.signOut(scope: SignOutScope.local);
  }
}
