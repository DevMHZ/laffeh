// Hide Supabase's own AuthUser so our domain entity is unambiguous here.
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../../core/error/failures.dart';
import '../../../../core/network/api_result.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../error/auth_error_mapper.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote);

  final AuthRemoteDataSource _remote;

  AuthUser? _toEntity(User? user) =>
      user == null ? null : AuthUser(id: user.id, phone: user.phone);

  @override
  AuthUser? get currentUser => _toEntity(_remote.currentUser);

  @override
  Stream<AuthUser?> authStateChanges() =>
      _remote.authState().map((state) => _toEntity(state.session?.user));

  @override
  Future<ApiResult<AuthUser>> signUp({
    required String phone,
    required String password,
  }) => _guard(
    () => _remote.signUp(phone: phone, password: password),
    context: 'signUp',
  );

  @override
  Future<ApiResult<AuthUser>> signIn({
    required String phone,
    required String password,
  }) => _guard(
    () => _remote.signIn(phone: phone, password: password),
    context: 'signIn',
  );

  @override
  Future<ApiResult<void>> signOut() async {
    try {
      await _remote.signOut();
      return const ApiSuccess<void>(null);
    } catch (e) {
      final mapped = AuthErrorMapper.map(e, context: 'signOut');
      return ApiFailure<void>(AuthFailure(mapped.code, mapped.message));
    }
  }

  @override
  Future<ApiResult<void>> deleteAccount() async {
    try {
      await _remote.deleteAccount();
      return const ApiSuccess<void>(null);
    } catch (e) {
      final mapped = AuthErrorMapper.map(e, context: 'delete_my_account');
      return ApiFailure<void>(AuthFailure(mapped.code, mapped.message));
    }
  }

  Future<ApiResult<AuthUser>> _guard(
    Future<User> Function() action, {
    required String context,
  }) async {
    try {
      final user = await action();
      return ApiSuccess<AuthUser>(_toEntity(user)!);
    } catch (e) {
      final mapped = AuthErrorMapper.map(e, context: context);
      return ApiFailure<AuthUser>(AuthFailure(mapped.code, mapped.message));
    }
  }
}
