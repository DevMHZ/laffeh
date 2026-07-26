import 'package:equatable/equatable.dart';

/// Public, typed error surface for the presentation layer.
///
/// Repositories never let raw exceptions leak. They convert
/// everything into a [Failure] subclass so the UI can pattern-match.
sealed class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  final int? statusCode;
  const ServerFailure(super.message, {this.statusCode});

  @override
  List<Object?> get props => [message, statusCode];
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class LocationFailure extends Failure {
  const LocationFailure(super.message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}

/// Authentication / account errors surfaced to the UI.
///
/// [code] is a stable, provider-agnostic identifier (e.g. `invalidCredentials`,
/// `phoneInUse`) mapped to localized copy by the presentation layer — the raw
/// Supabase message is never shown to the user.
class AuthFailure extends Failure {
  final String code;
  const AuthFailure(this.code, [String message = '']) : super(message);

  @override
  List<Object?> get props => [code, message];
}
