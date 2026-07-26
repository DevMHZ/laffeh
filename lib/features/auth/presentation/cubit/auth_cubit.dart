import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_result.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_state.dart';

/// App-global authentication state. Registered as a singleton so the whole app
/// reacts to sign-in / sign-out (routing, the account nudge, settings).
///
/// Form-level loading and error handling live in the screens: [signUp] /
/// [signIn] return an [ApiResult] the caller awaits, while the reactive
/// [AuthState] is driven by the repository's auth stream.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repo) : super(const AuthInitializing()) {
    _bootstrap();
  }

  final AuthRepository _repo;
  StreamSubscription<AuthUser?>? _sub;

  void _bootstrap() {
    final user = _repo.currentUser;
    emit(user == null ? const AuthUnauthenticated() : AuthAuthenticated(user));
    _sub = _repo.authStateChanges().listen((user) {
      final next = user == null
          ? const AuthUnauthenticated()
          : AuthAuthenticated(user);
      if (next != state) emit(next);
    });
  }

  bool get isAuthenticated => state is AuthAuthenticated;

  AuthUser? get currentUser =>
      state is AuthAuthenticated ? (state as AuthAuthenticated).user : null;

  Future<ApiResult<AuthUser>> signUp({
    required String phone,
    required String password,
  }) => _repo.signUp(phone: phone, password: password);

  Future<ApiResult<AuthUser>> signIn({
    required String phone,
    required String password,
  }) => _repo.signIn(phone: phone, password: password);

  Future<ApiResult<void>> signOut() => _repo.signOut();

  /// Permanently deletes the account. On success the repository's auth stream
  /// emits null, so the app drops back to the signed-out state on its own.
  Future<ApiResult<void>> deleteAccount() => _repo.deleteAccount();

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
