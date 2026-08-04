import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/features/academics/presentation/screens/admin_timetable_screen/admin_timetable_screen.dart';

import '../support/finance_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestBackendAdapter adapter;
  late Map<String, dynamic>? replacePayload;

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    adapter = TestBackendAdapter();
    replacePayload = null;
    BackendApiClient.instance.dio.httpClientAdapter = adapter;
    BackendApiClient.instance.setAuthToken('leadership-test-token');
    BackendApiClient.instance.setCurrentRole('principal');
    _seedRoutes(adapter);
    adapter.handlers['PUT /timetable/slots/replace-days'] = (options) async {
      replacePayload = Map<String, dynamic>.from(options.data as Map);
      return <String, dynamic>{
        'success': true,
        'data': {'created_count': 15, 'days': replacePayload?['days']},
      };
    };
  });

  tearDown(() {
    BackendApiClient.instance.clearAuthToken();
  });

  testWidgets('editor starts with three rows and mapped subjects only', (
    tester,
  ) async {
    await _pumpEditor(tester);

    expect(find.text('Select class to continue'), findsOneWidget);
    await tester.tap(find.text('Create Timetable'));
    await tester.pumpAndSettle();

    expect(find.text('Timetable rows'), findsOneWidget);
    expect(find.text('Free Period'), findsNWidgets(3));
    await tester.tap(find.text('Free Period').first);
    await tester.pump();
    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.text('Unmapped Art'), findsNothing);
    await tester.tapAt(const Offset(1000, 100));
    await tester.pump();
    expect(find.text('Apply to days'), findsOneWidget);
    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('Friday'), findsOneWidget);
  });

  testWidgets('editor opens cleanly on a phone viewport', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const AdminTimetableScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Timetable'));
    await tester.pumpAndSettle();

    expect(find.text('Timetable rows'), findsOneWidget);
    expect(find.text('Apply to days'), findsOneWidget);
  });

  testWidgets('day selection and row actions update the shared editor', (
    tester,
  ) async {
    await _pumpEditor(tester);
    await tester.tap(find.text('Create Timetable'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Monday'));
    await tester.pump();
    expect(
      find.text(
        '5 days selected. Row edits and plus/minus apply to all selected days.',
      ),
      findsOneWidget,
    );

    final addButton = find.byIcon(Icons.add_circle_outline_rounded).first;
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pump();
    expect(find.text('Free Period'), findsNWidgets(4));

    final removeButton = find.byIcon(Icons.remove_circle_outline_rounded).first;
    await tester.ensureVisible(removeButton);
    await tester.tap(removeButton);
    await tester.pump();
    expect(find.text('Free Period'), findsNWidgets(3));
  });

  testWidgets('manual time validation rejects partial rows before save', (
    tester,
  ) async {
    await _pumpEditor(tester);
    await tester.tap(find.text('Create Timetable'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '9:00');
    await tester.enterText(fields.at(1), '09:30');
    await tester.tap(find.text('Save Timetable'));
    await tester.pump();

    expect(find.text('Enter From and To as HH:MM for row 1.'), findsOneWidget);
    expect(replacePayload, isNull);
  });

  testWidgets('save sends free periods and only selected days', (tester) async {
    await _pumpEditor(tester);
    await tester.tap(find.text('Create Timetable'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    const starts = ['08:00', '09:00', '10:00'];
    const ends = ['08:30', '09:30', '10:30'];
    for (var row = 0; row < 3; row++) {
      await tester.enterText(fields.at(row * 2), starts[row]);
      await tester.enterText(fields.at(row * 2 + 1), ends[row]);
    }
    await tester.tap(find.text('Save Timetable'));
    await tester.pumpAndSettle();

    expect(replacePayload, isNotNull);
    expect(replacePayload?['days'], [1, 2, 3, 4, 5, 6]);
    final rows = replacePayload?['rows'] as List<dynamic>;
    expect(rows, hasLength(3));
    expect(rows.every((row) => (row as Map)['subject_id'] == null), isTrue);
  });
}

Future<void> _pumpEditor(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1100, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.lightTheme, home: const AdminTimetableScreen()),
  );
  await tester.pumpAndSettle();
}

void _seedRoutes(TestBackendAdapter adapter) {
  adapter.routes['GET /academic-years'] = {
    'success': true,
    'data': [
      {
        'id': 'year-1',
        'school_id': 'school-1',
        'year_label': '2026-2027',
        'start_date': '2026-04-01',
        'end_date': '2027-03-31',
        'is_current': true,
        'status': 'active',
      },
    ],
  };
  adapter.routes['GET /sections'] = {
    'success': true,
    'data': [
      {
        'id': 'section-1',
        'grade_id': 'grade-1',
        'academic_year_id': 'year-1',
        'section_name': 'A',
        'grade': {'id': 'grade-1', 'grade_name': 'Grade 2'},
        'capacity': 30,
      },
    ],
  };
  adapter.routes['GET /timetable/working-days'] = {
    'success': true,
    'data': {
      'days': [1, 2, 3, 4, 5, 6],
    },
  };
  adapter.routes['GET /timetable/slots'] = {
    'success': true,
    'data': <Map<String, dynamic>>[],
  };
  adapter.routes['GET /subjects'] = {
    'success': true,
    'data': [
      {'id': 'subject-math', 'subject_name': 'Mathematics'},
      {'id': 'subject-art', 'subject_name': 'Unmapped Art'},
    ],
  };
  adapter.routes['GET /grade-subjects'] = {
    'success': true,
    'data': [
      {
        'id': 'mapping-1',
        'subject_id': 'subject-math',
        'grade_id': 'grade-1',
        'academic_year_id': 'year-1',
      },
    ],
  };
  adapter.routes['GET /staff-subjects'] = {
    'success': true,
    'data': <Map<String, dynamic>>[],
  };
}
