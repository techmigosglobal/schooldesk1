import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/features/profile/presentation/screens/profile_management_screen/profile_management_screen.dart';

void main() {
  group('profile management role visibility', () {
    test(
      'the authenticated account role overrides a missing/wrong route role',
      () {
        expect(
          resolveProfileManagementRole(
            routeRole: 'principal',
            accountRole: ' Teacher ',
          ),
          'teacher',
        );
      },
    );

    test(
      'the route role is a fallback only when the account role is absent',
      () {
        expect(
          resolveProfileManagementRole(
            routeRole: ' Teacher ',
            accountRole: ' ',
          ),
          'teacher',
        );
      },
    );

    test('school details visibility is gated by the effective account role', () {
      final source = File(
        'lib/features/profile/presentation/screens/profile_management_screen/profile_management_screen.dart',
      ).readAsStringSync();

      expect(source, contains('bool get _isPrincipal => _effectiveRole =='));
      expect(source, contains('if (_isPrincipal) ...['));
    });
  });
}
