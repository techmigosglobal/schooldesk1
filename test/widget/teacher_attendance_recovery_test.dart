import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/errors/failures.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/features/attendance/presentation/screens/teacher_attendance_screen/teacher_attendance_screen.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_attendance_context.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_attendance_repository.dart';

class _ScopeAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancel,
  ) async {
    final data = switch (options.path) {
      '/auth/profile' => <String, dynamic>{
        'id': 'user',
        'role_name': 'teacher',
        'linked_id': 'staff',
      },
      '/dashboard/teacher' => <String, dynamic>{
        'staff_id': 'staff',
        'assigned_classes': [
          {
            'id': 'section',
            'grade_name': 'LKG',
            'section_name': 'A',
            'is_class_teacher': true,
          },
          {
            'id': 'co-section',
            'grade_name': 'Nursery',
            'section_name': 'B',
            'is_class_teacher': false,
          },
        ],
      },
      _ => <dynamic>[],
    };
    return ResponseBody.fromString(
      jsonEncode({'success': true, 'data': data, 'total': 0}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Repository implements TeacherAttendanceRepository {
  String status = 'ready';
  String today = '2026-10-18';
  String? end;
  bool failRoster = false;
  bool failHistory = false;
  String? owner;
  bool finalized = false;
  int contexts = 0;
  final dates = <String>[];
  @override
  Future<Result<TeacherAttendanceContext>> loadContext({
    required String sectionId,
  }) async {
    contexts++;
    return Result.ok(
      TeacherAttendanceContext.fromJson({
        'section_id': sectionId,
        'academic_year_id': status == 'missing_year' ? null : 'year',
        'academic_year_start': '2026-06-01',
        'academic_year_end': end ?? '2027-04-30',
        'school_date': today,
        'min_date': status == 'missing_year' || status == 'not_started'
            ? null
            : '2026-06-01',
        'max_date': status == 'missing_year' || status == 'not_started'
            ? null
            : end ?? today,
        'configuration_status': status,
      }),
    );
  }

  @override
  Future<Result<List<StudentModel>>> loadRoster({
    required String sectionId,
    required String date,
  }) async {
    dates.add(date);
    return failRoster
        ? const Result.err(
            ServerFailure(message: 'Unable to load attendance roster'),
          )
        : Result.ok([
            StudentModel.fromJson({
              'id': 'student',
              'first_name': 'Student',
              'last_name': 'One',
              'active_enrollment_id': 'enrollment',
            }),
          ]);
  }

  @override
  Future<Result<List<AttendanceSessionModel>>> loadHistory({
    required String sectionId,
    required String date,
  }) async => failHistory
      ? const Result.err(
          ServerFailure(message: 'Attendance history unavailable'),
        )
      : Result.ok([
          if (owner != null || finalized)
            AttendanceSessionModel.fromJson({
              'id': 'session',
              'section_id': sectionId,
              'date': date,
              'period_number': 1,
              'is_finalized': finalized,
              'status': finalized ? 'submitted' : 'draft',
              'daily_claim': {
                'status': 'claimed',
                'claimed_by_staff_id': owner ?? 'staff',
              },
            }),
        ]);
  @override
  Future<Result<List<Map<String, dynamic>>>> loadStudentEnrollments(
    String id,
  ) async => const Result.ok([]);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    final api = BackendApiClient.instance;
    api.dio.interceptors.clear();
    api.dio.httpClientAdapter = _ScopeAdapter();
    api.setCurrentUserId('user');
    api.setCurrentRole('teacher');
    api.setAuthToken('test');
    RoleAccessService.clear();
    RoleAccessService.resetSignOutGuard();
  });
  Future<void> settle(WidgetTester tester) async {
    // Dio/bootstrap and bundled font IO run outside Flutter's fake clock;
    // the shared teacher background also has continuous decorative animation.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> open(WidgetTester tester, _Repository repo) async {
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() => RoleAccessService.initialize());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: TeacherAttendanceScreen(repository: repo),
      ),
    );
    await settle(tester);
  }

  Future<void> retry(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await settle(tester);
  }

  testWidgets('initial date uses school clock and corrected current year', (
    tester,
  ) async {
    final repo = _Repository()..today = '2026-06-02';
    await open(tester, repo);
    expect(repo.dates, ['2026-06-02']);
    expect(find.text('Choose date · 2026-06-02'), findsOneWidget);
    expect(find.text('Student One'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('ended year clamps historical date and picker stays bounded', (
    tester,
  ) async {
    final repo = _Repository()
      ..today = '2027-05-02'
      ..end = '2027-04-30'
      ..status = 'ended';
    await open(tester, repo);
    expect(repo.dates, ['2027-04-30']);
    await tester.tap(find.text('Choose date · 2027-04-30'));
    await settle(tester);
    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(picker.firstDate, DateTime(2026, 6, 1));
    expect(picker.lastDate, DateTime(2027, 4, 30));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final status in ['missing_year', 'not_started']) {
    testWidgets(
      '$status preserves selection and retries corrected configuration',
      (tester) async {
        final repo = _Repository()..status = status;
        await open(tester, repo);
        expect(find.text('Attendance selection'), findsOneWidget);
        expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
        expect(repo.dates, isEmpty);
        expect(find.textContaining('Bad state'), findsNothing);
        repo.status = 'ready';
        await retry(tester);
        expect(repo.dates, ['2026-10-18']);
        expect(find.text('Student One'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'roster and history failures keep date accessible and recover on retry',
    (tester) async {
      final repo = _Repository()..failRoster = true;
      await open(tester, repo);
      expect(find.text('Choose date · 2026-10-18'), findsOneWidget);
      repo.failRoster = false;
      repo.failHistory = true;
      await retry(tester);
      expect(find.text('Attendance history unavailable'), findsOneWidget);
      expect(find.text('Choose date · 2026-10-18'), findsOneWidget);
      repo.failHistory = false;
      await retry(tester);
      expect(find.text('Student One'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('dirty marks survive resume context refresh', (tester) async {
    final repo = _Repository();
    await open(tester, repo);
    await tester.tap(find.text('All Present'));
    await settle(tester);
    final reads = repo.contexts;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(repo.contexts, reads + 1);
    expect(repo.dates.length, 1);
    await tester.ensureVisible(find.text('Save Draft'));
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Save Draft'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'another teacher claim blocks marking and own reopened claim permits it',
    (tester) async {
      final repo = _Repository()..owner = 'other-staff';
      await open(tester, repo);
      expect(find.text('Attendance in use'), findsOneWidget);
      await tester.tap(find.text('All Present'));
      await settle(tester);
      await tester.ensureVisible(find.text('Save Draft'));
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Save Draft'),
            )
            .onPressed,
        isNull,
      );
      repo.owner = 'staff';
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      await tester.ensureVisible(find.text('All Present'));
      await tester.tap(find.text('All Present'));
      await settle(tester);
      await tester.ensureVisible(find.text('Save Draft'));
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Save Draft'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'finalized primary and co-teacher registers retain correction permissions',
    (tester) async {
      final repo = _Repository()
        ..owner = 'staff'
        ..finalized = true;
      await open(tester, repo);
      expect(find.text('Attendance locked'), findsOneWidget);
      expect(find.text('Request Correction'), findsOneWidget);
      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      dropdown.onChanged!('co-section');
      await settle(tester);
      expect(find.text('Attendance locked'), findsOneWidget);
      expect(find.text('Request Correction'), findsNothing);
      expect(
        find.text(
          'Only the Class Teacher can request an attendance correction.',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
