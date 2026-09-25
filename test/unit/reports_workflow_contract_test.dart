import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'principal reports use the correct drawer destination and preview flow',
    () {
      final source = File(
        'lib/features/reports/presentation/screens/reports_analytics_screen/reports_analytics_screen.dart',
      ).readAsStringSync();

      expect(source, contains('PrincipalNav.reports'));
      expect(source, contains('_generateAndPreviewReport'));
      expect(source, contains('pdfService.previewDocument'));
      expect(source, isNot(contains('Printing.layoutPdf')));
    },
  );

  test('staff report rows distinguish approved leave from absence', () {
    final source = File(
      'lib/features/reports/presentation/screens/reports_analytics_screen/reports_analytics_screen.dart',
    ).readAsStringSync();

    expect(source, contains('_repository.loadApprovedLeaveApplications'));
    expect(source, contains('_staffOnLeaveIds'));
    expect(source, contains("'On leave'"));
  });

  test('attendance navigation exposes monitor and reports views', () {
    final source = File(
      'lib/features/attendance/presentation/screens/principal_attendance_screen/principal_attendance_screen.dart',
    ).readAsStringSync();

    expect(source, contains('_AttendanceView.monitor => _monitorView()'));
    expect(source, contains('_AttendanceView.reports => _reportsView()'));
  });
}
