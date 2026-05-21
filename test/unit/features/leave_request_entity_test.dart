import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/features/shared/domain/entities/leave_request.dart';

void main() {
  group('LeaveRequest Entity', () {
    final testRequest = LeaveRequest(
      id: 'leave_001',
      requesterId: 'teacher_001',
      requesterName: 'Ms. Priya Nair',
      requesterRole: 'teacher',
      leaveType: 'Sick',
      fromDate: DateTime(2025, 4, 20),
      toDate: DateTime(2025, 4, 22),
      reason: 'Medical appointment',
      submittedAt: DateTime(2025, 4, 18),
    );

    test('creates leave request with required fields', () {
      expect(testRequest.id, 'leave_001');
      expect(testRequest.requesterName, 'Ms. Priya Nair');
      expect(testRequest.leaveType, 'Sick');
    });

    test('default status is Pending', () {
      expect(testRequest.status, 'Pending');
    });

    group('durationDays', () {
      test('calculates correct duration', () {
        // April 20 to April 22 = 3 days (inclusive)
        expect(testRequest.durationDays, 3);
      });

      test('single day leave has duration 1', () {
        final singleDay = testRequest.copyWith(
          fromDate: DateTime(2025, 4, 20),
          toDate: DateTime(2025, 4, 20),
        );
        expect(singleDay.durationDays, 1);
      });
    });

    group('copyWith()', () {
      test('updates status to Approved', () {
        final approved = testRequest.copyWith(
          status: 'Approved',
          approvedBy: 'Principal',
          reviewedAt: DateTime(2025, 4, 19),
        );
        expect(approved.status, 'Approved');
        expect(approved.approvedBy, 'Principal');
        expect(approved.id, testRequest.id); // unchanged
      });

      test('updates status to Rejected with remark', () {
        final rejected = testRequest.copyWith(
          status: 'Rejected',
          rejectionRemark: 'Insufficient notice period',
        );
        expect(rejected.status, 'Rejected');
        expect(rejected.rejectionRemark, 'Insufficient notice period');
      });
    });

    group('equality', () {
      test('same id means equal', () {
        final copy = testRequest.copyWith(reason: 'Different reason');
        expect(testRequest, equals(copy));
      });

      test('different id means not equal', () {
        final other = testRequest.copyWith(id: 'leave_999');
        expect(testRequest, isNot(equals(other)));
      });
    });
  });
}
