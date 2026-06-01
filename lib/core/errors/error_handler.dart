import 'dart:io';

import 'package:schooldesk1/core/errors/failures.dart';
import 'package:schooldesk1/core/errors/exceptions.dart';

/// Centralized error handler — maps exceptions to typed Failures.
/// Use in repository implementations inside catch blocks.
class ErrorHandler {
  ErrorHandler._();

  /// Maps any exception to a [Failure].
  static Failure handle(Object error) {
    if (error is NetworkException) {
      return NetworkFailure(
        message: error.message,
        code: error.statusCode?.toString(),
      );
    }
    if (error is ServerException) {
      return ServerFailure(
        message: error.message,
        code: error.statusCode?.toString(),
      );
    }
    if (error is CacheException) {
      return CacheFailure(message: error.message);
    }
    if (error is ValidationException) {
      return ValidationFailure(message: error.message);
    }
    if (error is AuthException) {
      return AuthFailure(message: error.message);
    }
    if (error is NotFoundException) {
      return NotFoundFailure(message: error.message);
    }
    if (error is SocketException) {
      return const NetworkFailure();
    }
    if (error is FormatException) {
      return const CacheFailure(
        message: 'Data format error. Please try again.',
      );
    }
    return UnknownFailure(message: error.toString());
  }

  /// Returns a user-friendly message for a [Failure].
  static String userMessage(Failure failure) {
    if (failure is NetworkFailure) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (failure is ServerFailure) return failure.message;
    if (failure is CacheFailure) {
      return 'Could not load saved data. Please restart the app.';
    }
    if (failure is ValidationFailure) return failure.message;
    if (failure is AuthFailure) return 'Session expired. Please log in again.';
    if (failure is NotFoundFailure) {
      return 'The requested information was not found.';
    }
    if (failure is PermissionFailure) {
      return 'You do not have permission for this action.';
    }
    return 'Something went wrong. Please try again.';
  }
}
