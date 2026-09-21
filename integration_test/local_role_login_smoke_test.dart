import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schooldesk1/main.dart' as app;
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/services/token_storage_service.dart';
import 'package:schooldesk1/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart';
import 'package:schooldesk1/features/dashboard/presentation/screens/principal_dashboard_screen/principal_dashboard_screen.dart';
import 'package:schooldesk1/features/dashboard/presentation/screens/teacher_dashboard_screen/teacher_dashboard_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final credentials = <_RoleCredentials>[
    const _RoleCredentials(
      role: 'Principal',
      username: String.fromEnvironment('QA_PRINCIPAL_USERNAME'),
      password: String.fromEnvironment('QA_PRINCIPAL_PASSWORD'),
      dashboardType: PrincipalDashboardScreen,
    ),
    const _RoleCredentials(
      role: 'Admin',
      username: String.fromEnvironment('QA_ADMIN_USERNAME'),
      password: String.fromEnvironment('QA_ADMIN_PASSWORD'),
      // Legacy backend admins share Principal-level access in this app.
      dashboardType: PrincipalDashboardScreen,
    ),
    const _RoleCredentials(
      role: 'Coordinator',
      username: String.fromEnvironment('QA_COORDINATOR_USERNAME'),
      password: String.fromEnvironment('QA_COORDINATOR_PASSWORD'),
      dashboardType: PrincipalDashboardScreen,
    ),
    const _RoleCredentials(
      role: 'Teacher',
      username: String.fromEnvironment('QA_TEACHER_USERNAME'),
      password: String.fromEnvironment('QA_TEACHER_PASSWORD'),
      dashboardType: TeacherDashboardScreen,
    ),
    const _RoleCredentials(
      role: 'Parent',
      username: String.fromEnvironment('QA_PARENT_USERNAME'),
      password: String.fromEnvironment('QA_PARENT_PASSWORD'),
      dashboardType: ParentDashboardScreen,
    ),
  ];

  group('Local role login smoke', () {
    for (final role in credentials) {
      testWidgets('${role.role} logs in and reaches dashboard', (tester) async {
        try {
          await _launchCleanApp(tester);
          await _openSignInForm(tester);

          final fields = find.byType(TextFormField);
          expect(fields, findsNWidgets(2));
          await tester.enterText(fields.at(0), role.username);
          await tester.enterText(fields.at(1), role.password);
          await tester.testTextInput.receiveAction(TextInputAction.done);

          await _pumpUntilRoleDashboard(tester, role);

          expect(find.text('Dashboard unavailable'), findsNothing);
          expect(find.text('Invalid username or password.'), findsNothing);
          expect(
            BackendApiClient.instance.currentRoleName?.toLowerCase(),
            role.role.toLowerCase(),
          );
        } finally {
          app.disposeAppSemanticsHandleForTesting();
        }
      }, skip: !role.isConfigured);
    }
  });
}

Future<void> _launchCleanApp(WidgetTester tester) async {
  final originalErrorWidgetBuilder = ErrorWidget.builder;
  final originalFlutterErrorHandler = FlutterError.onError;
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
    FlutterError.onError = originalFlutterErrorHandler;
  }
}

Future<void> _openSignInForm(WidgetTester tester) async {
  if (find.byType(TextFormField).evaluate().length == 2) return;

  final landingSignInButton = find.byKey(const Key('sign_in_button'));
  if (landingSignInButton.evaluate().isNotEmpty) {
    await tester.tap(landingSignInButton);
  } else {
    await _pumpUntilAnyText(tester, const ['Login', 'Secure Login']);
    final loginButton = find.widgetWithText(FilledButton, 'Login');
    final secureLoginButton = find.widgetWithText(FilledButton, 'Secure Login');
    if (loginButton.evaluate().isNotEmpty) {
      await tester.tap(loginButton.first);
    } else {
      await tester.tap(secureLoginButton.first);
    }
  }

  for (var attempt = 0; attempt < 80; attempt++) {
    await tester.pump(const Duration(milliseconds: 500));
    if (find.byType(TextFormField).evaluate().length == 2) return;
  }
  fail(
    'The sign-in form did not expose the expected username and password fields.',
  );
}

Future<void> _pumpUntilRoleDashboard(
  WidgetTester tester,
  _RoleCredentials role,
) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    await tester.pump(const Duration(milliseconds: 500));
    final api = BackendApiClient.instance;
    final expectedRole = role.role.toLowerCase();
    if (api.isAuthenticated &&
        api.currentRoleName?.toLowerCase() == expectedRole &&
        find.byType(role.dashboardType).evaluate().isNotEmpty) {
      return;
    }
  }
  fail('The ${role.role} session did not reach its dashboard widget.');
}

Future<void> _pumpUntilAnyText(WidgetTester tester, List<String> texts) async {
  for (var attempt = 0; attempt < 80; attempt++) {
    await tester.pump(const Duration(milliseconds: 500));
    if (texts.any((text) => find.text(text).evaluate().isNotEmpty)) return;
  }
  fail('None of the expected text was found: ${texts.join(', ')}');
}

class _RoleCredentials {
  final String role;
  final String username;
  final String password;
  final Type dashboardType;

  const _RoleCredentials({
    required this.role,
    required this.username,
    required this.password,
    required this.dashboardType,
  });

  bool get isConfigured => username.trim().isNotEmpty && password.isNotEmpty;
}
