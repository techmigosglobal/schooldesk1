import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('exam results report cards and student progress routes stay retired', () {
    final routeSources = [
      read('lib/routes/app_routes.dart'),
      read('lib/routes/route_access_guard.dart'),
      read('lib/routes/schooldesk_screen_registry.dart'),
      read('lib/app/module_registry.dart'),
    ].join('\n');
    final navigationSources = [
      read('lib/core/widgets/parent_navigation.dart'),
      read('lib/core/widgets/teacher_navigation.dart'),
      read(
        'lib/features/dashboard/presentation/screens/teacher_dashboard_screen/teacher_dashboard_screen.dart',
      ),
    ].join('\n');
    final apiSources = [
      read('lib/core/network/generated/schooldesk_api_client.dart'),
      read('lib/core/network/api_modules/events_api.dart'),
      read('lib/core/network/api_modules/principal_api.dart'),
    ].join('\n');
    final backendRoutes = [
      read('school-backend/internal/routes/routes.go'),
      read('school-backend/internal/routes/principal_routes.go'),
    ].join('\n');

    expect(routeSources, isNot(contains('reportCardGenerator')));
    expect(routeSources, isNot(contains('teacherReports')));
    expect(routeSources, isNot(contains('teacherPerformance')));
    expect(routeSources, isNot(contains('parentAcademicProgress')));
    expect(routeSources, isNot(contains('/report-card-generator-screen')));
    expect(routeSources, isNot(contains('/teacher-reports-screen')));
    expect(routeSources, isNot(contains('/teacher-performance-screen')));
    expect(routeSources, isNot(contains('/parent-academic-progress-screen')));

    expect(navigationSources, isNot(contains('Academic Progress')));
    expect(navigationSources, isNot(contains('Student Performance')));
    expect(navigationSources, isNot(contains('teacherReports')));

    expect(apiSources, isNot(contains("'/exams")));
    expect(apiSources, isNot(contains('"/exams')));
    expect(apiSources, isNot(contains('/principal/exams')));
    expect(apiSources, isNot(contains('/principal/results')));
    expect(apiSources, isNot(contains('getExams(')));
    expect(apiSources, isNot(contains('getExamTypes(')));
    expect(apiSources, isNot(contains('createExam(')));
    expect(apiSources, isNot(contains('updateExam(')));
    expect(apiSources, isNot(contains('setExamPublished(')));
    expect(apiSources, isNot(contains('reportCards(')));

    expect(backendRoutes, isNot(contains('api.Group("/exams")')));
    expect(backendRoutes, isNot(contains('students.GET("/:id/marks"')));
    expect(backendRoutes, isNot(contains('students.GET("/:id/progress"')));
    expect(backendRoutes, isNot(contains('principal.GET("/exams"')));
    expect(backendRoutes, isNot(contains('principal.GET("/results"')));
    expect(backendRoutes, isNot(contains('/exam-schedule')));
  });

  test('parent calendar and reports analytics no longer surface exam tabs', () {
    final parentCalendar = read(
      'lib/features/calendar/presentation/screens/parent_calendar_screen/parent_calendar_screen.dart',
    );
    final reportsAnalytics = read(
      'lib/features/reports/presentation/screens/reports_analytics_screen/reports_analytics_screen.dart',
    );
    final adminReports = read(
      'lib/features/reports/presentation/screens/admin_reports_screen/admin_reports_screen.dart',
    );

    expect(parentCalendar, contains('api.getEvents()'));
    expect(parentCalendar, contains("api.getRawList('/parent-teacher-meetings')"));
    expect(parentCalendar, isNot(contains('api.getExams()')));
    expect(parentCalendar, isNot(contains("Tab(text: 'Exams')")));

    expect(reportsAnalytics, isNot(contains("Tab(text: 'Exam')")));
    expect(reportsAnalytics, isNot(contains('_buildExamTab')));
    expect(reportsAnalytics, isNot(contains('Exam Results Report')));

    expect(adminReports, isNot(contains('Report Card Generator')));
    expect(adminReports, isNot(contains('reportCardGenerator')));
  });
}
