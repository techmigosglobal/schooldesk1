import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('staff attendance summary only selects columns that exist on staff', () {
    final handler = File(
      'supabase/functions/api/handlers/attendance.ts',
    ).readAsStringSync();
    final schema = File(
      'supabase/migrations/0002_people_auth_schema.sql',
    ).readAsStringSync();
    final staffSchema = schema.substring(
      schema.indexOf('create table public.staff'),
      schema.indexOf('create table public.staff_qualifications'),
    );

    expect(handler, contains('path === "/attendance/staff/daily-summary"'));
    expect(handler, contains('svc.from("staff").select("id")'));
    expect(staffSchema, contains('first_name'));
    expect(staffSchema, contains('last_name'));
    expect(staffSchema, isNot(contains('full_name')));
    expect(
      handler,
      isNot(contains('id, first_name, last_name, full_name, staff_code')),
    );
  });
}
