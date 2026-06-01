import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/features/shared/data/models/api_contracts.dart'
    as contracts;

void main() {
  test('login contract matches the live username-based auth payload', () {
    expect(
      const contracts.LoginRequest(
        username: 'teacher01',
        password: 'secret123',
      ).toJson(),
      {'username': 'teacher01', 'password': 'secret123'},
    );
    expect(
      const contracts.LoginRequest(
        username: 'principal',
        password: 'secret123',
      ).toJson(),
      {
        'username': 'principal',
        'email': 'principal@schooldesk.local',
        'password': 'secret123',
      },
    );
  });

  test('student create contract uses scoped backend fields', () {
    final payload = const contracts.CreateStudentRequest(
      firstName: 'Asha',
      lastName: 'Rao',
      dateOfBirth: '2012-01-01',
      gender: 'female',
      admissionNumber: 'ADM-101',
      studentCode: 'STU-101',
      currentSectionId: 'section-1',
    ).toJson();

    expect(payload['first_name'], 'Asha');
    expect(payload['last_name'], 'Rao');
    expect(payload['current_section_id'], 'section-1');
    expect(payload, isNot(containsPair('name', 'Asha Rao')));
    expect(payload, isNot(contains('class_name')));
    expect(payload, isNot(contains('parent_name')));
    expect(payload, isNot(contains('school_id')));
  });

  test('attendance fee and leave contracts match live handlers', () {
    expect(
      const contracts.MarkAttendanceRequest(
        sessionId: 'session-1',
        attendances: [
          contracts.AttendanceEntryRequest(
            studentId: 'student-1',
            enrollmentId: 'enrollment-1',
            status: 'present',
          ),
        ],
      ).toJson(),
      {
        'attendances': [
          {
            'student_id': 'student-1',
            'enrollment_id': 'enrollment-1',
            'status': 'present',
          },
        ],
      },
    );
    expect(
      const contracts.RecordPaymentRequest(
        invoiceId: 'invoice-1',
        receiptNumber: 'REC-1',
        amountPaid: 500,
        paymentDate: '2026-05-30',
        paymentMode: 'cash',
      ).toJson(),
      {
        'invoice_id': 'invoice-1',
        'receipt_number': 'REC-1',
        'amount_paid': 500.0,
        'payment_date': '2026-05-30',
        'payment_mode': 'cash',
      },
    );
    expect(
      const contracts.SubmitLeaveRequest(
        staffId: 'staff-1',
        leaveTypeId: 'leave-type-1',
        fromDate: '2026-05-30',
        toDate: '2026-05-31',
      ).toJson(),
      {
        'staff_id': 'staff-1',
        'leave_type_id': 'leave-type-1',
        'from_date': '2026-05-30',
        'to_date': '2026-05-31',
        'half_day': false,
      },
    );
  });
}
