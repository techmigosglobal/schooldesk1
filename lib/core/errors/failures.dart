/// Centralized Failure models — Domain layer error representation.
/// All repository methods return `Either<Failure, T>` to propagate errors cleanly.
abstract class Failure {
  final String message;
  final String? code;

  const Failure({required this.message, this.code});

  @override
  String toString() => 'Failure(message: $message, code: $code)';
}

/// Network / HTTP failures
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'No internet connection. Please check your network.',
    super.code,
  });
}

/// Server-side failures (4xx / 5xx)
class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code});
}

/// Local cache / storage failures
class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Failed to read or write local data.',
    super.code,
  });
}

/// Validation failures (form input, business rules)
class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.code});
}

/// Authentication failures
class AuthFailure extends Failure {
  const AuthFailure({
    super.message = 'Authentication failed. Please log in again.',
    super.code,
  });
}

/// Not found failures
class NotFoundFailure extends Failure {
  const NotFoundFailure({
    super.message = 'The requested resource was not found.',
    super.code,
  });
}

/// Permission / authorization failures
class PermissionFailure extends Failure {
  const PermissionFailure({
    super.message = 'You do not have permission to perform this action.',
    super.code,
  });
}

/// Unknown / unexpected failures
class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'An unexpected error occurred. Please try again.',
    super.code,
  });
}
