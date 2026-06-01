import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schooldesk1/main.dart' as app;
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/services/token_storage_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final credentials = <_RoleCredentials>[
    _RoleCredentials(
      role: 'Principal',
      username: const String.fromEnvironment('QA_PRINCIPAL_USERNAME'),
      password: const String.fromEnvironment('QA_PRINCIPAL_PASSWORD'),
      dashboardMarkers: const ['Oversight Overview', 'Pending Approvals'],
    ),
    _RoleCredentials(
      role: 'Admin',
      username: const String.fromEnvironment('QA_ADMIN_USERNAME'),
      password: const String.fromEnvironment('QA_ADMIN_PASSWORD'),
      dashboardMarkers: const ['Total Students', 'Total Staff'],
    ),
    _RoleCredentials(
      role: 'Teacher',
      username: const String.fromEnvironment('QA_TEACHER_USERNAME'),
      password: const String.fromEnvironment('QA_TEACHER_PASSWORD'),
      dashboardMarkers: const ["Today's Overview", 'Class Students'],
    ),
    _RoleCredentials(
      role: 'Parent',
      username: const String.fromEnvironment('QA_PARENT_USERNAME'),
      password: const String.fromEnvironment('QA_PARENT_PASSWORD'),
      dashboardMarkers: const ['Fee Dues', 'Notices'],
    ),
  ];

  group('Local role login smoke', () {
    for (final role in credentials) {
      testWidgets('${role.role} logs in and reaches dashboard', (tester) async {
        await _launchCleanApp(tester);
        await _openSignInForm(tester);

        final fields = find.byType(TextFormField);
        expect(fields, findsNWidgets(2));
        await tester.enterText(fields.at(0), role.username);
        await tester.enterText(fields.at(1), role.password);
        await tester.testTextInput.receiveAction(TextInputAction.done);

        await _pumpUntilAnyText(tester, role.dashboardMarkers);

        expect(find.text('Dashboard unavailable'), findsNothing);
        expect(find.text('Invalid username or password.'), findsNothing);
      }, skip: !role.isConfigured);
    }
  });
}

Future<void> _launchCleanApp(WidgetTester tester) async {
  final originalErrorWidgetBuilder = ErrorWidget.builder;
  await TokenStorageService.clear();
  BackendApiClient.instance.clearAuthToken();
  RoleAccessService.clear();
  app.main();

  try {
    for (var attempt = 0; attempt < 50; attempt++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byType(app.MyApp).evaluate().isNotEmpty) {
        break;
      }
    }
  } finally {
    ErrorWidget.builder = originalErrorWidgetBuilder;
  }
}

Future<void> _openSignInForm(WidgetTester tester) async {
  if (find.text('Sign in').evaluate().isNotEmpty) return;

  await _pumpUntilAnyText(tester, const ['Login', 'Secure Login']);
  final loginButton = find.widgetWithText(FilledButton, 'Login');
  final secureLoginButton = find.widgetWithText(FilledButton, 'Secure Login');
  if (loginButton.evaluate().isNotEmpty) {
    await tester.tap(loginButton.first);
  } else {
    await tester.tap(secureLoginButton.first);
  }

  await _pumpUntilAnyText(tester, const ['Sign in']);
}

Future<void> _pumpUntilAnyText(WidgetTester tester, List<String> texts) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    await tester.pump(const Duration(milliseconds: 500));
    for (final text in texts) {
      if (find.text(text).evaluate().isNotEmpty) {
        return;
      }
    }
  }
  fail(
    'None of the expected dashboard markers were found: ${texts.join(', ')}',
  );
}

class _RoleCredentials {
  final String role;
  final String username;
  final String password;
  final List<String> dashboardMarkers;

  const _RoleCredentials({
    required this.role,
    required this.username,
    required this.password,
    required this.dashboardMarkers,
  });

  bool get isConfigured => username.trim().isNotEmpty && password.isNotEmpty;
}
