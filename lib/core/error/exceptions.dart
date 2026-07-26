/// Low-level (data layer) exceptions.
///
/// These are thrown by datasources and caught by repositories,
/// which convert them into typed [Failure] values for the UI.
class ServerException implements Exception {
  final String message;
  final int? statusCode;
  const ServerException(this.message, {this.statusCode});

  @override
  String toString() => 'ServerException($statusCode): $message';
}

class NetworkException implements Exception {
  final String message;
  const NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

class CacheException implements Exception {
  final String message;
  const CacheException(this.message);
}

class LocationException implements Exception {
  final String message;
  const LocationException(this.message);
}

class InvalidResponseException implements Exception {
  final String message;
  const InvalidResponseException(this.message);
}

/// Thrown by the auth datasource; carries a provider-agnostic [code] plus the
/// original message for logging (never shown to the user directly).
class AuthException implements Exception {
  final String code;
  final String message;
  const AuthException(this.code, [this.message = '']);

  @override
  String toString() => 'AuthException($code): $message';
}
