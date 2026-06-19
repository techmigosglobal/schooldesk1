import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/constants/schooldesk_glossary.dart';
import 'package:schooldesk1/routes/schooldesk_screen_registry.dart';

void main() {
  test('principal registry titles use canonical glossary labels', () {
    final expectedTitles = <String, String>{
      '/student-oversight-screen': SchoolDeskGlossary.studentOversight,
      '/staff-management-screen': SchoolDeskGlossary.staffOversight,
      '/communication-center-screen': SchoolDeskGlossary.communicationCenter,
      '/complaint-management-screen': SchoolDeskGlossary.complaints,
      '/events-calendar-screen': SchoolDeskGlossary.calendar,
      '/reports-analytics-screen': SchoolDeskGlossary.reports,
      '/principal-analytics-screen': SchoolDeskGlossary.analytics,
      '/id-card-generation-screen': SchoolDeskGlossary.idCards,
    };

    for (final entry in expectedTitles.entries) {
      expect(
        SchoolDeskScreenRegistry.byRoute(entry.key)?.title,
        entry.value,
        reason: 'Registry title drifted for ${entry.key}',
      );
    }
  });

  test('role-facing screens avoid old mixed terminology', () {
    final oldTerms = <String>[
      'Student Management',
      'Student Administration',
      'Staff Management',
      'Teacher & Staff',
      'Fees & Finance',
      'Exam Administration',
      'Timetable & Scheduling',
      'Timetable Management',
      'Syllabus Monitoring',
      'Exams & Results',
      'Complaints & Grievances',
      'Reports & Analytics',
      'Reports & Compliance',
      'Analytics Dashboard',
      'Parent Helpdesk',
      'Documents & Certs',
      'Documents & Certificates',
      'User & Access',
      'ID Card Generation',
      'Events & Calendar',
      'Fee Management',
      'Create, assign, and request student record changes for Principal approval',
      'Create staff profiles and send account changes for Principal approval',
    ];
    final sourceFiles = <String>[
      ..._dartFilesUnder('lib/features'),
      ..._dartFilesUnder('lib/core/widgets'),
      'lib/routes/schooldesk_screen_registry.dart',
    ];

    for (final path in sourceFiles) {
      final source = File(path).readAsStringSync();
      for (final term in oldTerms) {
        if (path.endsWith('principal_dashboard_screen.dart') &&
            term == 'Staff Management') {
          continue;
        }
        expect(source, isNot(contains(term)), reason: '$term found in $path');
      }
    }
  });
}

List<String> _dartFilesUnder(String path) {
  return Directory(path)
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.path)
      .toList();
}
