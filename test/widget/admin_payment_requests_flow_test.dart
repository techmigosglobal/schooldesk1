import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/features/finance/presentation/screens/admin_fees_screen/admin_payment_request_decision_screen.dart';
import 'package:schooldesk1/features/finance/presentation/screens/admin_fees_screen/admin_payment_requests_screen.dart';

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
      if (summary.contains('A RenderFlex overflowed by')) {
        return;
      }
      previousOnError?.call(details);
    };
  });

  tearDown(() {
    BackendApiClient.instance.clearAuthToken();
    FlutterError.onError = previousOnError;
  });

  testWidgets('principal payment requests list unifies all pending aliases', (
    tester,
  ) async {
    _setLargeSurface(tester);
    adapter.routes['GET /fees/payment-requests'] = <String, dynamic>{
      'success': true,
      'data': <Map<String, dynamic>>[
        _requestRow(
          id: 'req-pending',
          status: 'pending',
          studentName: 'Aarav Pending',
        ),
        _requestRow(
          id: 'req-verify',
          status: 'pending_verification',
          studentName: 'Diya Verification',
        ),
        _requestRow(
          id: 'req-submitted',
          status: 'submitted',
          studentName: 'Esha Submitted',
        ),
        _requestRow(
          id: 'req-resubmitted',
          status: 'resubmitted',
          studentName: 'Farhan Resubmitted',
        ),
        _requestRow(
          id: 'req-clarify',
          status: 'clarification_required',
          studentName: 'Kabir Clarification',
        ),
        _requestRow(
          id: 'req-intent',
          status: 'initiated',
          studentName: 'Ishaan Unfinished',
        ),
      ],
    };

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(1280, 1800),
          textScaler: TextScaler.linear(0.9),
        ),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AdminPaymentRequestsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    _drainExpectedOverflow(tester);

    expect(find.text('Aarav Pending'), findsOneWidget);
    expect(find.text('Diya Verification'), findsOneWidget);
    expect(find.text('Esha Submitted'), findsOneWidget);
    expect(find.text('Farhan Resubmitted'), findsOneWidget);
    expect(find.textContaining('Kabir'), findsNothing);
    expect(find.textContaining('Ishaan'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Clarification'));
    await tester.pumpAndSettle();
    _drainExpectedOverflow(tester);

    expect(find.text('Kabir Clarification'), findsOneWidget);
    expect(find.textContaining('Aarav'), findsNothing);
  });

  testWidgets('principal decision screen approves payment requests', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final navigatorKey = GlobalKey<NavigatorState>();
    Map<String, dynamic>? decisionPayload;
    adapter.handlers['PUT /fees/payment-requests/req-approved/decision'] =
        (options) {
          decisionPayload = Map<String, dynamic>.from(options.data as Map);
          return <String, dynamic>{
            'success': true,
            'data': <String, dynamic>{
              'id': 'req-approved',
              'status': 'approved',
            },
          };
        };

    await _pumpDecisionHost(tester, navigatorKey);
    await _pushDecisionScreen(
      tester,
      navigatorKey,
      _requestRow(
        id: 'req-approved',
        status: 'pending',
        studentName: 'Aarav Approved',
        proofUrl: '',
      ),
    );

    await tester.ensureVisible(find.text('Approve Payment').last);
    await tester.tap(find.text('Approve Payment').last);
    await tester.pump(const Duration(seconds: 1));

    expect(decisionPayload?['status'], 'approved');
    expect(find.text('Payment Completed'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('principal decision screen requests clarification', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final navigatorKey = GlobalKey<NavigatorState>();
    Map<String, dynamic>? decisionPayload;
    adapter.handlers['PUT /fees/payment-requests/req-clarify/decision'] =
        (options) {
          decisionPayload = Map<String, dynamic>.from(options.data as Map);
          return <String, dynamic>{
            'success': true,
            'data': <String, dynamic>{
              'id': 'req-clarify',
              'status': 'clarification_required',
            },
          };
        };

    await _pumpDecisionHost(tester, navigatorKey);
    await _pushDecisionScreen(
      tester,
      navigatorKey,
      _requestRow(
        id: 'req-clarify',
        status: 'pending_verification',
        studentName: 'Diya Clarify',
        proofUrl: '',
      ),
    );

    await tester.ensureVisible(find.text('Request Clarification').first);
    await tester.tap(find.text('Request Clarification').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      _decisionRemarksField(),
      'Please upload a clearer UPI screenshot.',
    );
    await tester.ensureVisible(find.text('Request Clarification').last);
    await tester.tap(find.text('Request Clarification').last);
    await tester.pumpAndSettle();

    expect(decisionPayload?['status'], 'clarification_required');
    expect(
      decisionPayload?['admin_remarks'],
      'Please upload a clearer UPI screenshot.',
    );
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('principal decision screen rejects payment requests', (
    tester,
  ) async {
    _setLargeSurface(tester);
    final navigatorKey = GlobalKey<NavigatorState>();
    Map<String, dynamic>? decisionPayload;
    adapter.handlers['PUT /fees/payment-requests/req-reject/decision'] =
        (options) {
          decisionPayload = Map<String, dynamic>.from(options.data as Map);
          return <String, dynamic>{
            'success': true,
            'data': <String, dynamic>{'id': 'req-reject', 'status': 'rejected'},
          };
        };

    await _pumpDecisionHost(tester, navigatorKey);
    await _pushDecisionScreen(
      tester,
      navigatorKey,
      _requestRow(
        id: 'req-reject',
        status: 'pending',
        studentName: 'Kabir Reject',
        proofUrl: '',
      ),
    );

    await tester.ensureVisible(find.text('Reject Payment').first);
    await tester.tap(find.text('Reject Payment').first);
    await tester.pumpAndSettle();
    await tester.enterText(
      _decisionRemarksField(),
      'Transaction reference does not match the proof.',
    );
    await tester.ensureVisible(find.text('Reject Payment').last);
    await tester.tap(find.text('Reject Payment').last);
    await tester.pumpAndSettle();

    expect(decisionPayload?['status'], 'rejected');
    expect(
      decisionPayload?['admin_remarks'],
      'Transaction reference does not match the proof.',
    );
    expect(find.text('Home'), findsOneWidget);
  });
}

Future<void> _pumpDecisionHost(
  WidgetTester tester,
  GlobalKey<NavigatorState> navigatorKey,
) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(
        size: Size(1280, 1800),
        textScaler: TextScaler.linear(0.9),
      ),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: Center(child: Text('Home'))),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pushDecisionScreen(
  WidgetTester tester,
  GlobalKey<NavigatorState> navigatorKey,
  Map<String, dynamic> request,
) async {
  navigatorKey.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => AdminPaymentRequestDecisionScreen(
        args: AdminPaymentRequestDecisionArgs(request: request),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _decisionRemarksField() {
  return find.byType(TextFormField).first;
}

Map<String, dynamic> _requestRow({
  required String id,
  required String status,
  required String studentName,
  String proofUrl = 'https://example.com/proof.png',
}) {
  final nameParts = studentName.split(' ');
  return <String, dynamic>{
    'id': id,
    'status': status,
    'invoice_id': 'invoice-$id',
    'amount': 6.0,
    'payment_date': '2026-07-03',
    'payment_mode': 'upi',
    'request_reference': 'FPR-$id',
    'transaction_id': 'UTR-$id',
    'remarks': 'Parent note',
    'proof_url': proofUrl,
    'invoice': <String, dynamic>{'invoice_number': 'INV-$id'},
    'student': <String, dynamic>{
      'first_name': nameParts.first,
      'last_name': nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '',
    },
    'parent_user': <String, dynamic>{
      'name': 'Parent $studentName',
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
    if (!message.contains('A RenderFlex overflowed by')) {
      throw exception;
    }
  }
}
