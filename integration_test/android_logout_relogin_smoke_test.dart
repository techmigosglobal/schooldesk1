import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/services/token_storage_service.dart';
import 'package:schooldesk1/features/dashboard/presentation/screens/teacher_dashboard_screen/teacher_dashboard_screen.dart';
import 'package:schooldesk1/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android logout clears session and allows clean relogin', (
    tester,
  ) async {
    const username = String.fromEnvironment('QA_TEACHER_USERNAME');
    const password = String.fromEnvironment('QA_TEACHER_PASSWORD');
    expect(username, isNotEmpty);
    expect(password, isNotEmpty);

    try {
      await _launchCleanApp(tester);
      await _loginAsTeacher(tester, username, password);

      expect(BackendApiClient.instance.isAuthenticated, isTrue);
      expect(
        BackendApiClient.instance.currentRoleName?.toLowerCase(),
        'teacher',
      );
      expect(await TokenStorageService.getAccessToken(), isNotEmpty);
      expect(await TokenStorageService.getRefreshToken(), isNotEmpty);

      await _pumpUntil(
        tester,
        () => find.byTooltip('Open navigation').evaluate().isNotEmpty,
      );
      await tester.tap(find.byTooltip('Open navigation'));
      await _pumpUntil(
        tester,
        () => find.text('Teacher Portal').evaluate().isNotEmpty,
      );
      await tester.tap(find.text('Sign Out').last);
      await _pumpUntil(
        tester,
        () => find
            .text('Are you sure you want to sign out of the Teacher portal?')
            .evaluate()
            .isNotEmpty,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Sign Out').last);

      await _pumpUntil(
        tester,
        () =>
            !BackendApiClient.instance.isAuthenticated &&
            find.byKey(const Key('sign_in_button')).evaluate().isNotEmpty,
      );
      expect(await TokenStorageService.getAccessToken(), isNull);
      expect(await TokenStorageService.getRefreshToken(), isNull);
      expect(await TokenStorageService.getRoleName(), isNull);
      expect(BackendApiClient.instance.currentRoleName, isNull);

      await _loginAsTeacher(tester, username, password);
      expect(BackendApiClient.instance.isAuthenticated, isTrue);
      expect(
        BackendApiClient.instance.currentRoleName?.toLowerCase(),
        'teacher',
      );
      expect(find.byType(TeacherDashboardScreen), findsOneWidget);
      expect(await TokenStorageService.getRoleName(), 'teacher');
    } finally {
      app.disposeAppSemanticsHandleForTesting();
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
    for (var attempt = 0; attempt < 60; attempt++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byType(app.MyApp).evaluate().isNotEmpty) return;
    }
  } finally {
    ErrorWidget.builder = originalErrorWidgetBuilder;
    FlutterError.onError = originalFlutterErrorHandler;
  }
  fail('The app did not finish startup.');
}

Future<void> _loginAsTeacher(
  WidgetTester tester,
  String username,
  String password,
) async {
  if (find.byType(TextFormField).evaluate().length != 2) {
    final signIn = find.byKey(const Key('sign_in_button'));
    if (signIn.evaluate().isNotEmpty) {
      await tester.tap(signIn);
    } else {
      await _pumpUntil(
        tester,
        () => find.widgetWithText(FilledButton, 'Login').evaluate().isNotEmpty,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Login').first);
    }
    await _pumpUntil(
      tester,
      () => find.byType(TextFormField).evaluate().length == 2,
    );
  }

  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), username);
  await tester.enterText(fields.at(1), password);
  await tester.testTextInput.receiveAction(TextInputAction.done);

  await _pumpUntil(
    tester,
    () =>
        BackendApiClient.instance.isAuthenticated &&
        BackendApiClient.instance.currentRoleName?.toLowerCase() == 'teacher' &&
        find.byType(TeacherDashboardScreen).evaluate().isNotEmpty,
  );
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 500));
    if (condition()) return;
  }
  fail('The expected screen or session state did not appear.');
}
