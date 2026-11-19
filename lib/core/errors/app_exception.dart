/// Base exception for all application-layer errors.
class AppException implements Exception {
  final String message;
  final String? code;
  final Object? cause;

  const AppException(this.message, {this.code, this.cause});

  @override
  String toString() => 'AppException($code): $message';
}

/// Thrown by service methods when a backend/database operation fails.
class ServiceException extends AppException {
  const ServiceException(super.message, {super.code, super.cause});

  @override
  String toString() => 'ServiceException($code): $message';
}

/// Thrown by auth service methods when an authentication operation fails.
class AuthAppException extends AppException {
  const AuthAppException(super.message, {super.code, super.cause});

  @override
  String toString() => 'AuthAppException($code): $message';
}
