import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/utils/validators.dart';

void main() {
  group('AppValidators', () {
    // ─── required ────────────────────────────────────────────────────────────
    group('required()', () {
      test('returns null for non-empty string', () {
        expect(AppValidators.required('Hello'), isNull);
      });

      test('returns error for null value', () {
        expect(AppValidators.required(null), isNotNull);
      });

      test('returns error for empty string', () {
        expect(AppValidators.required(''), isNotNull);
      });

      test('returns error for whitespace-only string', () {
        expect(AppValidators.required('   '), isNotNull);
      });

      test('uses custom field name in error message', () {
        final error = AppValidators.required('', fieldName: 'Student Name');
        expect(error, contains('Student Name'));
      });
    });

    // ─── email ────────────────────────────────────────────────────────────────
    group('email()', () {
      test('returns null for valid email', () {
        expect(AppValidators.email('test@example.com'), isNull);
        expect(AppValidators.email('user.name+tag@domain.co.in'), isNull);
      });

      test('returns error for invalid email', () {
        expect(AppValidators.email('notanemail'), isNotNull);
        expect(AppValidators.email('missing@'), isNotNull);
        expect(AppValidators.email('@nodomain.com'), isNotNull);
      });

      test('returns error for empty email', () {
        expect(AppValidators.email(''), isNotNull);
        expect(AppValidators.email(null), isNotNull);
      });
    });

    // ─── password ─────────────────────────────────────────────────────────────
    group('password()', () {
      test('returns null for valid password (6+ chars)', () {
        expect(AppValidators.password('Secure@123'), isNull);
        expect(AppValidators.password('abcdef'), isNull);
      });

      test('returns error for short password', () {
        expect(AppValidators.password('abc'), isNotNull);
        expect(AppValidators.password('12345'), isNotNull);
      });

      test('returns error for empty password', () {
        expect(AppValidators.password(''), isNotNull);
        expect(AppValidators.password(null), isNotNull);
      });
    });

    // ─── phone ────────────────────────────────────────────────────────────────
    group('phone()', () {
      test('returns null for valid phone numbers', () {
        expect(AppValidators.phone('9876543210'), isNull);
        expect(AppValidators.phone('+919876543210'), isNull);
      });

      test('returns error for invalid phone', () {
        expect(AppValidators.phone('123'), isNotNull);
        expect(AppValidators.phone('abcdefghij'), isNotNull);
      });

      test('returns error for empty phone', () {
        expect(AppValidators.phone(''), isNotNull);
        expect(AppValidators.phone(null), isNotNull);
      });
    });

    // ─── numeric ──────────────────────────────────────────────────────────────
    group('numeric()', () {
      test('returns null for valid numbers', () {
        expect(AppValidators.numeric('100'), isNull);
        expect(AppValidators.numeric('99.99'), isNull);
        expect(AppValidators.numeric('0'), isNull);
      });

      test('returns error for non-numeric strings', () {
        expect(AppValidators.numeric('abc'), isNotNull);
        expect(AppValidators.numeric('12.34.56'), isNotNull);
      });
    });

    // ─── positiveNumber ───────────────────────────────────────────────────────
    group('positiveNumber()', () {
      test('returns null for positive numbers', () {
        expect(AppValidators.positiveNumber('1'), isNull);
        expect(AppValidators.positiveNumber('1000.50'), isNull);
      });

      test('returns error for zero or negative', () {
        expect(AppValidators.positiveNumber('0'), isNotNull);
        expect(AppValidators.positiveNumber('-5'), isNotNull);
      });
    });

    // ─── minLength ────────────────────────────────────────────────────────────
    group('minLength()', () {
      test('returns null when length meets minimum', () {
        expect(AppValidators.minLength('Hello World', 5), isNull);
        expect(AppValidators.minLength('abc', 3), isNull);
      });

      test('returns error when length below minimum', () {
        expect(AppValidators.minLength('Hi', 5), isNotNull);
      });
    });
  });
}
