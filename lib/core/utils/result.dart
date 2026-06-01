import 'package:schooldesk1/core/errors/failures.dart';

/// A simple Result type — either a [Success] with data or a [Failure].
/// Replaces `Either<Failure, T>` without requiring dartz package.
///
/// Usage:
/// ```dart
/// Result<List<Student>> result = await repo.getStudents();
/// result.when(
///   success: (students) => setState(() => _students = students),
///   failure: (f) => setState(() => _error = f.message),
/// );
/// ```
sealed class Result<T> {
  const Result();

  const factory Result.ok(T data) = Success<T>;
  const factory Result.err(Failure failure) = ResultFailure<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is ResultFailure<T>;

  T? get dataOrNull => isSuccess ? (this as Success<T>).data : null;
  Failure? get failureOrNull =>
      isFailure ? (this as ResultFailure<T>).failure : null;

  R when<R>({
    required R Function(T data) success,
    required R Function(Failure failure) failure,
  }) {
    if (this is Success<T>) return success((this as Success<T>).data);
    return failure((this as ResultFailure<T>).failure);
  }
}

final class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

final class ResultFailure<T> extends Result<T> {
  final Failure failure;
  const ResultFailure(this.failure);
}
