part of 'auth_cubit.dart';

/// Global session state. Onboarding-completeness is resolved separately by the
/// routing layer (via the profile repository), keeping this cubit purely about
/// "is there a session, and who".
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Startup — deciding whether a session already exists.
class AuthInitializing extends AuthState {
  const AuthInitializing();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthAuthenticated extends AuthState {
  final AuthUser user;
  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}
