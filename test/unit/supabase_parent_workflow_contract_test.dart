import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Supabase gateway dispatches parent homework routes', () {
    final index = File('supabase/functions/api/index.ts').readAsStringSync();
    final homework = File(
      'supabase/functions/api/handlers/homework.ts',
    ).readAsStringSync();
    final api = File(
      'lib/core/network/api_modules/homework_api.dart',
    ).readAsStringSync();

    expect(index, contains('handleHomework'));
    expect(index, contains('path.startsWith("/homework")'));
    expect(homework, contains('path === "/homework"'));
    expect(homework, contains('suffix === "submissions"'));
    expect(homework, contains('const reviewMatch = suffix.match'));
    expect(homework, contains('svc.from("homework_submissions")'));
    expect(homework, contains('table_name", "homework"'));
    expect(homework, contains('parentCanAccessStudent'));
    expect(api, contains('Future<List<Map<String, dynamic>>> getHomework'));
    expect(api, contains('Future<Map<String, dynamic>> submitHomework'));
  });

  test('parent timetable uses child section with Supabase timetable slots', () {
    final source = File(
      'lib/features/academics/presentation/screens/parent_timetable_screen/parent_timetable_screen.dart',
    ).readAsStringSync();
    final timetable = File(
      'supabase/functions/api/handlers/timetable.ts',
    ).readAsStringSync();

    expect(source, contains('getTimetableSlots('));
    expect(source, contains("child['current_section_id']"));
    expect(source, isNot(contains('/me/timetable?student_id=')));
    expect(timetable, contains('url.searchParams.get("section_id")'));
  });

  test('parent health migration keeps reminder fields in medical records', () {
    final migration = File(
      'supabase/migrations/0010_parent_health_homework_contracts.sql',
    ).readAsStringSync();

    expect(migration, contains('add column if not exists dosage'));
    expect(migration, contains('add column if not exists reminder_time'));
    expect(migration, contains('idx_homework_submissions_lookup'));
  });
}
