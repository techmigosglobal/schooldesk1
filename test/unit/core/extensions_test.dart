import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

void main() {
  group('StringExtensions', () {
    group('capitalize', () {
      test('capitalizes first letter', () {
        expect('hello'.capitalize, 'Hello');
        expect('world'.capitalize, 'World');
      });

      test('handles empty string', () {
        expect(''.capitalize, '');
      });

      test('handles already capitalized', () {
        expect('Hello'.capitalize, 'Hello');
      });
    });

    group('titleCase', () {
      test('capitalizes each word', () {
        expect('hello world'.titleCase, 'Hello World');
        expect('john doe smith'.titleCase, 'John Doe Smith');
      });
    });

    group('isValidEmail', () {
      test('returns true for valid email', () {
        expect('test@example.com'.isValidEmail, isTrue);
        expect('user@domain.co.in'.isValidEmail, isTrue);
      });

      test('returns false for invalid email', () {
        expect('notanemail'.isValidEmail, isFalse);
        expect('missing@'.isValidEmail, isFalse);
      });
    });

    group('isValidPhone', () {
      test('returns true for valid phone', () {
        expect('9876543210'.isValidPhone, isTrue);
        expect('+919876543210'.isValidPhone, isTrue);
      });

      test('returns false for invalid phone', () {
        expect('123'.isValidPhone, isFalse);
        expect('abcdefghij'.isValidPhone, isFalse);
      });
    });

    group('truncate', () {
      test('truncates long strings', () {
        expect('Hello World'.truncate(5), 'Hello...');
      });

      test('does not truncate short strings', () {
        expect('Hi'.truncate(10), 'Hi');
      });
    });
  });

  group('DateTimeExtensions', () {
    final testDate = DateTime(2025, 4, 15, 14, 30);

    group('formattedDate', () {
      test('formats date correctly', () {
        expect(testDate.formattedDate, '15 Apr 2025');
      });
    });

    group('isoDate', () {
      test('returns ISO date string', () {
        expect(testDate.isoDate, '2025-04-15');
      });
    });

    group('isToday', () {
      test('returns true for today', () {
        expect(DateTime.now().isToday, isTrue);
      });

      test('returns false for past date', () {
        expect(DateTime(2020, 1, 1).isToday, isFalse);
      });
    });

    group('isPast', () {
      test('returns true for past date', () {
        expect(DateTime(2020, 1, 1).isPast, isTrue);
      });

      test('returns false for future date', () {
        expect(DateTime.now().add(const Duration(days: 1)).isPast, isFalse);
      });
    });
  });

  group('DoubleExtensions', () {
    group('currency', () {
      test('formats as Indian rupee', () {
        expect((1500.50).currency, '₹1500.50');
      });
    });

    group('currencyCompact', () {
      test('formats lakhs', () {
        expect((150000.0).currencyCompact, '₹1.5L');
      });

      test('formats thousands', () {
        expect((5000.0).currencyCompact, '₹5.0K');
      });

      test('formats small amounts', () {
        expect((500.0).currencyCompact, '₹500');
      });
    });

    group('percentage', () {
      test('formats as percentage', () {
        expect((87.5).percentage, '87.5%');
      });
    });
  });

  group('IntExtensions', () {
    group('ordinal', () {
      test('formats 1st, 2nd, 3rd correctly', () {
        expect(1.ordinal, '1st');
        expect(2.ordinal, '2nd');
        expect(3.ordinal, '3rd');
        expect(4.ordinal, '4th');
        expect(11.ordinal, '11th');
        expect(12.ordinal, '12th');
        expect(21.ordinal, '21st');
      });
    });
  });
}
