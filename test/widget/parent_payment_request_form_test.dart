import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/features/finance/presentation/screens/parent_fees_screen/parent_payment_request_form_screen.dart';

import '../support/finance_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const filePickerChannel = MethodChannel(
    'miguelruivo.flutter.plugins.filepicker',
  );
  late TestBackendAdapter adapter;

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    adapter = TestBackendAdapter();
    BackendApiClient.instance.dio.httpClientAdapter = adapter;
    BackendApiClient.instance.setAuthToken('parent-test-token');
    BackendApiClient.instance.setCurrentRole('parent');
  });

  tearDown(() async {
    BackendApiClient.instance.clearAuthToken();
    final messenger = TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(filePickerChannel, null);
  });

  testWidgets('parent payment form creates intent and stays qr first', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final args = _sampleArgs();
    final navigatorKey = GlobalKey<NavigatorState>();
    Map<String, dynamic>? intentPayload;
    _seedPaymentConfig(adapter);
    adapter.handlers['POST /fees/payments/intent'] = (options) {
      intentPayload = Map<String, dynamic>.from(options.data as Map);
      return <String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'id': 'intent-1',
          'request_reference': 'FPR-1001',
          'amount': 1.0,
          'upi_uri':
              'upi://pay?pa=school@upi&pn=Bad+Name&am=1.00&cu=INR&tn=FPR-1001%20payment',
        },
      };
    };

    await _pumpHost(tester, navigatorKey);
    await _pushParentForm(tester, navigatorKey, args);

    final confirmPaymentButton = find.widgetWithText(
      FilledButton,
      'Create Payment Reference',
    );
    await tester.scrollUntilVisible(
      confirmPaymentButton,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(confirmPaymentButton, findsOneWidget);
    await tester.tap(confirmPaymentButton);
    await tester.pumpAndSettle();

    expect(intentPayload?['invoice_id'], 'invoice-1');
    expect(intentPayload?['selected_months'], 1);
    expect(
      (intentPayload?['selected_month_names'] as List?)?.cast<String>(),
      <String>['January'],
    );
    expect(
      find.textContaining('Payment reference created: FPR-1001'),
      findsOneWidget,
    );
    expect(find.textContaining('Reference: FPR-1001'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Pay Now'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Reference Ready'), findsOneWidget);
    expect(
      find.text(
        'Scan the QR or use the copied UPI ID, then enter the UTR and upload the success screenshot below.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'parent payment form only sends the next continuous unpaid tuition months',
    (tester) async {
      _setLargeSurface(tester);
      final args = _sampleArgs(
        feeOverrides: <String, dynamic>{
          'amount': 20.0,
          'balance_amount': 20.0,
          'monthly_amount': 10.0,
          'allowed_month_names': <String>[
            'January',
            'February',
            'March',
            'April',
          ],
          'paid_month_names': <String>['January', 'February'],
        },
      );
      final navigatorKey = GlobalKey<NavigatorState>();
      Map<String, dynamic>? firstIntentPayload;
      Map<String, dynamic>? secondIntentPayload;
      var intentCount = 0;

      _seedPaymentConfig(adapter);
      adapter.handlers['POST /fees/payments/intent'] = (options) {
        intentCount += 1;
        final payload = Map<String, dynamic>.from(options.data as Map);
        if (intentCount == 1) {
          firstIntentPayload = payload;
        } else {
          secondIntentPayload = payload;
        }
        return <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{
            'id': 'intent-$intentCount',
            'request_reference': 'FPR-$intentCount',
            'amount': payload['selected_months'] == 2 ? 20.0 : 10.0,
            'upi_uri': 'upi://pay?pa=school@upi&am=10.00',
          },
        };
      };

      await _pumpHost(tester, navigatorKey);
      await _pushParentForm(tester, navigatorKey, args);

      expect(find.text('Already paid: January, February'), findsOneWidget);
      expect(find.text('Selected months: March'), findsOneWidget);
      await tester.tap(find.text('May'));
      await tester.pumpAndSettle();
      expect(find.text('Selected months: March'), findsOneWidget);

      final confirmPaymentButton = find.widgetWithText(
        FilledButton,
        'Create Payment Reference',
      );
      await tester.scrollUntilVisible(
        confirmPaymentButton,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(confirmPaymentButton);
      await tester.pumpAndSettle();

      expect(firstIntentPayload?['selected_months'], 1);
      expect(
        (firstIntentPayload?['selected_month_names'] as List?)?.cast<String>(),
        <String>['March'],
      );

      await tester.tap(find.text('April'));
      await tester.pumpAndSettle();
      expect(find.text('Selected months: March, April'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Create Payment Reference'),
      );
      await tester.pumpAndSettle();

      expect(secondIntentPayload?['selected_months'], 2);
      expect(
        (secondIntentPayload?['selected_month_names'] as List?)?.cast<String>(),
        <String>['March', 'April'],
      );
    },
  );

  testWidgets('parent payment form blocks Pay Now when UPI QR is not configured', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final args = _sampleArgs();
    final navigatorKey = GlobalKey<NavigatorState>();
    adapter.routes['GET /fees/payment-config'] = <String, dynamic>{
      'success': true,
      'data': <String, dynamic>{
        'upi_id': '',
        'payee_name': '',
        'upi_enabled': false,
        'qr_note': '',
        'qr_image_url': '',
      },
    };

    await _pumpHost(tester, navigatorKey);
    await _pushParentForm(tester, navigatorKey, args);

    expect(find.text('UPI payment is not configured'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Pay Now'), findsNothing);
    expect(
      find.widgetWithText(FilledButton, 'Create Payment Reference'),
      findsNothing,
    );
    expect(
      adapter.seenRequests.where(
        (request) => request.path == '/fees/payments/intent',
      ),
      isEmpty,
    );
  });

  test('fee payment proof API sends multipart request', () async {
    final proofFile = await createTestProofImage();
    Map<String, String>? submitFields;
    FormData? submitFormData;

    adapter.handlers['POST /fees/payments/submit'] = (options) {
      submitFormData = expectFormData(options.data);
      submitFields = formDataFields(submitFormData!);
      return <String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'id': 'req-2',
          'request_reference': 'FPR-2002',
          'proof_url': 'https://example.com/proof.png',
          'status': 'pending_verification',
        },
      };
    };

    final response = await BackendApiClient.instance.submitFeePaymentProof(
      paymentRequestId: 'intent-2',
      requestReference: 'FPR-2002',
      studentFeeId: 'invoice-1',
      amount: 1.0,
      paymentMethod: 'upi',
      transactionRef: 'UTR123456',
      screenshotPath: proofFile.path,
      screenshotName: proofFile.uri.pathSegments.last,
      selectedMonthNames: const <String>['January'],
      selectedMonths: 1,
      remarks: 'Parent note',
    );

    expect(response['status'], 'pending_verification');
    expect(submitFields?['student_fee_id'], 'invoice-1');
    expect(submitFields?['payment_request_id'], 'intent-2');
    expect(submitFields?['request_reference'], 'FPR-2002');
    expect(submitFields?['transaction_ref'], 'UTR123456');
    expect(submitFields?['selected_months'], '1');
    expect(submitFields?['selected_month_names'], 'January');
    expect(submitFields?['remarks'], 'Parent note');
    expect(submitFormData?.files.single.value.filename, 'proof.png');
  });

  testWidgets('clarification resubmit keeps parent in resubmission flow', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final navigatorKey = GlobalKey<NavigatorState>();
    final proofFile = await createTestProofImage();

    _seedPaymentConfig(adapter);
    final messenger = TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(filePickerChannel, (call) async {
      if (call.method != 'custom') return null;
      return <Map<String, dynamic>>[
        <String, dynamic>{
          'path': proofFile.path,
          'name': proofFile.uri.pathSegments.last,
          'size': proofFile.lengthSync(),
        },
      ];
    });

    await _pumpHost(tester, navigatorKey);
    await _pushParentForm(
      tester,
      navigatorKey,
      _sampleArgs(
        paymentRequest: <String, dynamic>{
          'id': 'req-1',
          'status': 'clarification_required',
          'transaction_id': 'OLD-UTR-1',
          'admin_remarks': 'Please upload a clearer screenshot.',
        },
      ),
    );

    expect(find.text('Clarification Required'), findsOneWidget);
    expect(find.text('Please upload a clearer screenshot.'), findsOneWidget);
    expect(find.textContaining('Resubmit Payment for Verification'), findsOneWidget);

    final uploadScreenshotButton = find.widgetWithText(
      OutlinedButton,
      'Upload Screenshot',
    );
    await tester.scrollUntilVisible(
      uploadScreenshotButton,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(uploadScreenshotButton);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('proof.png'), findsOneWidget);
    expect(find.text('OLD-UTR-1'), findsOneWidget);

    expect(
      adapter.seenRequests.where(
        (request) => request.path == '/fees/payments/intent',
      ),
      isEmpty,
    );
  });

  test('fee payment proof API resubmits clarification multipart request', () async {
    final proofFile = await createTestProofImage();
    Map<String, String>? resubmitFields;

    adapter.handlers['PATCH /fees/payments/req-1/resubmit'] = (options) {
      final formData = expectFormData(options.data);
      resubmitFields = formDataFields(formData);
      return <String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'id': 'req-1',
          'request_reference': 'FPR-3003',
          'proof_url': 'https://example.com/reproof.png',
          'status': 'pending_verification',
        },
      };
    };

    final response = await BackendApiClient.instance.resubmitFeePaymentProof(
      id: 'req-1',
      transactionRef: 'NEW-UTR-9',
      screenshotPath: proofFile.path,
      screenshotName: proofFile.uri.pathSegments.last,
      remarks: 'Updated proof',
    );

    expect(response['status'], 'pending_verification');
    expect(resubmitFields?['transaction_ref'], 'NEW-UTR-9');
    expect(resubmitFields?['remarks'], 'Updated proof');
  });
}

Future<void> _pumpHost(
  WidgetTester tester,
  GlobalKey<NavigatorState> navigatorKey,
) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      theme: AppTheme.lightTheme,
      home: const Scaffold(body: Center(child: Text('Home'))),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _pushParentForm(
  WidgetTester tester,
  GlobalKey<NavigatorState> navigatorKey,
  ParentPaymentRequestFormArgs args,
) async {
  navigatorKey.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => ParentPaymentRequestFormScreen(args: args),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Finder _utrField() {
  return find.widgetWithText(TextFormField, 'UTR / transaction reference');
}

ParentPaymentRequestFormArgs _sampleArgs({
  Map<String, dynamic>? paymentRequest,
  Map<String, dynamic> feeOverrides = const <String, dynamic>{},
}) {
  return ParentPaymentRequestFormArgs(
    fees: <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'invoice-1',
        'invoice_number': 'INV-1',
        'component': 'Tuition Fee',
        'fee_type': 'tuition',
        'amount': 12.0,
        'balance_amount': 12.0,
        'monthly_amount': 1.0,
        'term_amount': 6.0,
        'term_count': 2,
        ...feeOverrides,
      },
    ],
    student: <String, dynamic>{
      'id': 'student-1',
      'name': 'Aarav Sharma',
      'class': 'Class 5 - A',
    },
    paymentRequest: paymentRequest,
  );
}

void _seedPaymentConfig(TestBackendAdapter adapter) {
  adapter.routes['GET /fees/payment-config'] = <String, dynamic>{
    'success': true,
    'data': <String, dynamic>{
      'upi_id': 'school@upi',
      'payee_name': 'School Desk',
      'upi_enabled': true,
      'qr_note': 'School fee payment',
      'qr_image_url': '',
      'updated_at': '2026-07-03T10:00:00.000Z',
    },
  };
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
