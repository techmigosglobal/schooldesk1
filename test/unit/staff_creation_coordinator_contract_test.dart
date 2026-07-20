import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('staff profile form offers only the requested designation choices', () {
    final source = File(
      'lib/features/people/presentation/screens/staff_management_screen/staff_management_screen.dart',
    ).readAsStringSync();

    expect(
      source,
      contains("'Teacher',\n    'Co Teacher',\n    'Coordinator',"),
    );
    expect(source, isNot(contains("'Support Staff'")));
    expect(source, contains("_accountRole = 'Coordinator'"));
    expect(source, contains("['Teacher', 'Coordinator']"));
  });

  test(
    'optional staff fields do not block profile submission or send defaults',
    () {
      final profile = File(
        'lib/features/people/presentation/screens/staff_management_screen/staff_management_screen.dart',
      ).readAsStringSync();
      final api = File(
        'lib/core/network/api_modules/staff_api.dart',
      ).readAsStringSync();

      expect(profile, contains('Date of Birth (optional)'));
      expect(profile, contains('Phone Number (optional)'));
      expect(profile, contains('Employee ID (optional)'));
      expect(profile, contains('Employment Type (optional)'));
      expect(profile, contains('static String? _optionalPhone'));
      expect(profile, contains('static String _backendDate(DateTime? date)'));
      expect(api, isNot(contains("String dateOfBirth = '1990-01-01'")));
      expect(api, isNot(contains("String joinDate = '2026-01-01'")));
      expect(
        api,
        contains("if (dateOfBirth != null && dateOfBirth.trim().isNotEmpty)"),
      );
    },
  );

  test(
    'staff provisioning persists coordinator in user and Auth role metadata',
    () {
      final source = File(
        'supabase/functions/api/handlers/staff.ts',
      ).readAsStringSync();
      expect(source, contains('role_name: userRow.role_name'));
      expect(source, contains('app_metadata: {'));
      expect(source, contains('linked_id: staffId'));
      expect(
        source,
        contains('const roleName = text(body.account_role).toLowerCase()'),
      );
    },
  );
}
