import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('homework daily claims resolve legacy academic years safely', () {
    final handler = File(
      'supabase/functions/api/handlers/homework.ts',
    ).readAsStringSync();
    final claims = File(
      'supabase/functions/api/handlers/daily_claims.ts',
    ).readAsStringSync();
    final helper = File(
      'supabase/functions/api/lib/homework_legacy.ts',
    ).readAsStringSync();

    expect(handler, contains('async function homeworkAcademicYearId'));
    expect(handler, contains('async function loadHomeworkDailyClaim'));
    expect(handler, contains('sectionAcademicYear'));
    expect(handler, contains('isUuid(storedYearId) ? storedYearId : ""'));
    expect(handler, contains('loadHomeworkDailyClaim(svc, school, row)'));
    expect(handler, contains('loadHomeworkDailyClaim(svc, school, existing)'));
    expect(handler, contains('loadHomeworkDailyClaim(svc, school, homework)'));
    expect(
      handler,
      contains('assignment.isClassTeacher || assignment.isCoTeacher'),
    );
    expect(handler, contains('teacherCanUseSubject'));
    expect(claims, contains('!isUuid(academicYearId)'));
    expect(claims, contains('return null;'));
    expect(helper, contains('UUID_PATTERN'));
    expect(helper, contains('ISO_DATE_PATTERN'));
  });

  test('homework migration backfills only missing values and preserves rows', () {
    final migration = File(
      'supabase/migrations/20260815120000_backfill_legacy_homework_academic_year.sql',
    ).readAsStringSync();
    final smoke = File(
      'supabase/tests/homework_legacy_academic_year_smoke.sql',
    ).readAsStringSync();

    expect(migration, contains("fr.table_name = 'homework'"));
    expect(migration, contains('jsonb_set'));
    expect(
      migration,
      contains("nullif(fr.data->>'academic_year_id', '') is null"),
    );
    expect(migration, contains('sec.academic_year_id is not null'));
    expect(migration, isNot(contains('delete from')));
    expect(smoke, contains('missing_count'));
    expect(smoke, contains('sec.academic_year_id is not null'));
  });
}
