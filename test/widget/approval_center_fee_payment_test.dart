import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/features/people/presentation/screens/approval_center_screen/approval_center_screen.dart';

import '../support/finance_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestBackendAdapter adapter;
  void Function(FlutterErrorDetails details)? previousOnError;

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    adapter = TestBackendAdapter();
    BackendApiClient.instance.dio.httpClientAdapter = adapter;
    BackendApiClient.instance.setAuthToken('principal-test-token');
    BackendApiClient.instance.setCurrentRole('principal');
    previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      final summary = details.exceptionAsString();
      if (summary.contains('A RenderFlex overflowed by')) return;
      previousOnError?.call(details);
    };
  });

  tearDown(() {
    BackendApiClient.instance.clearAuthToken();
    FlutterError.onError = previousOnError;
  });

  testWidgets(
    'Fees tab shows pending payment proofs and uses payment decision route',
    (tester) async {
      _setLargeSurface(tester);
      var decisionCount = 0;
      _registerEmptyApprovalRoutes(adapter);
      adapter.handlers['GET /fees/payment-requests'] = (_) {
        final status = decisionCount == 0 ? 'submitted' : 'approved';
        return <String, dynamic>{
          'success': true,
          'data': <Map<String, dynamic>>[_paymentRequestRow(status: status)],
        };
      };
      adapter.handlers['PUT /fees/payment-requests/req-proof/decision'] =
          (options) {
            decisionCount += 1;
            expect((options.data as Map)['status'], 'approved');
            expect((options.data as Map)['admin_remarks'], '');
            return <String, dynamic>{
              'success': true,
              'data': <String, dynamic>{
                'id': 'req-proof',
                'status': 'approved',
              },
            };
          };

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(1280, 1800),
            textScaler: TextScaler.linear(0.9),
          ),
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ApprovalCenterScreen(
              args: ApprovalCenterRouteArgs(initialTab: 'fees'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      _drainExpectedOverflow(tester);
      expect(find.text('Payment Proof'), findsOneWidget);
      expect(find.text('Rudhighsa Goud Y'), findsOneWidget);
      expect(
        find.text('Payment proof · ₹30000 · FEE-AUTO-TEST'),
        findsOneWidget,
      );

      await tester.tap(find.text('Rudhighsa Goud Y'));
      await tester.pumpAndSettle();
      _drainExpectedOverflow(tester);
      expect(find.textContaining('Invoice: FEE-AUTO-TEST'), findsOneWidget);
      expect(find.textContaining('Parent: Y. Sivamani Kanta'), findsWidgets);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Approve'));
      await tester.pumpAndSettle();
      _drainExpectedOverflow(tester);

      expect(decisionCount, 1);
      expect(find.text('Rudhighsa Goud Y'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
      await tester.pumpAndSettle();
      _drainExpectedOverflow(tester);
      expect(find.text('Rudhighsa Goud Y'), findsOneWidget);
      expect(find.text('Approved'), findsWidgets);
    },
  );
}

void _registerEmptyApprovalRoutes(TestBackendAdapter adapter) {
  for (final path in [
    '/leave/applications',
    '/account-approvals',
    '/approvals',
    '/student-leave/applications',
    '/fees/concessions',
    '/event-posts/pending',
    '/notifications',
    '/notifications/preferences',
  ]) {
    adapter.routes['GET $path'] = <String, dynamic>{
      'success': true,
      'data': <Map<String, dynamic>>[],
    };
  }
}

Map<String, dynamic> _paymentRequestRow({required String status}) {
  return <String, dynamic>{
    'id': 'req-proof',
    'status': status,
    'invoice_id': 'invoice-proof',
    'amount': 30000,
    'payment_date': '2026-08-07',
    'payment_method': 'upi',
    'request_reference': 'FPR-1786096306287-70556D96',
    'transaction_id': 'UTR-TEST',
    'remarks': 'Paid by parent',
    'proof_url': '',
    'invoice': <String, dynamic>{'invoice_number': 'FEE-AUTO-TEST'},
    'student': <String, dynamic>{
      'first_name': 'Rudhighsa',
      'last_name': 'Goud Y',
    },
    'parent_user': <String, dynamic>{
      'name': 'Y. Sivamani Kanta',
      'email': 'parent@example.com',
    },
  };
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _drainExpectedOverflow(WidgetTester tester) {
  while (true) {
    final exception = tester.takeException();
    if (exception == null) return;
    final message = exception.toString();
    if (!message.contains('A RenderFlex overflowed by')) throw exception;
  }
}
