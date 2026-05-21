import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/features/shared/domain/entities/fee_record.dart';

void main() {
  group('FeeRecord Entity', () {
    final testFee = FeeRecord(
      id: 'fee_001',
      studentId: 'stu_001',
      studentName: 'Arjun Sharma',
      className: 'Class 10',
      feeType: 'Tuition Fee',
      amount: 15000,
      paidAmount: 10000,
      dueDate: DateTime(2025, 4, 30),
      status: 'Partial',
    );

    test('creates fee record with required fields', () {
      expect(testFee.id, 'fee_001');
      expect(testFee.amount, 15000);
      expect(testFee.paidAmount, 10000);
    });

    group('pendingAmount', () {
      test('calculates correct pending amount', () {
        expect(testFee.pendingAmount, 5000);
      });

      test('pending amount is zero when fully paid', () {
        final paid = testFee.copyWith(paidAmount: 15000, status: 'Paid');
        expect(paid.pendingAmount, 0);
      });
    });

    group('isOverdue', () {
      test('returns true for overdue status', () {
        final overdue = testFee.copyWith(status: 'Overdue');
        expect(overdue.isOverdue, isTrue);
      });

      test('returns true for pending with past due date', () {
        final pastDue = testFee.copyWith(
          status: 'Pending',
          dueDate: DateTime(2020, 1, 1),
        );
        expect(pastDue.isOverdue, isTrue);
      });

      test('returns false for paid fee', () {
        final paid = testFee.copyWith(status: 'Paid');
        expect(paid.isOverdue, isFalse);
      });

      test('returns false for pending with future due date', () {
        final future = testFee.copyWith(
          status: 'Pending',
          dueDate: DateTime.now().add(const Duration(days: 30)),
        );
        expect(future.isOverdue, isFalse);
      });
    });

    group('copyWith()', () {
      test('updates payment info', () {
        final updated = testFee.copyWith(
          paidAmount: 15000,
          status: 'Paid',
          paidDate: DateTime(2025, 4, 25),
          receiptNumber: 'RCP001',
          paymentMode: 'Online',
        );
        expect(updated.paidAmount, 15000);
        expect(updated.status, 'Paid');
        expect(updated.receiptNumber, 'RCP001');
        expect(updated.id, testFee.id); // unchanged
      });
    });

    group('equality', () {
      test('same id means equal', () {
        final copy = testFee.copyWith(paidAmount: 5000);
        expect(testFee, equals(copy));
      });
    });
  });
}
