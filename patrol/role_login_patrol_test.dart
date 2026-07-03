import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/services/token_storage_service.dart';
import 'package:schooldesk1/main.dart' as app;

import '../test/support/local_test_credentials.dart';

void main() {
  patrolTest(
    'principal can log in to the local seeded app',
    ($) async {
      final principal = localRoleCredentials.first;
      await _launchCleanApp($);
      await _openSignInForm($);

      final fields = find.byType(TextFormField);
      await $.tester.enterText(fields.at(0), principal.username);
      await $.tester.enterText(fields.at(1), principal.password);
      await $.tester.testTextInput.receiveAction(TextInputAction.done);

      await _waitForAnyText($, principal.dashboardMarkers);
    },
    skip: !localRoleCredentials.first.isConfigured,
  );
}

Future<void> _launchCleanApp(PatrolIntegrationTester $) async {
  await TokenStorageService.clear();
  BackendApiClient.instance.clearAuthToken();
  RoleAccessService.clear();
  app.main();
  await $.pumpAndSettle();
}

Future<void> _openSignInForm(PatrolIntegrationTester $) async {
  final tester = $.tester;
  if (find.text('Sign in').evaluate().isNotEmpty) return;

  final loginButton = find.widgetWithText(FilledButton, 'Login');
  final secureLoginButton = find.widgetWithText(FilledButton, 'Secure Login');
  if (loginButton.evaluate().isNotEmpty) {
    await tester.tap(loginButton.first);
  } else if (secureLoginButton.evaluate().isNotEmpty) {
    await tester.tap(secureLoginButton.first);
  }
  await $.pumpAndSettle();
}

Future<void> _waitForAnyText(
  PatrolIntegrationTester $,
  List<String> texts,
) async {
  for (var attempt = 0; attempt < 60; attempt++) {
    await $.pump(const Duration(milliseconds: 500));
    for (final text in texts) {
      if (find.text(text).evaluate().isNotEmpty) return;
    }
  }
  throw TestFailure('None of these texts appeared: ${texts.join(', ')}');
}
