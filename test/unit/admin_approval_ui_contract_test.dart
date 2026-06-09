import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin dashboard surfaces approval states and preparation actions', () {
    final dashboard = _read(
      'lib/features/dashboard/presentation/screens/admin_dashboard_screen/admin_dashboard_screen.dart',
    );

    expect(dashboard, contains('getApprovalRequests()'));
    expect(dashboard, contains('Pending submissions'));
    expect(dashboard, contains('Changes requested'));
    expect(dashboard, contains('Recently approved/rejected'));
    expect(dashboard, contains('Prepare Student Request'));
    expect(dashboard, contains('Submit Notice for Approval'));
    expect(dashboard, contains('Prepare staff request'));
    expect(dashboard, contains('Submit fee request'));
    expect(dashboard, contains('Submit timetable request'));
    expect(dashboard, isNot(contains('Create Student')));
    expect(dashboard, isNot(contains('Publish Timetable')));
  });

  test('admin student controls submit approval requests instead of final labels', () {
    final students = _read(
      'lib/features/people/presentation/screens/admin_students_screen/admin_students_screen.dart',
    );

    expect(students, contains("createRaw('/student-approvals'"));
    expect(students, contains('Prepare Student Request'));
    expect(students, contains('Submit Student for Approval'));
    expect(students, contains('Submit Update for Approval'));
    expect(students, contains('Submit Removal for Approval'));
    expect(students, contains('Submit Promotion for Approval'));
    expect(students, isNot(contains('Request Delete')));
    expect(students, isNot(contains('Request student')));
    expect(students, isNot(contains('Send Request')));
  });

  test('admin staff update and removal submit backend approval requests', () {
    final staff = _read(
      'lib/features/people/presentation/screens/staff_management_screen/staff_management_screen.dart',
    );

    expect(staff, contains('requestPrincipalApproval: _isAdminOwner'));
    expect(staff, contains('createApprovalRequest'));
    expect(staff, contains('submitApprovalRequest'));
    expect(staff, contains("module: 'staff'"));
    expect(staff, contains("operationType: 'update'"));
    expect(staff, contains("operationType: 'delete'"));
    expect(staff, contains('Prepare Staff Request'));
    expect(staff, contains('Submit Staff Update for Approval'));
    expect(staff, contains('Submit Staff Removal for Approval'));
  });

  test('admin finance controls use request language', () {
    final fees = _read(
      'lib/features/finance/presentation/screens/admin_fees_screen/admin_fees_screen.dart',
    );
    final feeForms = _read(
      'lib/features/finance/presentation/screens/admin_fees_screen/admin_fee_form_screens.dart',
    );
    final combined = '$fees\n$feeForms';

    expect(combined, contains('Prepare Fee Structure Request'));
    expect(combined, contains('Submit Fee Structure for Approval'));
    expect(combined, contains('Submit Invoice Request'));
    expect(combined, contains('Submit Invoices for Approval'));
    expect(combined, contains('Submit Payment Request'));
    expect(combined, contains('Submit Payment for Approval'));
    expect(combined, isNot(contains("label: const Text('Create')")));
    expect(combined, isNot(contains('Save structure')));
    expect(combined, isNot(contains('Generate invoices')));
    expect(combined, isNot(contains('Record payment')));
  });

  test('admin scoped sources do not expose final decision buttons', () {
    final sources = [
      'lib/features/dashboard/presentation/screens/admin_dashboard_screen/admin_dashboard_screen.dart',
      'lib/features/people/presentation/screens/admin_students_screen/admin_students_screen.dart',
      'lib/features/people/presentation/screens/staff_management_screen/staff_management_screen.dart',
      'lib/features/finance/presentation/screens/admin_fees_screen/admin_fees_screen.dart',
      'lib/features/finance/presentation/screens/admin_fees_screen/admin_fee_form_screens.dart',
      'lib/features/finance/presentation/screens/admin_fees_screen/admin_payment_request_decision_screen.dart',
    ].map(_read).join('\n');

    for (final label in ['Approve', 'Reject', 'Apply']) {
      expect(sources, isNot(contains("label: const Text('$label')")));
      expect(sources, isNot(contains("child: const Text('$label')")));
      expect(sources, isNot(contains("label: Text('$label')")));
      expect(sources, isNot(contains("child: Text('$label')")));
    }
  });
}

String _read(String path) => File(path).readAsStringSync();
