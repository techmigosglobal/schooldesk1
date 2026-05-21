import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/core/errors/failures.dart';

void main() {
  group('Result<T>', () {
    group('Result.ok()', () {
      test('creates a Success result', () {
        final result = Result.ok('hello');
        expect(result.isSuccess, isTrue);
        expect(result.isFailure, isFalse);
      });

      test('dataOrNull returns data', () {
        final result = Result.ok(42);
        expect(result.dataOrNull, 42);
      });

      test('failureOrNull returns null for success', () {
        final result = Result.ok('data');
        expect(result.failureOrNull, isNull);
      });
    });

    group('Result.err()', () {
      test('creates a ResultFailure', () {
        final result = Result<String>.err(const NetworkFailure());
        expect(result.isSuccess, isFalse);
        expect(result.isFailure, isTrue);
      });

      test('dataOrNull returns null for failure', () {
        final result = Result<int>.err(const CacheFailure());
        expect(result.dataOrNull, isNull);
      });

      test('failureOrNull returns failure', () {
        const failure = NetworkFailure();
        final result = Result<String>.err(failure);
        expect(result.failureOrNull, isA<NetworkFailure>());
      });
    });

    group('when()', () {
      test('calls success callback on success', () {
        final result = Result.ok(100);
        final value = result.when(
          success: (data) => data * 2,
          failure: (_) => -1,
        );
        expect(value, 200);
      });

      test('calls failure callback on failure', () {
        final result = Result<int>.err(const NetworkFailure());
        final value = result.when(success: (data) => data, failure: (f) => -1);
        expect(value, -1);
      });

      test('success callback receives correct data', () {
        final result = Result.ok(['a', 'b', 'c']);
        result.when(
          success: (data) {
            expect(data.length, 3);
            expect(data.first, 'a');
          },
          failure: (_) => fail('Should not call failure'),
        );
      });

      test('failure callback receives correct failure type', () {
        const failure = ValidationFailure(message: 'Test error');
        final result = Result<String>.err(failure);
        result.when(
          success: (_) => fail('Should not call success'),
          failure: (f) {
            expect(f, isA<ValidationFailure>());
            expect(f.message, 'Test error');
          },
        );
      });
    });

    group('with complex types', () {
      test('works with List<Map>', () {
        final data = [
          {'id': '1', 'name': 'Test'},
        ];
        final result = Result.ok(data);
        expect(result.isSuccess, isTrue);
        expect(result.dataOrNull?.length, 1);
      });

      test('works with void/null', () {
        final result = Result.ok(null);
        expect(result.isSuccess, isTrue);
      });
    });
  });
}
