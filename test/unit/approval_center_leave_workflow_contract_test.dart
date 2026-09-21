import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/features/people/presentation/screens/approval_center_screen/approval_center_screen.dart';

void main() {
  test('approval center consumes leave notification route context', () {
    final args = ApprovalCenterRouteArgs.fromRoute({
      'referenceType': 'student_leave',
      'referenceId': 'leave-123',
      'initialTab': 'leave',
    });

    expect(args.referenceType, 'student_leave');
    expect(args.initialApprovalId, 'leave-123');
    expect(args.initialTab, 'leave');
  });

  test('student leave decision schema and API persist complete metadata', () {
    final migration = File(
      'supabase/migrations/20260716154313_student_leave_decision_metadata.sql',
    ).readAsStringSync();
    final routeBackfill = File(
      'supabase/migrations/20260716154926_leave_notification_approval_routes.sql',
    ).readAsStringSync();
    final leaveHandler = File(
      'supabase/functions/api/handlers/leave.ts',
    ).readAsStringSync();

    expect(migration, contains('rejection_reason text'));
    expect(migration, contains('decided_at timestamptz'));
    expect(leaveHandler, contains('decided_at: new Date().toISOString()'));
    expect(leaveHandler, contains('route: "/approval-center-screen"'));
    expect(leaveHandler, contains('reference_id: data.id'));
    expect(
      routeBackfill,
      contains("entity_type in ('leave', 'student_leave')"),
    );
    expect(routeBackfill, contains("route = '/approval-center-screen'"));
  });

  test('approval center hydrates requesters by ID and preserves API fields', () {
    final screen = File(
      'lib/features/people/presentation/screens/approval_center_screen/approval_center_screen.dart',
    ).readAsStringSync();
    final approvalsHandler = File(
      'supabase/functions/api/handlers/approvals.ts',
    ).readAsStringSync();

    expect(screen, isNot(contains("path: '/class-approvals'")));
    expect(screen, isNot(contains("path: '/student-approvals'")));
    expect(screen, isNot(contains("path: '/timetable/approvals'")));
    expect(
      approvalsHandler,
      contains('accountUsersById.get(text(row.user_id))'),
    );
    expect(approvalsHandler, contains('requesterName: text(userRow.name'));
    expect(approvalsHandler, contains('requesterRole: text(userRow.role_name'));
    expect(
      approvalsHandler,
      contains('user: usersById.get(text(row.user_id))'),
    );
    expect(approvalsHandler, contains('start_date, end_date, reason'));
    expect(approvalsHandler, isNot(contains('from_date, to_date')));
  });
}
