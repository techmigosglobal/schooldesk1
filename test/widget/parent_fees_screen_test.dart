import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/features/finance/presentation/screens/parent_fees_screen/parent_fees_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeBackendAdapter adapter;

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    adapter = _FakeBackendAdapter();
    BackendApiClient.instance.dio.httpClientAdapter = adapter;
    BackendApiClient.instance.setAuthToken('parent-test-token');
    BackendApiClient.instance.setCurrentRole('parent');
  });

  tearDown(() {
    BackendApiClient.instance.clearAuthToken();
  });

  testWidgets('parent fees screen stays stable on a compact phone width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    _seedParentFeesRoutes(adapter);

    final flutterErrors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = flutterErrors.add;
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ParentFeesScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final overflowErrors = flutterErrors
        .where(
          (error) => error.exceptionAsString().contains('A RenderFlex overflowed'),
        )
        .toList();

    expect(find.text('Next Fee Due'), findsOneWidget);
    expect(find.textContaining('Due by'), findsOneWidget);
    expect(overflowErrors, isEmpty);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('parent fees child selector stays scrollable for many children', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    _seedParentFeesRoutes(adapter, multiChild: true);

    final flutterErrors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = flutterErrors.add;
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ParentFeesScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final overflowErrors = flutterErrors
        .where(
          (error) => error.exceptionAsString().contains('A RenderFlex overflowed'),
        )
        .toList();

    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(find.text('Aarav'), findsOneWidget);
    expect(find.text('Diya'), findsOneWidget);
    expect(overflowErrors, isEmpty);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

void _seedParentFeesRoutes(
  _FakeBackendAdapter adapter, {
  bool multiChild = false,
}) {
  adapter.routes['GET /me/students'] = {
    'success': true,
    'data': [
      {
        'id': 'student-1',
        'first_name': 'Aarav',
        'last_name': 'Sharma',
        'admission_number': 'ADM-101',
        'student_code': 'STU-101',
        'current_section': {
          'section_name': 'A',
          'grade': {'grade_name': 'Class 5'},
        },
      },
      if (multiChild)
        {
          'id': 'student-2',
          'first_name': 'Diya',
          'last_name': 'Sharma',
          'admission_number': 'ADM-102',
          'student_code': 'STU-102',
          'current_section': {
            'section_name': 'B',
            'grade': {'grade_name': 'Class 3'},
          },
        },
      if (multiChild)
        {
          'id': 'student-3',
          'first_name': 'Kabir',
          'last_name': 'Sharma',
          'admission_number': 'ADM-103',
          'student_code': 'STU-103',
          'current_section': {
            'section_name': 'C',
            'grade': {'grade_name': 'Class 1'},
          },
        },
      if (multiChild)
        {
          'id': 'student-4',
          'first_name': 'Myra',
          'last_name': 'Sharma',
          'admission_number': 'ADM-104',
          'student_code': 'STU-104',
          'current_section': {
            'section_name': 'D',
            'grade': {'grade_name': 'KG'},
          },
        },
    ],
  };
  adapter.routes['GET /parent/students/student-1/fees'] = {
    'success': true,
    'data': [
      {
        'id': 'invoice-1',
        'invoice_number': 'INV-2026-0001',
        'fee_item_name': 'Tuition Fee',
        'fee_type': 'tuition',
        'billing_mode': 'term_wise',
        'priority': 1,
        'total_amount': 125000.0,
        'paid_amount': 0.0,
        'balance_amount': 125000.0,
        'balance': 125000.0,
        'due_date': '2026-12-31T00:00:00Z',
        'status': 'pending',
        'monthly_amount': 10416.67,
        'term_amount': 41666.67,
        'term_count': 3,
        'items': [
          {
            'description': 'Tuition Fee',
            'amount': 125000.0,
          },
        ],
      },
    ],
  };
  adapter.routes['GET /fees/invoices'] = {
    'success': true,
    'data': [
      {
        'id': 'invoice-1',
        'invoice_number': 'INV-2026-0001',
        'payments': const [],
      },
    ],
    'total': 1,
    'page': 1,
    'page_size': 100,
  };
  adapter.routes['GET /fees/payment-requests'] = {
    'success': true,
    'data': const [],
    'total': 0,
    'page': 1,
    'page_size': 100,
  };
}

class _FakeBackendAdapter implements HttpClientAdapter {
  final Map<String, Map<String, dynamic>> routes = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method.toUpperCase()} ${options.path}';
    final payload = routes[key];
    if (payload == null) {
      return ResponseBody.fromString(
        jsonEncode({'success': false, 'error': 'Missing fake route $key'}),
        404,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
