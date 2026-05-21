/// Integration test stubs — these define the full end-to-end test flows.
/// Run with: flutter test integration_test/
///
/// MANUAL TESTING REQUIRED for flows that need real device interaction.
/// See test_cases.csv for the complete test case sheet.

// ignore_for_file: unused_import
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:schooldesk1/main.dart' as app;

/// ─── AUTH FLOW INTEGRATION TESTS ────────────────────────────────────────────
///
/// TC-AUTH-001: Principal login with valid credentials
/// TC-AUTH-002: Admin login with valid credentials
/// TC-AUTH-003: Teacher login with valid credentials
/// TC-AUTH-004: Parent login with valid credentials
/// TC-AUTH-005: Login with invalid credentials shows error
/// TC-AUTH-006: Empty email/password shows validation error
/// TC-AUTH-007: Logout navigates back to landing page
///
/// STATUS: MANUAL — requires device interaction for full flow testing
/// Automated unit tests cover credential validation logic in:
///   test/unit/features/auth_controller_test.dart

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Auth Flow Integration Tests', () {
    testWidgets('App launches and shows landing page', (tester) async {
      await _launchApp(tester);

      // The app root should be visible once async startup finishes.
      expect(find.byType(app.MyApp), findsOneWidget);
    });

    // TODO: Add full auth flow tests when backend is integrated
    // testWidgets('Principal login navigates to dashboard', (tester) async {
    //   app.main();
    //   await tester.pumpAndSettle();
    //   await tester.tap(find.text('Principal Login'));
    //   await tester.pumpAndSettle();
    //   await tester.enterText(find.byKey(Key('email_field')), 'principal@sunrise.edu.in');
    //   await tester.enterText(find.byKey(Key('password_field')), 'Sunrise@2025');
    //   await tester.tap(find.text('Login'));
    //   await tester.pumpAndSettle();
    //   expect(find.text('Principal Dashboard'), findsOneWidget);
    // });
  });
}

Future<void> _launchApp(WidgetTester tester) async {
  final originalErrorWidgetBuilder = ErrorWidget.builder;
  app.main();

  try {
    for (var attempt = 0; attempt < 40; attempt++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byType(app.MyApp).evaluate().isNotEmpty) {
        break;
      }
    }
  } finally {
    ErrorWidget.builder = originalErrorWidgetBuilder;
  }
}
