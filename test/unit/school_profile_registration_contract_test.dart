import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('school profile uses the real registration_no database column', () {
    final screen = File(
      'lib/features/profile/presentation/screens/school_profile_screen/school_profile_screen.dart',
    ).readAsStringSync();
    final dashboard = File(
      'lib/features/dashboard/presentation/screens/principal_dashboard_screen/principal_dashboard_screen.dart',
    ).readAsStringSync();

    expect(screen, contains("school['registration_no']"));
    expect(
      screen,
      contains("'registration_no': _registrationCtrl.text.trim()"),
    );
    expect(screen, isNot(contains("'registration_number': _registrationCtrl")));
    expect(dashboard, contains("school['registration_no']"));
  });

  test('school API accepts the legacy registration key without writing it', () {
    final handler = File(
      'supabase/functions/api/handlers/schools.ts',
    ).readAsStringSync();

    expect(handler, contains('const { registration_number, ...updates }'));
    expect(handler, contains('updates.registration_no = registration_number'));
    expect(
      handler,
      contains('(profileSchool as Record<string, unknown>)?.registration_no'),
    );
  });
}
