import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/features/finance/presentation/screens/parent_payment_screens/parent_payment_history_screen.dart';

import '../support/finance_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestBackendAdapter adapter;

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    adapter = TestBackendAdapter();
    BackendApiClient.instance.dio.httpClientAdapter = adapter;
    BackendApiClient.instance.setAuthToken('parent-test-token');
    BackendApiClient.instance.setCurrentRole('parent');
  });

  tearDown(() {
    BackendApiClient.instance.clearAuthToken();
  });

  testWidgets(
    'parent payment history keeps rupee amount, invoice, months, and receipt context',
    (tester) async {
      _setLargeSurface(tester);
      adapter.routes['GET /me/students'] = <String, dynamic>{
        'success': true,
        'data': <Map<String, dynamic>>[
          <String, dynamic>{'id': 'student-1'},
        ],
      };
      adapter.routes['GET /fees/payments'] = <String, dynamic>{
        'success': true,
        'data': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'payment-1',
            'invoice_id': 'invoice-1',
            'amount': 1250.0,
            'payment_method': 'upi',
            'reference_number': 'UTR123456',
            'paid_at': '2026-07-03T09:30:00.000Z',
            'status': 'completed',
            'selected_month_names': <String>['January', 'February'],
            'invoice': <String, dynamic>{
              'id': 'invoice-1',
              'invoice_number': 'INV-2026-0001',
              'fee_type': 'tuition',
            },
            'student': <String, dynamic>{
              'first_name': 'Aarav',
              'last_name': 'Sharma',
            },
            'fee_receipts': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'receipt-1',
                'receipt_number': 'RCP-2026-0001',
              },
            ],
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ParentPaymentHistoryScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('RCP-2026-0001'), findsOneWidget);
      expect(find.text('INV-2026-0001'), findsOneWidget);
      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('January, February'), findsOneWidget);
      expect(find.text('UTR123456'), findsOneWidget);
      expect(find.text('₹1250.00'), findsOneWidget);
      expect(find.text('Successful'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
