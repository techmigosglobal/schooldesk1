/// App-level exceptions — thrown in the Data layer, caught and mapped to Failures.
library;

class NetworkException implements Exception {
  final String message;
  final int? statusCode;

  const NetworkException({
    this.message = 'Network error occurred.',
    this.statusCode,
  });

  @override
  String toString() => 'NetworkException($statusCode): $message';
}

class ServerException implements Exception {
  final String message;
  final int? statusCode;

  const ServerException({required this.message, this.statusCode});

  @override
  String toString() => 'ServerException($statusCode): $message';
}

class CacheException implements Exception {
  final String message;

  const CacheException({this.message = 'Cache operation failed.'});

  @override
  String toString() => 'CacheException: $message';
}

class ValidationException implements Exception {
  final String message;
  final Map<String, String>? fieldErrors;

  const ValidationException({required this.message, this.fieldErrors});

  @override
  String toString() => 'ValidationException: $message';
}

class AuthException implements Exception {
  final String message;

  const AuthException({this.message = 'Authentication failed.'});

  @override
  String toString() => 'AuthException: $message';
}

class NotFoundException implements Exception {
  final String message;

  const NotFoundException({this.message = 'Resource not found.'});

  @override
  String toString() => 'NotFoundException: $message';
}
