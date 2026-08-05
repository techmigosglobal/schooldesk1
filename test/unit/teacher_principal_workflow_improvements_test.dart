import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teacher dashboard exposes a task-based today action queue', () {
    final source = File(
      'lib/features/dashboard/presentation/screens/teacher_dashboard_screen/teacher_dashboard_screen.dart',
    ).readAsStringSync();

    expect(source, contains('Today Action Queue'));
    expect(source, contains('_teacherActionQueue'));
    expect(source, contains('Mark Student Attendance'));
    expect(source, contains('Track Leave'));
  });

  test('teacher dashboard exposes leave as a separate quick action', () {
    final source = File(
      'lib/features/dashboard/presentation/screens/teacher_dashboard_screen/teacher_dashboard_screen.dart',
    ).readAsStringSync();

    expect(source, contains("'Leaves'"));
    expect(source, contains("'Apply and track'"));
    expect(source, contains('AppRoutes.teacherLeave'));
  });

  test('principal dashboard exposes an oversight action queue', () {
    final source = File(
      'lib/features/dashboard/presentation/screens/principal_dashboard_screen/principal_dashboard_screen.dart',
    ).readAsStringSync();

    expect(source, contains('Principal Action Queue'));
    expect(source, contains('_principalActionQueue'));
    expect(source, isNot(contains("_SectionTitle('Today')")));
    expect(source, isNot(contains('_TodaySnapshotRow')));
    expect(source, contains('Review Attendance'));
    expect(source, contains("'Approvals'"));
    expect(source, contains('School Posts'));
    expect(source, contains('Fee Requests'));
    expect(source, contains('Access Approvals'));
  });

  test('teacher and principal navigation use clear communication labels', () {
    final teacherNav = File(
      'lib/core/widgets/teacher_navigation.dart',
    ).readAsStringSync();
    final teacherFlow = File(
      'lib/core/widgets/teacher_flow_ui.dart',
    ).readAsStringSync();
    final principalNav = File(
      'lib/core/widgets/app_navigation.dart',
    ).readAsStringSync();
    final principalDashboard = File(
      'lib/features/dashboard/presentation/screens/principal_dashboard_screen/principal_dashboard_screen.dart',
    ).readAsStringSync();

    expect(teacherNav, contains("label: 'Communication'"));
    expect(teacherNav, contains("label: 'PTM Slots'"));
    expect(teacherFlow, contains('showBackButton: false'));
    expect(principalNav, isNot(contains("label: 'Broadcasts & Notices'")));
    expect(principalNav, contains("label: 'Messages & Chats'"));
    expect(principalDashboard, contains("label: 'Messages & Chats'"));
    expect(principalDashboard, isNot(contains("label: 'Chat Communications'")));
  });

  test('role handoffs expose clear empty states and approval routes', () {
    final teacherDashboard = File(
      'lib/features/dashboard/presentation/screens/teacher_dashboard_screen/teacher_dashboard_screen.dart',
    ).readAsStringSync();
    final teacherAttendance = File(
      'lib/features/attendance/presentation/screens/teacher_attendance_screen/teacher_attendance_screen.dart',
    ).readAsStringSync();
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final guard = File('lib/routes/route_access_guard.dart').readAsStringSync();
    final teacherNav = File(
      'lib/core/widgets/teacher_navigation.dart',
    ).readAsStringSync();
    final principalNav = File(
      'lib/core/widgets/app_navigation.dart',
    ).readAsStringSync();

    expect(teacherDashboard, contains('No classes assigned yet.'));
    expect(
      teacherDashboard,
      contains('attendance workflow will appear after assignment'),
    );
    expect(
      teacherAttendance,
      contains(
        'Please contact Admin/Principal to set your class teacher assignment.',
      ),
    );
    expect(teacherAttendance, contains('Request Correction'));
    expect(principalNav, contains("label: 'School Posts'"));
    expect(principalNav, isNot(contains("label: 'School Posts Approval'")));
    expect(principalNav, isNot(contains("label: 'School Feed Posts'")));
    expect(teacherNav, contains("label: 'Event Posts'"));
    expect(routes, contains('TeacherEventPostScreen'));
    expect(routes, contains('SchoolPostsRouteArgs'));
    expect(guard, contains("AppRoutes.teacherEventPosts: {'teacher'}"));
    expect(guard, contains("AppRoutes.principalEventApprovals: {'principal'}"));
  });
}
