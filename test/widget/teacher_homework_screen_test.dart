import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/network/schooldesk_api.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/features/homework/presentation/screens/teacher_homework_screen/teacher_homework_screen.dart';

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
    SchoolDeskApi.instance.dio.httpClientAdapter = adapter;
    SchoolDeskApi.instance.dio.interceptors.clear();
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
    'legacy Dairy remains usable when supplementary submissions fail',
    (tester) async {
      _seedTeacherHomeworkRoutes(adapter);

      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const TeacherHomeworkScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(tester.takeException(), isNull);
      expect(find.text('Dairy / Assignments'), findsOneWidget);
      expect(find.textContaining('ServerException'), findsNothing);

      await tester.tap(find.text('Review'));
      await tester.pump();

      expect(find.text('Legacy Dairy'), findsOneWidget);
    },
  );
}

void _seedTeacherHomeworkRoutes(TestBackendAdapter adapter) {
  adapter.routes['GET /auth/profile'] = {
    'success': true,
    'data': {
      'id': 'teacher-user-1',
      'email': 'teacher@example.test',
      'name': 'Legacy Teacher',
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
        'assigned_classes': 1,
        'assigned_students': 1,
        'homework_total': 0,
        'homework_due': 0,
        'unread_messages': 0,
      },
      'assigned_classes': [
        {
          'id': 'section-1',
          'grade_name': 'LKG',
          'section_name': 'A',
          'is_class_teacher': true,
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
        'first_name': 'Test',
        'last_name': 'Student',
        'current_section_id': 'section-1',
        'status': 'active',
      },
    ],
    'total': 1,
    'page': 1,
    'page_size': 100,
  };
  adapter.handlers['GET /timetable/slots'] = (_) async => {
    'success': true,
    'data': [
      {
        'id': 'slot-1',
        'section_id': 'section-1',
        'staff_id': 'staff-1',
        'subject_id': 'subject-1',
        'day_of_week': 1,
        'period_number': 1,
        'start_time': '09:00',
        'end_time': '09:45',
        'subject': {'subject_name': 'General'},
        'section': {'grade_name': 'LKG', 'section_name': 'A'},
      },
    ],
  };
  adapter.routes['GET /notifications'] = {
    'success': true,
    'data': <Map<String, dynamic>>[],
    'total': 0,
    'unread_count': 0,
  };
  adapter.routes['GET /notifications/preferences'] = {
    'success': true,
    'data': <String, dynamic>{},
  };
  adapter.routes['GET /homework'] = {
    'success': true,
    'data': [
      {
        'id': 'legacy-homework',
        'homework_id': 'legacy-homework',
        'title': 'Legacy Dairy',
        'description': 'Read the story and draw a picture.',
        'subject_id': 'subject-1',
        'section_id': 'section-1',
        'staff_id': 'staff-1',
        'assigned_date': '2026-08-07',
        'submission_date': '2026-08-20',
        // Deliberately absent: this is the legacy record that previously
        // caused the daily-claim UUID filter to receive an empty string.
        'daily_claim': null,
      },
    ],
    'total': 1,
    'page': 1,
    'page_size': 1,
  };
  adapter.routes['GET /homework/reminders/today'] = {
    'success': true,
    'data': {'status': 'pending', 'section_id': 'section-1'},
  };
  adapter.handlers['GET /homework/legacy-homework/submissions'] = (_) async => {
    'success': false,
    'error': 'supplementary submission read failed',
    '__status': 500,
  };
}
