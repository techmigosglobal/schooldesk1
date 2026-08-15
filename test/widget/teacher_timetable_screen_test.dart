import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/features/academics/presentation/screens/teacher_timetable_screen/teacher_timetable_screen.dart';

import '../support/finance_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestBackendAdapter adapter;

  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    RoleAccessService.clear();
    RoleAccessService.resetSignOutGuard();
    adapter = TestBackendAdapter();
    BackendApiClient.instance.dio.httpClientAdapter = adapter;
    BackendApiClient.instance.setAuthToken('teacher-test-token');
    BackendApiClient.instance.setCurrentRole('teacher');
    BackendApiClient.instance.setCurrentUserId('teacher-user-1');
    await BackendApiClient.instance.invalidateCachedReads();
  });

  tearDown(() {
    BackendApiClient.instance.clearAuthToken();
    RoleAccessService.clear();
  });

  testWidgets(
    'teacher timetable shows configured weekdays horizontally and filters by day',
    (tester) async {
      final workingDays = _workingDaysWithoutToday();
      _seedTeacherRoutes(adapter, workingDays: workingDays);

      await _pumpTeacherTimetable(tester);

      final selectorFinder = find.byKey(
        const ValueKey('teacher-timetable-weekday-selector'),
      );
      final selector = tester.widget<ListView>(selectorFinder);
      expect(selector.scrollDirection, Axis.horizontal);
      expect(
        find.byKey(ValueKey('teacher-timetable-day-${workingDays.first}')),
        findsOneWidget,
      );
      final selectedDayCard = find.byKey(
        const ValueKey('teacher-timetable-selected-day'),
      );
      expect(
        find.descendant(
          of: selectedDayCard,
          matching: find.text('Mathematics'),
        ),
        findsOneWidget,
      );
      expect(find.text(_dayName(workingDays.first)), findsOneWidget);

      await tester.tap(
        find.byKey(ValueKey('teacher-timetable-day-${workingDays[1]}')),
      );
      await tester.pump();

      expect(
        find.descendant(of: selectedDayCard, matching: find.text('Science')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: selectedDayCard,
          matching: find.text('Mathematics'),
        ),
        findsNothing,
      );
      expect(find.text(_dayName(workingDays[1])), findsOneWidget);
    },
  );

  testWidgets('teacher timetable shows a day-specific empty state', (
    tester,
  ) async {
    final workingDays = _workingDaysWithoutToday();
    _seedTeacherRoutes(adapter, workingDays: workingDays);

    await _pumpTeacherTimetable(tester);
    await tester.tap(
      find.byKey(ValueKey('teacher-timetable-day-${workingDays[2]}')),
    );
    await tester.pump();

    expect(
      find.text('No classes scheduled for ${_dayName(workingDays[2])}.'),
      findsOneWidget,
    );
    final selectedDayCard = find.byKey(
      const ValueKey('teacher-timetable-selected-day'),
    );
    expect(
      find.descendant(of: selectedDayCard, matching: find.text('Mathematics')),
      findsNothing,
    );
    expect(
      find.descendant(of: selectedDayCard, matching: find.text('Science')),
      findsNothing,
    );
  });

  testWidgets('multiple teacher sections retain the class selector', (
    tester,
  ) async {
    final workingDays = _workingDaysWithoutToday();
    _seedTeacherRoutes(
      adapter,
      workingDays: workingDays,
      multipleSections: true,
    );

    await _pumpTeacherTimetable(tester);

    final classSelector = find.byWidgetPredicate(
      (widget) => widget is DropdownButtonFormField<String>,
    );
    expect(classSelector, findsOneWidget);
    expect(find.text('Grade 2 - A'), findsWidgets);

    await tester.tap(classSelector);
    await tester.pump();
    expect(find.text('Grade 3 - B'), findsOneWidget);
  });
}

Future<void> _pumpTeacherTimetable(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: const TeacherTimetableScreen(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  expect(tester.takeException(), isNull);
}

void _seedTeacherRoutes(
  TestBackendAdapter adapter, {
  required List<int> workingDays,
  bool multipleSections = false,
}) {
  adapter.routes['GET /auth/profile'] = {
    'success': true,
    'data': {
      'id': 'teacher-user-1',
      'email': 'teacher@example.test',
      'name': 'Backend Teacher',
      'school_id': 'school-1',
      'role_id': 'role-teacher',
      'role_name': 'Teacher',
      'is_active': true,
    },
  };
  adapter.routes['GET /dashboard/teacher'] = {
    'success': true,
    'data': {
      'role': 'Teacher',
      'staff_id': 'staff-1',
      'metrics': {
        'assigned_classes': multipleSections ? 2 : 1,
        'assigned_students': 2,
        'homework_total': 0,
        'homework_due': 0,
        'unread_messages': 0,
      },
      'assigned_classes': [
        {
          'id': 'section-1',
          'grade_name': 'Grade 2',
          'section_name': 'A',
          'is_class_teacher': true,
        },
        if (multipleSections)
          {
            'id': 'section-2',
            'grade_name': 'Grade 3',
            'section_name': 'B',
            'is_class_teacher': false,
          },
      ],
    },
  };
  adapter.routes['GET /students'] = {
    'success': true,
    'data': [
      {
        'id': 'student-1',
        'school_id': 'school-1',
        'student_code': 'STU-1',
        'admission_number': 'ADM-1',
        'first_name': 'Linked',
        'last_name': 'Student',
        'current_section_id': 'section-1',
        'status': 'active',
      },
    ],
    'total': 1,
    'page': 1,
    'page_size': 100,
  };
  adapter.routes['GET /timetable/working-days'] = {
    'success': true,
    'data': {'days': workingDays},
  };

  adapter.handlers['GET /timetable/slots'] = (options) async {
    final sectionId = options.queryParameters['section_id']?.toString();
    final rows = <Map<String, dynamic>>[
      _slot(
        id: 'slot-mathematics',
        sectionId: 'section-1',
        day: workingDays.first,
        period: 1,
        subject: 'Mathematics',
        grade: 'Grade 2',
        section: 'A',
      ),
      _slot(
        id: 'slot-science',
        sectionId: 'section-1',
        day: workingDays[1],
        period: 2,
        subject: 'Science',
        grade: 'Grade 2',
        section: 'A',
      ),
      if (multipleSections)
        _slot(
          id: 'slot-language',
          sectionId: 'section-2',
          day: workingDays.first,
          period: 1,
          subject: 'Language',
          grade: 'Grade 3',
          section: 'B',
        ),
    ];
    return {
      'success': true,
      'data': sectionId == null
          ? rows
          : rows.where((row) => row['section_id'] == sectionId).toList(),
    };
  };
}

Map<String, dynamic> _slot({
  required String id,
  required String sectionId,
  required int day,
  required int period,
  required String subject,
  required String grade,
  required String section,
}) => {
  'id': id,
  'section_id': sectionId,
  'staff_id': 'staff-1',
  'subject_id': id,
  'day_of_week': day,
  'period_number': period,
  'start_time': '09:00',
  'end_time': '09:45',
  'subject': {'subject_name': subject},
  'section': {'grade_name': grade, 'section_name': section},
};

List<int> _workingDaysWithoutToday() {
  final today = DateTime.now().weekday;
  return [
    for (var day = DateTime.monday; day <= DateTime.sunday; day++)
      if (day != today) day,
  ];
}

String _dayName(int day) {
  const days = [
    '',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return days[day];
}
