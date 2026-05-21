import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('role frontends do not contain audited demo/static workflow data', () {
    final bannedStrings = <String>[
      'Aarav',
      'Zoya',
      'teacher_verma',
      'Rahul Verma',
      'Public High School',
      'admin123',
      '₹22,000 Due',
      '₹50/month penalty',
      'Term 3 fee payment pending',
      'Worksheet downloaded!',
      'Report card downloaded!',
      'downloaded!',
      'PDF exported',
      'CSV exported',
      'assigned as substitute',
      'pending principal approval',
      "'640'",
      "'87.4%'",
      "'89.3%'",
      "'94.5%'",
      "'47'",
      "final weekData = [",
      "final classData = [",
      'Mrs. Anita Sharma',
      'Class Teacher — 5-A',
      'badgeCount: 3',
      'badgeCount: 2',
      'BackendDataService.kTeacherSyllabus',
      'BackendDataService.kTeacherWeeklyPlan',
      'BackendDataService.kTeacherNotes',
      'BackendDataService.kSharedPtmMeetings',
      'BackendDataService.kSharedDisciplineIncidents',
      'BackendDataService.kSharedSchoolNotices',
      "/ (cls['strength'] as int)",
    ];

    final frontendFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) {
          final path = file.path;
          return path.endsWith('.dart') &&
              (path.contains('/presentation/') ||
                  path.contains('/routes/') ||
                  path.contains('/widgets/'));
        });

    final findings = <String>[];
    for (final file in frontendFiles) {
      final content = file.readAsStringSync();
      for (final banned in bannedStrings) {
        if (content.contains(banned)) {
          findings.add('${file.path}: contains "$banned"');
        }
      }
    }

    expect(findings, isEmpty, reason: findings.join('\n'));
  });
}
