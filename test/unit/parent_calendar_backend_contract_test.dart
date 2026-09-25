import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parent calendar renders backend events and holidays only', () {
    final source = File(
      'lib/features/calendar/presentation/screens/parent_calendar_screen/parent_calendar_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/roles/parent/data/api_parent_calendar_repository.dart',
    ).readAsStringSync();

    expect(source, contains('_repository.loadEvents'));
    expect(source, isNot(contains('BackendApiClient.instance')));
    expect(
      source,
      isNot(contains("api.getRawList('/parent-teacher-meetings')")),
    );
    expect(source, isNot(contains('api.getExams()')));
    expect(source, isNot(contains("Tab(text: 'Exams')")));
    expect(source, contains('_repository.loadAcademicYear'));
    expect(source, contains('SchoolDeskStatusPanel.empty'));
    expect(repository, contains('getAcademicYears'));
    expect(repository, contains('getEvents'));
    expect(source, isNot(contains('Republic Day Celebration')));
    expect(source, isNot(contains('Mahashivratri')));
    expect(source, isNot(contains('Annual Exam Begins')));
    expect(
      source,
      isNot(contains("setState(() => _events[i]['rsvp'] = true)")),
    );
  });

  test('principal event calendar preserves selected local event dates', () {
    final source = File(
      'lib/features/calendar/presentation/screens/events_calendar_screen/events_calendar_screen.dart',
    ).readAsStringSync();
    final api = File(
      'lib/core/network/api_modules/events_api.dart',
    ).readAsStringSync();

    expect(source, contains('final start = _eventDateTime(row, true)'));
    expect(source, contains('final end ='));
    expect(source, contains('_eventDateTime(row, false)'));
    expect(source, contains('final date = DateTime.tryParse(dateText)'));
    expect(source, contains('DateTime.tryParse(_clean(row[dateTimeKey]))'));
    expect(source, contains('String _formatRfc3339(DateTime date)'));
    expect(source, isNot(contains('date.toUtc().toIso8601String()')));
    expect(api, contains("'start_datetime': start.toIso8601String()"));
    expect(api, contains("'end_datetime': end.toIso8601String()"));
  });
}
