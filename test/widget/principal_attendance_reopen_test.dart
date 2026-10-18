import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/network/models/backend_models.dart';
import 'package:schooldesk1/features/attendance/presentation/screens/principal_attendance_screen/principal_attendance_screen.dart';
import 'package:schooldesk1/roles/principal/domain/principal_attendance_repository.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> openStudent(WidgetTester tester, _Repository repository) async {
    await tester.pumpWidget(
      MaterialApp(home: PrincipalAttendanceScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Student Attendance').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Student One'));
    await tester.tap(find.text('Student One'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
  }

  testWidgets('student actions fetch LKG outside the first school-wide page', (
    tester,
  ) async {
    final repository = _Repository();
    await openStudent(tester, repository);
    expect(repository.loadedSessionIds, ['lkg-session']);
    expect(find.text('Notify Nursery Teacher'), findsNothing);
    expect(find.textContaining('LKG Teacher ·'), findsOneWidget);
    await tester.tap(find.text('Reopen Attendance'));
    await tester.pumpAndSettle();
    expect(find.text('Reopen LKG - A on ${repository.date}'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Correct absent status');
    await tester.tap(find.widgetWithText(FilledButton, 'Reopen'));
    await tester.pumpAndSettle();
    expect(repository.reopened, {
      'session': 'lkg-session',
      'section': 'lkg',
      'date': repository.date,
      'student': 'student',
      'reason': 'Correct absent status',
    });
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'no record for selected date never falls back to another register',
    (tester) async {
      final repository = _Repository()..recordDate = '2000-01-01';
      await openStudent(tester, repository);
      expect(find.text('Reopen Attendance'), findsNothing);
      expect(
        find.text(
          'No attendance record for this student on ${repository.date}.',
        ),
        findsOneWidget,
      );
      expect(repository.loadedSessionIds, isEmpty);
      expect(repository.reopened, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('historical register follows the record after a class transfer', (
    tester,
  ) async {
    final repository = _Repository()..recordSection = 'nursery';
    await openStudent(tester, repository);
    expect(repository.loadedSessionIds, ['nursery-session']);
    expect(find.textContaining('Nursery Teacher ·'), findsOneWidget);
    expect(find.text('NURSERY - A'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a changed session context cannot open the action sheet', (
    tester,
  ) async {
    final repository = _Repository()..sessionDate = '2000-01-01';
    await openStudent(tester, repository);
    expect(find.text('Reopen Attendance'), findsNothing);
    expect(
      find.text('Attendance context changed. Refresh and try again.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('multiple registers require choosing the intended period', (
    tester,
  ) async {
    final repository = _Repository()..multiple = true;
    await openStudent(tester, repository);
    expect(find.text('Choose register for ${repository.date}'), findsOneWidget);
    expect(find.text('Reopen Attendance'), findsNothing);
    await tester.tap(find.textContaining('Period 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reopen Attendance'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Second period correction');
    await tester.tap(find.widgetWithText(FilledButton, 'Reopen'));
    await tester.pumpAndSettle();
    expect(repository.reopened?['session'], 'lkg-session-2');
    await tester.pumpWidget(const SizedBox());
  });
}

class _Repository implements PrincipalAttendanceRepository {
  final date = DateTime.now().toIso8601String().split('T').first;
  String? recordDate;
  String? sessionDate;
  String recordSection = 'lkg';
  bool multiple = false;
  final loadedSessionIds = <String>[];
  Map<String, String?>? reopened;

  AttendanceSessionModel session(String id) => AttendanceSessionModel.fromJson({
    'id': id,
    'section_id': id.startsWith('nursery') ? 'nursery' : 'lkg',
    'date': sessionDate ?? date,
    'status': 'submitted',
    'is_finalized': true,
    'period_number': id.endsWith('-2') ? 2 : 1,
    'total_students': 1,
    'present_count': 0,
    'staff': {
      'first_name': id.startsWith('nursery')
          ? 'Nursery Teacher'
          : 'LKG Teacher',
    },
    'student_attendances': [
      {'student_id': 'student', 'status': 'absent'},
    ],
  });

  @override
  Future<AttendanceSessionModel> loadSession(String sessionId) async {
    loadedSessionIds.add(sessionId);
    return session(sessionId);
  }

  @override
  Future<PaginatedList<AttendanceSessionModel>> loadSessions({
    String? startDate,
    String? endDate,
    String? date,
    int page = 1,
    int pageSize = 20,
  }) async => PaginatedList(
    data: [session('nursery-session')],
    total: 21,
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<List<SectionModel>> loadSections() async => [
    SectionModel.fromJson({
      'id': 'lkg',
      'section_name': 'A',
      'grade': {'grade_name': 'LKG'},
    }),
    SectionModel.fromJson({
      'id': 'nursery',
      'section_name': 'A',
      'grade': {'grade_name': 'NURSERY'},
    }),
  ];

  @override
  Future<PaginatedList<StudentModel>> loadStudents({
    required String sectionId,
    required int page,
    required int pageSize,
  }) async => PaginatedList(
    data: [
      StudentModel.fromJson({
        'id': 'student',
        'school_id': 'school',
        'first_name': 'Student',
        'last_name': 'One',
        'current_section_id': 'lkg',
      }),
    ],
    total: 1,
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<List<Map<String, dynamic>>> loadStudentAttendanceRecords(
    String studentId, {
    int? month,
    int? year,
  }) async => [
    for (final suffix in ['', if (multiple) '-2'])
      {
        'session_id': '$recordSection-session$suffix',
        'student_id': studentId,
        'status': 'absent',
        'session': {
          'id': '$recordSection-session$suffix',
          'section_id': recordSection,
          'date': recordDate ?? date,
        },
      },
  ];

  @override
  Future<AttendanceSessionModel> reopenSession(
    String sessionId, {
    required String reason,
    required String sectionId,
    required String date,
    String? studentId,
  }) async {
    reopened = {
      'session': sessionId,
      'section': sectionId,
      'date': date,
      'student': studentId,
      'reason': reason,
    };
    return session(sessionId);
  }

  @override
  Future<List<StaffAttendanceModel>> loadStaffAttendance({
    String? startDate,
    String? endDate,
    String? date,
  }) async => [];
  @override
  Future<PaginatedList<StaffModel>> loadStaff({
    required int page,
    required int pageSize,
    String? status,
  }) async => PaginatedList(data: [], total: 0, page: page, pageSize: pageSize);
  @override
  Future<Map<String, dynamic>> loadStaffDailySummary({
    required String date,
  }) async => {};
  @override
  Future<Map<String, dynamic>> createReportExport({
    required String path,
    required String reportTitle,
    required String format,
    String reportType = '',
    String scope = '',
    Map<String, dynamic> parameters = const {},
  }) async => {};
}
