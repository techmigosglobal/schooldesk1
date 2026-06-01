import 'package:schooldesk1/core/errors/exceptions.dart';
import 'package:schooldesk1/core/errors/failures.dart';
import 'package:schooldesk1/core/utils/result.dart';

Future<Result<T>> guardApi<T>(Future<T> Function() action) async {
  try {
    return Result.ok(await action());
  } catch (error) {
    return Result.err(failureFrom(error));
  }
}

Failure failureFrom(Object error) {
  return switch (error) {
    NetworkException(:final message) => NetworkFailure(message: message),
    ServerException(:final message, :final statusCode) => ServerFailure(
      message: message,
      code: statusCode?.toString(),
    ),
    CacheException(:final message) => CacheFailure(message: message),
    ValidationException(:final message) => ValidationFailure(message: message),
    AuthException(:final message) => AuthFailure(message: message),
    NotFoundException(:final message) => NotFoundFailure(message: message),
    _ => UnknownFailure(message: error.toString()),
  };
}

DateTime parseDate(Object? value, {DateTime? fallback}) {
  final parsed = DateTime.tryParse('${value ?? ''}');
  return parsed ?? fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
}

String textValue(Object? value) => value?.toString().trim() ?? '';

double doubleValue(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(textValue(value)) ?? 0;
}
