import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/features/finance/presentation/screens/parent_hub/parent_payment_flow.dart';
import 'package:schooldesk1/routes/app_routes.dart';

import '../support/finance_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestBackendAdapter adapter;
  late Map<String, dynamic> intentPayload;

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    adapter = TestBackendAdapter();
    adapter.routes['GET /fees/payment-config'] = <String, dynamic>{
      'success': true,
      'data': <String, dynamic>{
        'upi_id': 'school@test',
        'payee_name': 'School',
        'qr_image_url': 'https://example.test/payment-qr.png',
        'qr_note': 'Verify the payee name before completing payment.',
      },
    };
    intentPayload = <String, dynamic>{};
    adapter.handlers['POST /fees/payments/request'] = (options) {
      intentPayload = Map<String, dynamic>.from(options.data as Map);
      return <String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'id': 'payment-request-id',
          'request_reference': 'PAY-TEST',
        },
      };
    };
    BackendApiClient.instance.dio.httpClientAdapter = adapter;
    BackendApiClient.instance.setAuthToken('parent-test-token');
    BackendApiClient.instance.setCurrentRole('parent');
  });

  tearDown(() {
    BackendApiClient.instance.clearAuthToken();
  });

  testWidgets('Tuition label overrides stale other type and shows months', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: ParentPaymentFlow(
          args: ParentPaymentSelectionArgs(
            fees: const [
              {
                'id': 'tuition-invoice',
                'component': 'Tuition',
                'fee_type': 'other',
                'billing_mode': 'one_time',
                'amount': 10.0,
                'monthly_amount': 1.0,
              },
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tuition'), findsOneWidget);
    expect(find.text('Select Months to Pay'), findsOneWidget);
    expect(find.text('June'), findsOneWidget);
    expect(find.text('Paying for 1 month(s)'), findsOneWidget);
    expect(find.textContaining('Book & Kit'), findsNothing);

    await tester.tap(find.text('Continue to Pay'));
    await tester.pumpAndSettle();

    expect(intentPayload['invoice_id'], 'tuition-invoice');
    expect(intentPayload['selected_month_names'], <String>['June']);
    expect(intentPayload['selected_months'], 1);
    expect(find.text('Pay to School UPI ID'), findsOneWidget);
    expect(find.byKey(const Key('payment-config-qr-image')), findsOneWidget);
    expect(find.text('school@test'), findsOneWidget);
    expect(
      find.text('Verify the payee name before completing payment.'),
      findsOneWidget,
    );

    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final copyButton = find.byKey(const Key('copy-payment-upi-id'));
    await tester.ensureVisible(copyButton);
    await tester.tap(copyButton);
    await tester.pump();
    expect(copiedText, 'school@test');
    expect(find.text('Copied UPI ID: school@test'), findsOneWidget);
  });

  testWidgets('one-time summary retains the actually selected fee label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: ParentPaymentFlow(
          args: ParentPaymentSelectionArgs(
            fees: const [
              {
                'id': 'activity-invoice',
                'component': 'Activity Fee',
                'fee_type': 'other',
                'amount': 25.0,
              },
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Activity Fee'), findsOneWidget);
    expect(find.text('Activity Fee: one-time payment'), findsOneWidget);
    expect(find.textContaining('Book & Kit'), findsNothing);
    expect(find.text('Select Months to Pay'), findsNothing);
  });
}
