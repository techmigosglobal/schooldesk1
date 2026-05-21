import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('report exports use typed lifecycle with generated artifacts', () {
    final api = File('lib/services/backend_api_client.dart').readAsStringSync();
    final adminReports = File(
      'lib/presentation/admin_reports_screen/admin_reports_screen.dart',
    ).readAsStringSync();
    final principalReports = File(
      'lib/presentation/reports_analytics_screen/reports_analytics_screen.dart',
    ).readAsStringSync();
    final adminAttendance = File(
      'lib/presentation/admin_attendance_screen/admin_attendance_screen.dart',
    ).readAsStringSync();
    final adminFees = File(
      'lib/presentation/admin_fees_screen/admin_fees_screen.dart',
    ).readAsStringSync();
    final teacherReports = File(
      'lib/presentation/teacher_reports_screen/teacher_reports_screen.dart',
    ).readAsStringSync();
    final parentProgress = File(
      'lib/presentation/parent_academic_progress_screen/parent_academic_progress_screen.dart',
    ).readAsStringSync();
    final reportCardGenerator = File(
      'lib/presentation/report_card_generator_screen/report_card_generator_screen.dart',
    ).readAsStringSync();
    final syllabus = File(
      'lib/presentation/syllabus_monitoring_screen/syllabus_monitoring_screen.dart',
    ).readAsStringSync();
    final studentOversight = File(
      'lib/presentation/student_oversight_screen/student_oversight_screen.dart',
    ).readAsStringSync();
    final main = File('school-backend/main.go').readAsStringSync();
    final model = File(
      'school-backend/internal/models/report_export.go',
    ).readAsStringSync();
    final handler = File(
      'school-backend/internal/handlers/report_export.go',
    ).readAsStringSync();

    expect(api, contains('Future<Map<String, dynamic>> createReportExport'));
    expect(
      api,
      contains('Future<List<Map<String, dynamic>>> getReportExports'),
    );

    for (final source in [
      adminReports,
      principalReports,
      adminAttendance,
      adminFees,
      teacherReports,
      parentProgress,
      reportCardGenerator,
      syllabus,
      studentOversight,
    ]) {
      expect(source, contains('createReportExport('));
    }
    expect(reportCardGenerator, contains("'/exams/report-cards/exports'"));
    expect(reportCardGenerator, contains('report_card_bulk'));
    expect(adminReports, isNot(contains('download_done_rounded')));
    expect(adminReports, isNot(contains('exported as \$format successfully')));

    expect(model, contains('type ReportExport struct'));
    expect(model, contains('ArtifactPath'));
    expect(model, contains('DownloadURL'));
    expect(handler, contains('func (h *ReportExportHandler) Create'));
    expect(handler, contains('writeReportArtifact'));
    expect(handler, contains('Status:        "processing"'));
    expect(handler, contains('row.Status = "completed"'));
    expect(handler, contains('row.Status = "failed"'));

    expect(main, contains('NewReportExportHandler()'));
    expect(main, contains('reportExportHandler.Create("general_reports")'));
    expect(main, contains('reportExportHandler.Create("student_reports")'));
    expect(main, contains('reportExportHandler.Create("attendance_reports")'));
    expect(main, contains('reportExportHandler.Create("fee_reports")'));
    expect(main, contains('reportExportHandler.Create("report_cards")'));
    expect(
      main,
      isNot(contains('NewFrontendRecordHandler("fees/reports/exports")')),
    );
    expect(
      main,
      isNot(contains('NewFrontendRecordHandler("exams/report-cards/exports")')),
    );
  });
}
