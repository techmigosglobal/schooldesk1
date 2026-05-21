import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/errors/failures.dart';
import 'package:schooldesk1/core/errors/exceptions.dart';
import 'package:schooldesk1/core/errors/error_handler.dart';

void main() {
  group('Failure Models', () {
    test('NetworkFailure has default message', () {
      const failure = NetworkFailure();
      expect(failure.message, isNotEmpty);
    });

    test('ServerFailure stores custom message', () {
      const failure = ServerFailure(
        message: 'Internal Server Error',
        code: '500',
      );
      expect(failure.message, 'Internal Server Error');
      expect(failure.code, '500');
    });

    test('ValidationFailure stores message', () {
      const failure = ValidationFailure(message: 'Email is required.');
      expect(failure.message, 'Email is required.');
    });

    test('AuthFailure has default message', () {
      const failure = AuthFailure();
      expect(failure.message, isNotEmpty);
    });

    test('CacheFailure has default message', () {
      const failure = CacheFailure();
      expect(failure.message, isNotEmpty);
    });

    test('NotFoundFailure has default message', () {
      const failure = NotFoundFailure();
      expect(failure.message, isNotEmpty);
    });

    test('UnknownFailure has default message', () {
      const failure = UnknownFailure();
      expect(failure.message, isNotEmpty);
    });
  });

  group('ErrorHandler.handle()', () {
    test('maps NetworkException to NetworkFailure', () {
      final failure = ErrorHandler.handle(const NetworkException());
      expect(failure, isA<NetworkFailure>());
    });

    test('maps ServerException to ServerFailure', () {
      final failure = ErrorHandler.handle(
        const ServerException(message: 'Bad Gateway', statusCode: 502),
      );
      expect(failure, isA<ServerFailure>());
      expect(failure.message, 'Bad Gateway');
    });

    test('maps CacheException to CacheFailure', () {
      final failure = ErrorHandler.handle(const CacheException());
      expect(failure, isA<CacheFailure>());
    });

    test('maps ValidationException to ValidationFailure', () {
      final failure = ErrorHandler.handle(
        const ValidationException(message: 'Invalid input'),
      );
      expect(failure, isA<ValidationFailure>());
    });

    test('maps AuthException to AuthFailure', () {
      final failure = ErrorHandler.handle(const AuthException());
      expect(failure, isA<AuthFailure>());
    });

    test('maps NotFoundException to NotFoundFailure', () {
      final failure = ErrorHandler.handle(const NotFoundException());
      expect(failure, isA<NotFoundFailure>());
    });

    test('maps unknown exception to UnknownFailure', () {
      final failure = ErrorHandler.handle(Exception('Some random error'));
      expect(failure, isA<UnknownFailure>());
    });

    test('maps FormatException to CacheFailure', () {
      final failure = ErrorHandler.handle(const FormatException('bad format'));
      expect(failure, isA<CacheFailure>());
    });
  });

  group('ErrorHandler.userMessage()', () {
    test('returns friendly message for NetworkFailure', () {
      const failure = NetworkFailure();
      final msg = ErrorHandler.userMessage(failure);
      expect(msg, isNotEmpty);
      expect(msg.toLowerCase(), contains('internet'));
    });

    test('returns server message for ServerFailure', () {
      const failure = ServerFailure(message: 'Custom server error');
      final msg = ErrorHandler.userMessage(failure);
      expect(msg, 'Custom server error');
    });

    test('returns friendly message for AuthFailure', () {
      const failure = AuthFailure();
      final msg = ErrorHandler.userMessage(failure);
      expect(msg.toLowerCase(), contains('session'));
    });

    test('returns validation message for ValidationFailure', () {
      const failure = ValidationFailure(message: 'Email is required');
      final msg = ErrorHandler.userMessage(failure);
      expect(msg, 'Email is required');
    });
  });
}
