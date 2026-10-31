import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/features/attendance/presentation/widgets/teacher_student_attendance_history_sheet.dart';

Map<String, dynamic> record(String date, String section, String year) => {
  'status': 'present',
  'session': {
    'date': date,
    'section': {
      'section_name': section,
      'grade': {'grade_name': 'Nursery'},
    },
    'academic_year': {'year_label': year},
  },
};

Widget sheet(
  Future<List<Map<String, dynamic>>> Function(String) loader, {
  String id = 'student',
}) => MaterialApp(
  home: Scaffold(
    body: TeacherStudentAttendanceHistorySheet(
      studentId: id,
      studentName: id,
      loadHistory: loader,
    ),
  ),
);

void main() {
  testWidgets('transferred student shows original class, year and date', (
    tester,
  ) async {
    await tester.pumpWidget(
      sheet(
        (id) async => [
          record('2025-09-01', 'A', '2025-2026'),
          record('2026-10-24', 'B', '2026-2027'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2025-09-01'), findsOneWidget);
    expect(find.text('Nursery - A · 2025-2026\nPresent'), findsOneWidget);
    expect(find.text('Nursery - B · 2026-2027\nPresent'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('2026-10-24')).dy,
      lessThan(tester.getTopLeft(find.text('2025-09-01')).dy),
    );
  });

  testWidgets('failed read offers retry and successful empty state', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      sheet((_) async {
        if (++attempts == 1) throw StateError('offline');
        return const [];
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('No attendance recorded yet.'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('No attendance recorded yet.'), findsOneWidget);
  });

  testWidgets('switching students ignores late private history responses', (
    tester,
  ) async {
    final first = Completer<List<Map<String, dynamic>>>();
    await tester.pumpWidget(sheet((_) => first.future, id: 'first'));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(sheet((_) async => const [], id: 'second'));
    await tester.pumpAndSettle();
    first.complete([record('2025-09-01', 'A', '2025-2026')]);
    await tester.pumpAndSettle();
    expect(find.text('No attendance recorded yet.'), findsOneWidget);
    expect(find.text('2025-09-01'), findsNothing);
  });

  testWidgets('history fits a narrow screen with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.7)),
          child: child!,
        ),
        home: Scaffold(
          body: TeacherStudentAttendanceHistorySheet(
            studentId: 'student',
            studentName: 'A student with a long name',
            loadHistory: (_) async => [record('2026-10-24', 'B', '2026-2027')],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('2026-10-24'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('2026-10-24'), findsOneWidget);
  });
}
