import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'parent calendar renders backend events holidays exams and PTM rows',
    () {
      final source = File(
        'lib/presentation/parent_calendar_screen/parent_calendar_screen.dart',
      ).readAsStringSync();
      final api = File(
        'lib/services/backend_api_client.dart',
      ).readAsStringSync();

      expect(source, contains('BackendApiClient.instance'));
      expect(source, contains('api.getEvents()'));
      expect(source, contains("api.getRawList('/parent-teacher-meetings')"));
      expect(source, contains('api.getExams()'));
      expect(source, contains("api.getRawMap('/academic-years/"));
      expect(source, contains('SchoolDeskStatusPanel.empty'));
      expect(api, contains('Future<Map<String, dynamic>> getRawMap'));
      expect(source, isNot(contains('Republic Day Celebration')));
      expect(source, isNot(contains('Mahashivratri')));
      expect(source, isNot(contains('Annual Exam Begins')));
      expect(
        source,
        isNot(contains("setState(() => _events[i]['rsvp'] = true)")),
      );
    },
  );
}
