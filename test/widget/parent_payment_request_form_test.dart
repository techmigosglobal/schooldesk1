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
  const urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');

  late TestBackendAdapter adapter;
  bool launchedUpi = false;
  String? launchedUrl;

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    adapter = TestBackendAdapter();
    BackendApiClient.instance.dio.httpClientAdapter = adapter;
    BackendApiClient.instance.setAuthToken('parent-test-token');
    BackendApiClient.instance.setCurrentRole('parent');
    launchedUpi = false;
    launchedUrl = null;
  });

  tearDown(() async {
    BackendApiClient.instance.clearAuthToken();
    final messenger = TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(filePickerChannel, null);
    messenger.setMockMethodCallHandler(urlLauncherChannel, null);
  });

  testWidgets('parent payment form creates intent and marks UPI as opened', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final args = _sampleArgs();
    final navigatorKey = GlobalKey<NavigatorState>();
    Map<String, dynamic>? intentPayload;
    _seedPaymentConfig(adapter);
    final messenger = TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(urlLauncherChannel, (call) async {
      if (call.method == 'launch') {
        launchedUpi = true;
        launchedUrl = (call.arguments as Map)['url'] as String;
        return true;
      }
      return false;
    });
    adapter.handlers['POST /fees/payments/intent'] = (options) {
      intentPayload = Map<String, dynamic>.from(options.data as Map);
      return <String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'id': 'intent-1',
          'request_reference': 'FPR-1001',
          'amount': 1.0,
          'upi_uri': 'upi://pay?pa=school@upi&am=1.00',
        },
      };
    };

    await _pumpHost(tester, navigatorKey);
    await _pushParentForm(tester, navigatorKey, args);

    final confirmPaymentButton = find.widgetWithText(
      FilledButton,
      'Confirm Payment',
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
    final payNowButton = find.widgetWithText(FilledButton, 'Pay Now');
    expect(payNowButton, findsOneWidget);

    await tester.tap(payNowButton);
    await tester.pumpAndSettle();

    expect(launchedUpi, isTrue);
    expect(launchedUrl, contains('upi://pay'));
    expect(
      find.text(
        'After payment, enter the UTR and upload the success screenshot below.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('parent payment form uploads proof and submits multipart request', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final args = _sampleArgs();
    final navigatorKey = GlobalKey<NavigatorState>();
    final proofFile = await createTestProofImage();
    Map<String, dynamic>? intentPayload;
    Map<String, String>? submitFields;
    FormData? submitFormData;

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
    adapter.handlers['POST /fees/payments/intent'] = (options) {
      intentPayload = Map<String, dynamic>.from(options.data as Map);
      return <String, dynamic>{
        'success': true,
        'data': <String, dynamic>{
          'id': 'intent-2',
          'request_reference': 'FPR-2002',
          'amount': 1.0,
          'upi_uri': 'upi://pay?pa=school@upi&am=1.00',
        },
      };
    };
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

    await _pumpHost(tester, navigatorKey);
    await _pushParentForm(tester, navigatorKey, args);

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
    await tester.pumpAndSettle();
    expect(find.text('proof.png'), findsOneWidget);

    await tester.enterText(_utrField(), 'UTR123456');
    final confirmPaymentButton = find.widgetWithText(
      FilledButton,
      'Confirm Payment',
    );
    await tester.scrollUntilVisible(
      confirmPaymentButton,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(confirmPaymentButton);
    await tester.pumpAndSettle();
    final submitButton = find.widgetWithText(
      FilledButton,
      'Submit Payment for Verification INR 1',
    );
    await tester.scrollUntilVisible(
      submitButton,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pump(const Duration(seconds: 1));

    expect(intentPayload?['invoice_id'], 'invoice-1');
    expect(submitFields?['student_fee_id'], 'invoice-1');
    expect(submitFields?['payment_request_id'], 'intent-2');
    expect(submitFields?['request_reference'], 'FPR-2002');
    expect(submitFields?['transaction_ref'], 'UTR123456');
    expect(submitFields?['selected_months'], '1');
    expect(submitFields?['selected_month_names'], 'January');
    expect(submitFormData?.files.single.value.filename, 'proof.png');
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('clarification resubmit keeps parent in resubmission flow', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final navigatorKey = GlobalKey<NavigatorState>();
    final proofFile = await createTestProofImage();
    Map<String, String>? resubmitFields;

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
    await tester.pumpAndSettle();
    expect(find.text('proof.png'), findsOneWidget);
    expect(find.text('OLD-UTR-1'), findsOneWidget);

    await tester.enterText(_utrField(), 'NEW-UTR-9');
    final resubmitButton = find.widgetWithText(
      FilledButton,
      'Resubmit Payment for Verification',
    );
    await tester.scrollUntilVisible(
      resubmitButton,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(resubmitButton);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
    await tester.pump(const Duration(seconds: 1));

    expect(resubmitFields?['transaction_ref'], 'NEW-UTR-9');
    expect(find.text('Home'), findsOneWidget);
    expect(
      adapter.seenRequests.where(
        (request) => request.path == '/fees/payments/intent',
      ),
      isEmpty,
    );
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
  await tester.pumpAndSettle();
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
  await tester.pumpAndSettle();
}

Finder _utrField() {
  return find.byType(TextFormField).first;
}

ParentPaymentRequestFormArgs _sampleArgs({
  Map<String, dynamic>? paymentRequest,
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
