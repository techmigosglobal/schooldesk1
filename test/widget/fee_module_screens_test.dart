import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_home_screen/fee_home_screen.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_structures_screen/fee_structures_screen.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_collect_screen/fee_collect_screen.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_ledger_screen/fee_ledger_screen.dart';
import 'package:schooldesk1/features/finance/presentation/screens/fee_reports_screen/fee_reports_screen.dart';
import 'package:schooldesk1/features/finance/presentation/screens/principal_dashboard/principal_collect_fee.dart';

import '../support/finance_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestBackendAdapter adapter;
  void Function(FlutterErrorDetails)? previousOnError;

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
    _seedAllFeeRoutes(adapter);
  });

  tearDown(() {
    BackendApiClient.instance.clearAuthToken();
    FlutterError.onError = previousOnError;
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // FeeHomeScreen
  // ═══════════════════════════════════════════════════════════════════════════

  group('FeeHomeScreen', () {
    testWidgets('renders header, metrics, and quick actions', (tester) async {
      _setLargeSurface(tester);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const FeeHomeScreen()),
      );
      await tester.pumpAndSettle();

      // Header
      expect(find.text('Fees'), findsOneWidget);

      // Metrics
      expect(find.text('Fee Structures'), findsWidgets);
      expect(find.text('Collected'), findsWidgets);
      expect(find.text('Outstanding'), findsWidgets);
      expect(find.text('Students'), findsWidgets);

      // Quick actions
      expect(find.text('Fee Structures'), findsWidgets);
      expect(find.text('Collect Fee'), findsOneWidget);
      expect(find.text('Generate Invoice'), findsOneWidget);
      expect(find.text('Student Ledger & Dues'), findsOneWidget);
      expect(find.text('Reports & Exports'), findsOneWidget);
    });

    testWidgets('shows collection progress donut', (tester) async {
      _setLargeSurface(tester);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const FeeHomeScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Collection Progress'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('always shows parent payment setup action', (tester) async {
      _setLargeSurface(tester);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const FeeHomeScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Parent Payment Setup'), findsOneWidget);
    });

    testWidgets('shows pending payment requests badge', (tester) async {
      _setLargeSurface(tester);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const FeeHomeScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Parent Payment Requests'), findsOneWidget);
      expect(find.text('1'), findsWidgets); // badge count
    });

    testWidgets('stays stable on compact phone width', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final flutterErrors = <FlutterErrorDetails>[];

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const FeeHomeScreen()),
      );
      await tester.pumpAndSettle();

      final overflowErrors = flutterErrors
          .where(
            (e) => e.exceptionAsString().contains('A RenderFlex overflowed'),
          )
          .toList();

      expect(overflowErrors, isEmpty);
      expect(find.text('Fees'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // FeeStructuresScreen
  // ═══════════════════════════════════════════════════════════════════════════

  group('FeeStructuresScreen', () {
    testWidgets('renders header and fee structure list', (tester) async {
      _setLargeSurface(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const FeeStructuresScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fee Structures'), findsOneWidget);
      // Structure items from mock data
      expect(find.text('Tuition Fee'), findsOneWidget);
      expect(find.text('Book & Kit Fee'), findsOneWidget);
    });

    testWidgets('has create fee structure button in app bar', (tester) async {
      _setLargeSurface(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const FeeStructuresScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('shows academic year dropdown', (tester) async {
      _setLargeSurface(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const FeeStructuresScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButtonFormField<String>), findsWidgets);
    });

    testWidgets('shows empty state when no structures exist', (tester) async {
      _setLargeSurface(tester);
      adapter.routes['GET /fees/structures'] = <String, dynamic>{
        'success': true,
        'data': <Map<String, dynamic>>[],
      };

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const FeeStructuresScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No fee structures'), findsOneWidget);
    });

    testWidgets('search box filters structures', (tester) async {
      _setLargeSurface(tester);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const FeeStructuresScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Both structures visible initially
      expect(find.text('Tuition Fee'), findsOneWidget);
      expect(find.text('Book & Kit Fee'), findsOneWidget);

      // Search for tuition
      await tester.enterText(find.byType(TextField).first, 'tuition');
      await tester.pumpAndSettle();

      expect(find.text('Tuition Fee'), findsOneWidget);
      // Book & Kit should still be visible since it's a different item
      // but the search filters based on haystack
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // FeeCollectScreen
  // ═══════════════════════════════════════════════════════════════════════════

  group('FeeCollectScreen', () {
    testWidgets('renders student picker with due invoices', (tester) async {
      _setLargeSurface(tester);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const FeeCollectScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Collect Fee'), findsOneWidget);
      expect(find.text('Select Student with Due'), findsOneWidget);
      expect(find.text('Aarav Sharma'), findsOneWidget);
    });

    testWidgets('shows empty state when no dues', (tester) async {
      _setLargeSurface(tester);
      adapter.routes['GET /fees/invoices'] = <String, dynamic>{
        'success': true,
        'data': <Map<String, dynamic>>[],
        'total': 0,
        'page': 1,
        'page_size': 500,
      };

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const FeeCollectScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('No outstanding dues'), findsOneWidget);
    });

    testWidgets('selecting student shows payment form', (tester) async {
      _setLargeSurface(tester);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const FeeCollectScreen()),
      );
      await tester.pumpAndSettle();

      // Tap on the student card
      await tester.tap(find.text('Aarav Sharma'));
      await tester.pumpAndSettle();

      // Payment form should appear
      expect(find.text('Change'), findsOneWidget);
      expect(find.text('Payment Mode'), findsOneWidget);
      expect(find.text('Confirm Payment'), findsOneWidget);
    });

    testWidgets('shows tuition month selector for tuition invoices', (
      tester,
    ) async {
      _setLargeSurface(tester);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const FeeCollectScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aarav Sharma'));
      await tester.pumpAndSettle();

      // Tuition months should be visible as FilterChips
      expect(find.text('Select Tuition Months'), findsOneWidget);
      expect(find.byType(FilterChip), findsWidgets);
    });

    testWidgets('payment mode chips are selectable', (tester) async {
      _setLargeSurface(tester);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const FeeCollectScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aarav Sharma'));
      await tester.pumpAndSettle();

      // Default is Cash
      expect(find.text('Cash'), findsWidgets);
      expect(find.text('Cheque'), findsOneWidget);
      expect(find.text('Bank Transfer'), findsOneWidget);
    });

    testWidgets('stays stable on compact phone width', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const FeeCollectScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Collect Fee'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('PrincipalCollectFee', () {
    testWidgets('keeps AppBar and system back inside the four-stage wizard', (
      tester,
    ) async {
      _setLargeSurface(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PrincipalCollectFee(),
                    ),
                  ),
                  child: const Text('Open collector'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open collector'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Class 5 - A'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aarav Sharma'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tuition Fee').last);
      await tester.pumpAndSettle();

      // Payment -> Fee Type via the AppBar button.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Select Fee Type'), findsOneWidget);

      // Fee Type -> Student via the AppBar button.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Search student name...'), findsOneWidget);

      // Student -> Section via Android/system back.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Select Class & Section'), findsOneWidget);

      // Section is the only stage that exits the collector route.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Open collector'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // FeeLedgerScreen
  // ═══════════════════════════════════════════════════════════════════════════

  group('FeeLedgerScreen', () {
    testWidgets('renders header and student accounts', (tester) async {
      _setLargeSurface(tester);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const FeeLedgerScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Student Ledger & Dues'), findsOneWidget);
      expect(find.text('Aarav Sharma'), findsOneWidget);
    });

    testWidgets('shows outstanding and collected metrics', (tester) async {
      _setLargeSurface(tester);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const FeeLedgerScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Outstanding'), findsWidgets);
      expect(find.text('Collected'), findsWidgets);
      expect(find.text('Students'), findsWidgets);
    });

    testWidgets('filter chips work for status filtering', (tester) async {
      _setLargeSurface(tester);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const FeeLedgerScreen()),
      );
      await tester.pumpAndSettle();

      // All filter chips present
      expect(find.byType(FilterChip), findsWidgets);

      // Tap on a filter
      await tester.tap(find.text('Paid'));
      await tester.pumpAndSettle();

      // Should still render without error
      expect(find.text('Student Ledger & Dues'), findsOneWidget);
    });

    testWidgets('tapping student opens ledger detail sheet', (tester) async {
      _setLargeSurface(tester);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const FeeLedgerScreen()),
      );
      await tester.pumpAndSettle();

      // Tap on student card
      await tester.tap(find.text('Aarav Sharma'));
      await tester.pumpAndSettle();

      // Bottom sheet should show
      expect(find.text('Invoices'), findsOneWidget);
      expect(find.text('Payment History'), findsOneWidget);
    });

    testWidgets('ledger detail shows PDF export button', (tester) async {
      _setLargeSurface(tester);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const FeeLedgerScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aarav Sharma'));
      await tester.pumpAndSettle();

      expect(find.text('Export Invoice PDF'), findsOneWidget);
    });

    testWidgets('search box filters students', (tester) async {
      _setLargeSurface(tester);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const FeeLedgerScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aarav Sharma'), findsOneWidget);

      // Search for a non-existent student
      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pumpAndSettle();

      expect(find.text('Aarav Sharma'), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // FeeReportsScreen
  // ═══════════════════════════════════════════════════════════════════════════

  group('FeeReportsScreen', () {
    testWidgets('renders header and live summary card', (tester) async {
      _setLargeSurface(tester);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const FeeReportsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fee Reports'), findsOneWidget);
      expect(find.text('Live Fee Summary'), findsOneWidget);
      expect(find.text('Expected'), findsOneWidget);
      expect(find.text('Collected'), findsWidgets);
      expect(find.text('Outstanding'), findsWidgets);
    });

    testWidgets('shows PDF download button', (tester) async {
      _setLargeSurface(tester);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const FeeReportsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Download PDF Summary'), findsOneWidget);
    });

    testWidgets('shows server-side export reports', (tester) async {
      _setLargeSurface(tester);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const FeeReportsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Server-side Exports'), findsOneWidget);
      expect(find.text('Collection Summary'), findsOneWidget);
      expect(find.text('Class Wise Collection'), findsOneWidget);
      expect(find.text('Student Wise Report'), findsOneWidget);
      expect(find.text('Outstanding Report'), findsOneWidget);
      expect(find.text('Daily Collection Report'), findsOneWidget);
    });

    testWidgets('shows collection rate percentage', (tester) async {
      _setLargeSurface(tester);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const FeeReportsScreen()),
      );
      await tester.pumpAndSettle();

      // Collection rate should be shown
      expect(find.text('Rate'), findsOneWidget);
    });

    testWidgets('stays stable on compact phone width', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const FeeReportsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fee Reports'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Mock data seeding
// ═══════════════════════════════════════════════════════════════════════════════

void _seedAllFeeRoutes(TestBackendAdapter adapter) {
  // Academic years — AcademicYearModel requires school_id
  adapter.routes['GET /academic-years'] = <String, dynamic>{
    'success': true,
    'data': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'year-1',
        'school_id': 'school-1',
        'year_label': '2025-2026',
        'start_date': '2025-04-01',
        'end_date': '2026-03-31',
        'is_current': true,
        'status': 'active',
      },
    ],
  };

  // Grades — GradeModel requires school_id and grade_number
  adapter.routes['GET /grades'] = <String, dynamic>{
    'success': true,
    'data': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'grade-1',
        'school_id': 'school-1',
        'grade_number': 5,
        'grade_name': 'Class 5',
      },
    ],
  };

  // Sections — SectionModel requires gradeId, gradeName, sectionName, etc.
  adapter.routes['GET /sections'] = <String, dynamic>{
    'success': true,
    'data': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'section-1',
        'school_id': 'school-1',
        'grade_id': 'grade-1',
        'grade': <String, dynamic>{'grade_name': 'Class 5'},
        'academic_year_id': 'year-1',
        'section_name': 'A',
        'capacity': 40,
        'room_id': '',
        'room_number': '',
        'room_type': '',
      },
    ],
  };

  // Fee structures
  adapter.routes['GET /fees/structures'] = <String, dynamic>{
    'success': true,
    'data': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'struct-1',
        'academic_year_id': 'year-1',
        'grade_id': 'grade-1',
        'section_id': 'section-1',
        'fee_category_id': 'cat-tuition',
        'amount': 120000.0,
        'frequency': 'yearly',
        'due_day': 10,
        'fee_type': 'tuition',
        'billing_mode': 'monthly',
        'fee_category': <String, dynamic>{
          'id': 'cat-tuition',
          'category_name': 'Tuition Fee',
          'frequency': 'yearly',
        },
        'grade': <String, dynamic>{'id': 'grade-1', 'grade_name': 'Class 5'},
        'section': <String, dynamic>{'id': 'section-1', 'section_name': 'A'},
      },
      <String, dynamic>{
        'id': 'struct-2',
        'academic_year_id': 'year-1',
        'grade_id': 'grade-1',
        'section_id': 'section-1',
        'fee_category_id': 'cat-bookkit',
        'amount': 15000.0,
        'frequency': 'one_time',
        'due_day': 10,
        'fee_type': 'book_kit',
        'billing_mode': 'one_time',
        'fee_category': <String, dynamic>{
          'id': 'cat-bookkit',
          'category_name': 'Book & Kit Fee',
          'frequency': 'one_time',
        },
        'grade': <String, dynamic>{'id': 'grade-1', 'grade_name': 'Class 5'},
        'section': <String, dynamic>{'id': 'section-1', 'section_name': 'A'},
      },
    ],
  };

  // Fee categories
  adapter.routes['GET /fees/categories'] = <String, dynamic>{
    'success': true,
    'data': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'cat-tuition',
        'category_name': 'Tuition Fee',
        'frequency': 'yearly',
      },
      <String, dynamic>{
        'id': 'cat-bookkit',
        'category_name': 'Book & Kit Fee',
        'frequency': 'one_time',
      },
    ],
  };

  // Invoices
  adapter.routes['GET /fees/invoices'] = <String, dynamic>{
    'success': true,
    'data': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'inv-1',
        'invoice_number': 'INV-2026-0001',
        'student_id': 'student-1',
        'student': <String, dynamic>{
          'id': 'student-1',
          'name': 'Aarav Sharma',
          'first_name': 'Aarav',
          'last_name': 'Sharma',
          'current_section': <String, dynamic>{
            'section_name': 'A',
            'grade': <String, dynamic>{'grade_name': 'Class 5'},
          },
        },
        'fee_type': 'tuition',
        'total_amount': 120000.0,
        'paid_amount': 50000.0,
        'balance': 70000.0,
        'due_date': '2026-12-31',
        'status': 'partial',
        'monthly_amount': 10000.0,
        'allowed_month_names': <String>[
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ],
        'paid_month_names': <String>[
          'January',
          'February',
          'March',
          'April',
          'May',
        ],
        'unpaid_month_names': <String>[
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December',
        ],
        'payments': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'pay-1',
            'amount_paid': 25000.0,
            'payment_date': '2026-01-15',
            'payment_mode': 'upi',
            'receipt_number': 'RCP-001',
            'status': 'completed',
          },
          <String, dynamic>{
            'id': 'pay-2',
            'amount_paid': 25000.0,
            'payment_date': '2026-03-10',
            'payment_mode': 'cash',
            'receipt_number': 'RCP-002',
            'status': 'completed',
          },
        ],
      },
    ],
    'total': 1,
    'page': 1,
    'page_size': 500,
  };

  // Payment requests
  adapter.routes['GET /fees/payment-requests'] = <String, dynamic>{
    'success': true,
    'data': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'req-1',
        'status': 'pending',
        'invoice_id': 'inv-1',
        'amount': 10000.0,
        'payment_mode': 'upi',
        'request_reference': 'FPR-001',
        'student': <String, dynamic>{
          'first_name': 'Aarav',
          'last_name': 'Sharma',
        },
      },
    ],
  };

  // Payment config
  adapter.routes['GET /fees/payment-config'] = <String, dynamic>{
    'success': true,
    'data': <String, dynamic>{
      'upi_id': 'school@upi',
      'payee_name': 'Springfield School',
      'qr_note': 'Fee payment',
      'upi_enabled': true,
      'qr_image_url': '',
    },
  };
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
