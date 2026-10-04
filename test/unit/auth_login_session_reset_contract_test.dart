import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('login screen reopens role scope after logout', () {
    final source = File(
      'lib/features/auth/presentation/screens/auth_login_screen/auth_login_screen.dart',
    ).readAsStringSync();

    final resetIndex = source.indexOf('RoleAccessService.resetSignOutGuard()');
    final loginIndex = source.indexOf('await _repository.login(');

    expect(
      resetIndex,
      greaterThanOrEqualTo(0),
      reason: 'A new login must clear the previous sign-out guard.',
    );
    expect(
      resetIndex,
      lessThan(loginIndex),
      reason: 'The guard must be reset before the new session initializes.',
    );
  });
}
