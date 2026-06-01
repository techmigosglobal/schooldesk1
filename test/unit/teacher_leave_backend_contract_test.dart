import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'backend_api_sources.dart';

import 'backend_route_sources.dart';

void main() {
  test('teacher leave uses routed form with real backend staff and leave ids', () {
    final screen = File(
      'lib/features/leave/presentation/screens/teacher_leave_screen/teacher_leave_screen.dart',
    ).readAsStringSync();
    final form = File(
      'lib/features/leave/presentation/screens/teacher_leave_screen/teacher_leave_request_form_screen.dart',
    ).readAsStringSync();
    final api = readBackendApiSources();
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final guard = File('lib/routes/route_access_guard.dart').readAsStringSync();
    final registry = File(
      'lib/routes/schooldesk_screen_registry.dart',
    ).readAsStringSync();
    final main = readBackendRouteSources();

    expect(screen, contains('AppRoutes.teacherLeaveRequestForm'));
    expect(screen, contains("getDashboard('teacher')"));
    expect(screen, contains('getLeaveTypes()'));
    expect(screen, contains('getLeaveBalances(staffId: staffId)'));
    expect(screen, contains('getLeaveApplications(staffId: staffId)'));
    expect(screen, isNot(contains('showModalBottomSheet(')));
    expect(screen, isNot(contains("staff_id': 'self'")));
    expect(screen, isNot(contains('NotificationService')));

    expect(form, contains('TeacherLeaveRequestFormScreen'));
    expect(form, contains('submitLeaveApplication('));
    expect(form, contains('LeaveApplicationRequest('));
    expect(form, contains('staffId: widget.args.staffId'));
    expect(form, contains('leaveTypeId: _leaveTypeId'));
    expect(form, contains('halfDay: _halfDay'));
    expect(form, isNot(contains('substituteCtrl')));
    expect(form, isNot(contains('showModalBottomSheet(')));

    expect(api, contains('Future<List<Map<String, dynamic>>> getLeaveTypes()'));
    expect(
      api,
      contains('Future<List<Map<String, dynamic>>> getLeaveBalances'),
    );
    expect(routes, contains('teacherLeaveRequestForm'));
    expect(routes, contains('TeacherLeaveRequestFormScreen'));
    expect(guard, contains('AppRoutes.teacherLeaveRequestForm: {\'teacher\'}'));
    expect(registry, contains('/teacher-leave-screen/request'));
    expect(main, contains('leave.GET("/balances"'));
  });
}
