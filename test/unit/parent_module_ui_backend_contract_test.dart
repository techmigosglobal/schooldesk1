import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'backend_api_sources.dart';

import 'backend_route_sources.dart';

void main() {
  test('parent module routes are visible through the temporary route gate', () {
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();

    for (final route in const [
      'parentDashboard',
      'parentAttendance',
      'parentHomework',
      'parentHomeworkSubmit',
      'parentNotices',
      'parentTeacherChat',
      'parentFees',
      'parentPaymentRequestForm',
      'feePaymentReceipt',
      'parentLeave',
      'parentLeaveRequestForm',
      'parentCalendar',
      'parentDocuments',
      'parentDiary',
      'parentAcademicInfo',
    ]) {
      expect(routes, contains('static const String $route'));
      expect(routes, contains('$route:'));
    }
  });

  test('parent module screens stay backed by live APIs', () {
    final dashboard = File(
      'lib/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart',
    ).readAsStringSync();
    final attendance = File(
      'lib/features/attendance/presentation/screens/parent_attendance_screen/parent_attendance_screen.dart',
    ).readAsStringSync();
    final homework = File(
      'lib/features/homework/presentation/screens/parent_homework_screen/parent_homework_screen.dart',
    ).readAsStringSync();
    final homeworkSubmit = File(
      'lib/features/homework/presentation/screens/parent_homework_screen/parent_homework_submission_screen.dart',
    ).readAsStringSync();
    final fees = File(
      'lib/features/finance/presentation/screens/parent_fees_screen/parent_fees_screen.dart',
    ).readAsStringSync();
    final leaveForm = File(
      'lib/features/leave/presentation/screens/parent_leave_screen/parent_leave_request_form_screen.dart',
    ).readAsStringSync();
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();

    expect(dashboard, contains("api.getDashboard('parent')"));
    expect(dashboard, contains('api.getMyStudents()'));
    expect(attendance, contains('getStudentAttendanceSummary'));
    expect(attendance, isNot(contains('statusMap')));
    expect(homework, contains('getHomework('));
    expect(homework, contains('getHomeworkSubmissions('));
    expect(homeworkSubmit, contains('submitHomework('));
    expect(fees, contains('getInvoices(studentId: studentId)'));
    expect(fees, contains('getParentPaymentRequests('));
    expect(routes, isNot(contains('parentAcademicProgress')));
    expect(leaveForm, contains('getLeaveTypes()'));
    expect(leaveForm, isNot(contains('static const _leaveTypes')));
  });

  test('parent dashboard puts media-rich school feed before utility actions', () {
    final dashboard = File(
      'lib/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart',
    ).readAsStringSync();

    final feedIndex = dashboard.indexOf(
      '_SchoolFeedList(eventPosts: eventPosts)',
    );
    final summaryIndex = dashboard.indexOf(
      '_ParentSummaryGrid(dashboard: dashboard, child: activeChild)',
    );
    final shortcutsIndex = dashboard.indexOf(
      'const _ParentWorkflowShortcuts()',
    );

    expect(feedIndex, isNonNegative);
    expect(summaryIndex, isNonNegative);
    expect(shortcutsIndex, isNonNegative);
    expect(feedIndex, lessThan(summaryIndex));
    expect(feedIndex, lessThan(shortcutsIndex));
    expect(dashboard, contains("'media_urls': ev['media_urls']"));
    expect(dashboard, contains('_eventPostMediaUrls'));
    expect(dashboard, contains('_eventPostMediaType'));
    expect(dashboard, contains('_SchoolFeedMediaPreview'));
  });

  test('parent portal root does not expose stack back to login', () {
    final dashboard = File(
      'lib/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart',
    ).readAsStringSync();
    final scaffold = File(
      'lib/core/widgets/erp_module_scaffold.dart',
    ).readAsStringSync();

    expect(dashboard, contains('isPortalRoot: true'));
    expect(dashboard, contains('fallbackRoute: AppRoutes.parentDashboard'));
    expect(scaffold, contains('final bool isPortalRoot;'));
    expect(scaffold, contains('final String? fallbackRoute;'));
    expect(scaffold, contains('final bool showBackButton;'));
    expect(scaffold, contains('canNavigateBack'));
    expect(scaffold, contains('_handleBackPressed'));
    expect(scaffold, contains('PopScope('));
    expect(scaffold, contains('canPop: !widget.isPortalRoot'));
    expect(scaffold, contains('pushNamedAndRemoveUntil'));
  });

  test('parent child summaries surface backend operational fields', () {
    final api = readBackendApiSources();
    final data = File(
      'lib/core/services/backend_data_service.dart',
    ).readAsStringSync();
    final parentLinks = File(
      'school-backend/internal/handlers/parent_link.go',
    ).readAsStringSync();

    expect(
      parentLinks,
      contains('studentResponseRows(database.DB, schoolID, students)'),
    );
    expect(
      parentLinks,
      contains('Preload("Student.CurrentSection.ClassTeacher")'),
    );
    expect(api, contains('_parentStudentDashboardMap'));
    expect(
      api,
      isNot(contains("row['attendance'] = row['attendance'] ?? 'N/A'")),
    );
    expect(
      api,
      isNot(
        contains("row['classTeacher'] = row['classTeacher'] ?? 'Not assigned'"),
      ),
    );
    expect(data, contains("'photo': student.photoUrl"));
    expect(data, contains("'rollNo': student.admissionNumber.isNotEmpty"));
    expect(data, contains("'attendance': student.attendancePercent"));
    expect(data, contains("'feesDue': student.feeBalance"));
    expect(data, contains("'classTeacher': classTeacherName"));
  });

  test('parent frontend records are scoped to the current parent user', () {
    final frontendRecord = File(
      'school-backend/internal/handlers/frontend_record.go',
    ).readAsStringSync();
    final main = readBackendRouteSources();

    expect(frontendRecord, contains('parentOwnsRecords'));
    expect(frontendRecord, contains('"notice-acknowledgements"'));
    expect(frontendRecord, contains('"documents/access-requests"'));
    expect(frontendRecord, contains('"certificates/requests"'));
    expect(frontendRecord, contains('created_by = ?'));
    expect(
      main,
      contains(
        'frontendResource("/notice-acknowledgements", "Principal", "Teacher", "Parent")',
      ),
    );
    expect(
      main,
      contains(
        'frontendResource("/documents/access-requests", "Principal", "Parent")',
      ),
    );
  });
}
