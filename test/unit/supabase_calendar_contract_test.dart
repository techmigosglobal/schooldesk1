import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('principal calendar no longer offers seeded demo calendar loading', () {
    final source = File(
      'lib/features/calendar/presentation/screens/events_calendar_screen/events_calendar_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('Load 2026–27 school calendar')));
    expect(source, isNot(contains('_SchoolCalendarData')));
    expect(source, contains("'/parent-teacher-meetings'"));
    expect(source, contains('_PrincipalEvent.fromPtmApi'));
  });

  test('supabase gateway exposes real calendar and ptm handlers', () {
    final index = File('supabase/functions/api/index.ts').readAsStringSync();
    final calendar = File(
      'supabase/functions/api/handlers/calendar.ts',
    ).readAsStringSync();
    final communications = File(
      'supabase/functions/api/handlers/communications.ts',
    ).readAsStringSync();

    expect(index, contains('handleCalendar'));
    expect(index, contains('path.startsWith("/events")'));
    expect(index, contains('path.startsWith("/parent-teacher-meetings")'));
    expect(calendar, contains('svc.from("events")'));
    expect(calendar, contains('svc.from("holidays")'));
    expect(calendar, contains('["principal"].includes(roleName(user))'));
    expect(calendar, contains('return fail("forbidden", 403)'));
    expect(communications, contains('parent_teacher_meetings'));
    expect(communications, contains('/parent-teacher-meetings'));
  });

  test('calendar uses one visual surface for every role and limits creation', () {
    final source = File(
      'lib/features/calendar/presentation/screens/events_calendar_screen/events_calendar_screen.dart',
    ).readAsStringSync();

    expect(source, contains('_buildSharedCalendar()'));
    expect(source, contains('SchoolDeskModuleScaffold('));
    expect(source, contains('floatingActionButton: _canManageEvents'));
    expect(source, contains("label: const Text('Create event')"));
    expect(source, contains('_buildCalendarSummary()'));
  });
}
