import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/presentation/teacher_classes_screen/teacher_classes_screen.dart';
import 'package:schooldesk1/services/backend_api_client.dart';
import 'package:schooldesk1/services/role_access_service.dart';

void main() {
  late _FakeBackendAdapter adapter;

  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    RoleAccessService.clear();
    adapter = _FakeBackendAdapter();
    BackendApiClient.instance.dio.httpClientAdapter = adapter;
    BackendApiClient.instance.setAuthToken('test-token');
  });

  test(
    'teacher scope keeps assigned subject from backend timetable even when it is not today',
    () async {
      final nonTodayWeekday = DateTime.now().weekday == DateTime.monday
          ? DateTime.tuesday
          : DateTime.monday;

      adapter.routes['GET /auth/profile'] = _ok({
        'id': 'teacher-user-1',
        'email': 'teacher@example.test',
        'name': 'Backend Teacher',
        'school_id': 'school-1',
        'role_id': 'role-teacher',
        'role_name': 'Teacher',
        'is_active': true,
      });
      adapter.routes['GET /dashboard/teacher'] = _ok({
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
          {'id': 'section-1', 'grade_name': 'Grade 2', 'section_name': 'A'},
        ],
      });
      adapter.routes['GET /students'] = _okList([
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
      ], total: 1);
      adapter.routes['GET /timetable/slots'] = _ok([
        {
          'id': 'slot-1',
          'section_id': 'section-1',
          'staff_id': 'staff-1',
          'subject_id': 'subject-1',
          'day_of_week': nonTodayWeekday,
          'period_number': 1,
          'start_time': '09:00',
          'end_time': '09:45',
          'subject': {'subject_name': 'Robotics'},
        },
      ]);

      await RoleAccessService.initialize();

      expect(RoleAccessService.teacherStaffId, 'staff-1');
      expect(RoleAccessService.teacherClassId, 'section-1');
      expect(RoleAccessService.teacherClassName, 'Grade 2 A');
      expect(RoleAccessService.teacherClassStudents, hasLength(1));
      expect(RoleAccessService.teacherSubject, 'Robotics');
    },
  );

  testWidgets(
    'teacher classes screen initializes backend role scope before rendering assigned class',
    (tester) async {
      _seedTeacherScope(adapter, nonTodayWeekday: DateTime.monday);

      await tester.pumpWidget(const MaterialApp(home: TeacherClassesScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Grade 2 A'), findsWidgets);
      expect(find.textContaining('Linked Student'), findsOneWidget);
      expect(find.textContaining('Not assigned'), findsNothing);
    },
  );
}

Map<String, dynamic> _ok(dynamic data) => {'success': true, 'data': data};

Map<String, dynamic> _okList(
  List<Map<String, dynamic>> rows, {
  required int total,
}) => {
  'success': true,
  'data': rows,
  'total': total,
  'page': 1,
  'page_size': rows.length,
};

void _seedTeacherScope(
  _FakeBackendAdapter adapter, {
  required int nonTodayWeekday,
}) {
  adapter.routes['GET /auth/profile'] = _ok({
    'id': 'teacher-user-1',
    'email': 'teacher@example.test',
    'name': 'Backend Teacher',
    'school_id': 'school-1',
    'role_id': 'role-teacher',
    'role_name': 'Teacher',
    'is_active': true,
  });
  adapter.routes['GET /dashboard/teacher'] = _ok({
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
      {'id': 'section-1', 'grade_name': 'Grade 2', 'section_name': 'A'},
    ],
  });
  adapter.routes['GET /students'] = _okList([
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
  ], total: 1);
  adapter.routes['GET /timetable/slots'] = _ok([
    {
      'id': 'slot-1',
      'section_id': 'section-1',
      'staff_id': 'staff-1',
      'subject_id': 'subject-1',
      'day_of_week': nonTodayWeekday,
      'period_number': 1,
      'start_time': '09:00',
      'end_time': '09:45',
      'subject': {'subject_name': 'Robotics'},
    },
  ]);
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
