import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/services/pdf_service.dart';

int _pageCount(List<int> bytes) => RegExp(
  r'/Type\s*/Page\b',
).allMatches(latin1.decode(bytes, allowInvalid: true)).length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('generates a structured report PDF with real report sections', (
    tester,
  ) async {
    final bytes = await PdfService.getInstance().generateStructuredReport(
      reportTitle: 'Attendance Report',
      period: 'August 2026',
      scope: 'Arish Ville - branch-scoped report',
      schoolName: 'Arish Ville',
      schoolAddress: 'Branch address',
      metrics: const [
        {'label': 'Students', 'value': '62'},
        {'label': 'Average', 'value': '88.4%'},
      ],
      tables: const [
        {
          'title': 'Attendance by class / section',
          'headers': ['Class / section', 'Students', 'Present', 'Attendance'],
          'rows': [
            ['Playgroup - A', '12', '11', '91.7%'],
          ],
          'weights': [2.3, 1, 1, 1.2],
        },
      ],
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  testWidgets('paginates large structured report tables', (tester) async {
    final rows = List<List<String>>.generate(
      90,
      (index) => [
        'Student ${index + 1}',
        'Class ${(index % 8) + 1} - Section ${index % 3 + 1}',
        '${20 + index}',
        '${18 + index}',
        '${(90 + index % 10).toStringAsFixed(1)}%',
      ],
    );

    final bytes = await PdfService.getInstance().generateStructuredReport(
      reportTitle: 'Large Attendance Report',
      period: 'August 2026',
      scope: 'All classes',
      metrics: const [
        {'label': 'Rows', 'value': '90'},
      ],
      tables: [
        {
          'title': 'Attendance by class / section',
          'headers': const [
            'Student',
            'Class / section',
            'Total',
            'Present',
            'Attendance',
          ],
          'rows': rows,
          'weights': const [2, 2, 1, 1, 1.2],
        },
      ],
    );

    expect(_pageCount(bytes), greaterThan(1));
  });

  testWidgets('paginates large attendance and directory PDFs', (tester) async {
    final report = PdfService.getInstance();
    final attendanceRows = List<Map<String, dynamic>>.generate(
      90,
      (index) => {
        'name': 'Student ${index + 1}',
        'present': 20,
        'absent': 2,
        'total': 22,
        'percentage': 90.9,
      },
    );
    final directoryRows = List<Map<String, String>>.generate(
      90,
      (index) => {
        'name': 'Student ${index + 1}',
        'admission': 'ADM-${index + 1}',
        'systemId': 'STU-${1000 + index}',
        'classSection': 'Grade ${(index % 8) + 1} - A',
        'gender': index.isEven ? 'Female' : 'Male',
        'dateOfBirth': '01 Jan 2015',
        'status': 'Active',
      },
    );

    final attendance = await report.generateAttendanceReport(
      className: 'Grade 8 - A',
      month: 'August 2026',
      students: attendanceRows,
    );
    final directory = await report.generateStudentDirectoryReport(
      title: 'Student Directory',
      students: directoryRows,
    );

    expect(_pageCount(attendance), greaterThan(1));
    expect(_pageCount(directory), greaterThan(1));
  });
}
