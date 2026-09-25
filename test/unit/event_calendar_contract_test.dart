import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('event form posts backend datetime fields and preserves day lookup', () {
    final source = File(
      'lib/features/calendar/presentation/screens/events_calendar_screen/events_calendar_screen.dart',
    ).readAsStringSync();

    expect(source, contains("'start_datetime':"));
    expect(source, contains("'end_datetime':"));
    expect(source, isNot(contains("createRaw('/events', payload)")));
    expect(source, contains('widget.repository.createEvent'));
    expect(source, contains('event.overlapsDate(day)'));
    expect(
      source,
      contains("import 'package:table_calendar/table_calendar.dart';"),
    );
    expect(source, contains('TableCalendar<_PrincipalEvent>('));
    expect(source, contains("_EventsDisplayMode.agenda"));
    expect(source, contains('_buildSelectedDayAgenda()'));
    expect(source, contains('_buildFilters()'));
    expect(source, contains("label: Text('Agenda')"));
    expect(source, contains("message: 'Go to today'"));
    final repository = File(
      'lib/modules/calendar/data/api_calendar_repository.dart',
    ).readAsStringSync();
    expect(repository, contains('createEventPayload'));
  });

  test('event api creates events with the Go /events contract', () {
    final api = File(
      'lib/core/network/api_modules/events_api.dart',
    ).readAsStringSync();

    expect(api, contains('Future<void> createEventPayload('));
    expect(api, contains("'event_title':"));
    expect(api, contains("'start_datetime':"));
    expect(api, contains("'end_datetime':"));
    expect(api, contains("_dio.post('/events'"));
  });
}
