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
    expect(source, contains('BackendApiClient.instance.createEventPayload'));
    expect(source, contains('event.overlapsDate(day)'));
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
