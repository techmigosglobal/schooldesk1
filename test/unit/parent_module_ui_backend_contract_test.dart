import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parent module routes are visible through the temporary route gate', () {
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();

    expect(routes, contains('_roleWorkflowVisibleRoutes'));
    expect(routes, contains('!metadata.isShared'));
    for (final route in const [
      'parentDashboard',
      'parentAcademicProgress',
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
      expect(routes, contains('$route,'));
    }
  });

  test('parent module screens stay backed by live APIs', () {
    final dashboard = File(
      'lib/presentation/parent_dashboard_screen/parent_dashboard_screen.dart',
    ).readAsStringSync();
    final attendance = File(
      'lib/presentation/parent_attendance_screen/parent_attendance_screen.dart',
    ).readAsStringSync();
    final homework = File(
      'lib/presentation/parent_homework_screen/parent_homework_screen.dart',
    ).readAsStringSync();
    final homeworkSubmit = File(
      'lib/presentation/parent_homework_screen/parent_homework_submission_screen.dart',
    ).readAsStringSync();
    final fees = File(
      'lib/presentation/parent_fees_screen/parent_fees_screen.dart',
    ).readAsStringSync();
    final progress = File(
      'lib/presentation/parent_academic_progress_screen/parent_academic_progress_screen.dart',
    ).readAsStringSync();
    final leaveForm = File(
      'lib/presentation/parent_leave_screen/parent_leave_request_form_screen.dart',
    ).readAsStringSync();

    expect(dashboard, contains("api.getDashboard('parent')"));
    expect(dashboard, contains('api.getMyStudents()'));
    expect(attendance, contains('getStudentAttendanceSummary'));
    expect(attendance, isNot(contains('statusMap')));
    expect(homework, contains('getHomework('));
    expect(homework, contains('getHomeworkSubmissions('));
    expect(homeworkSubmit, contains('submitHomework('));
    expect(fees, contains('getInvoices(studentId: studentId)'));
    expect(fees, contains('getParentPaymentRequests('));
    expect(progress, contains("'/students/\$studentId/marks'"));
    expect(progress, contains("'/exams/report-cards'"));
    expect(leaveForm, contains('getLeaveTypes()'));
    expect(leaveForm, isNot(contains('static const _leaveTypes')));
  });

  test('parent frontend records are scoped to the current parent user', () {
    final frontendRecord = File(
      'school-backend/internal/handlers/frontend_record.go',
    ).readAsStringSync();
    final main = File('school-backend/main.go').readAsStringSync();

    expect(frontendRecord, contains('parentOwnsRecords'));
    expect(frontendRecord, contains('"notice-acknowledgements"'));
    expect(frontendRecord, contains('"documents/access-requests"'));
    expect(frontendRecord, contains('"certificates/requests"'));
    expect(frontendRecord, contains('created_by = ?'));
    expect(
      main,
      contains(
        'frontendResource("/notice-acknowledgements", "Admin", "Principal", "Teacher", "Parent")',
      ),
    );
    expect(
      main,
      contains(
        'frontendResource("/documents/access-requests", "Admin", "Principal", "Parent")',
      ),
    );
  });
}
