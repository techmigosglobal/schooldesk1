import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/features/dashboard/presentation/screens/teacher_dashboard_screen/teacher_dashboard_screen.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    RoleAccessService.clear();
  });

  testWidgets('teacher dashboard renders before async role data finishes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: TeacherDashboardScreen(loadData: false)),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Good morning'), findsOneWidget);
    expect(find.byType(SchoolDeskIllustratedActionTile), findsWidgets);
  });

  testWidgets('teacher dashboard renders backend-shaped timetable rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: TeacherDashboardScreen(
          loadData: false,
          initialTimetable: [
            {
              'period': 1,
              'subject': 'Science',
              'class': 'Grade 5',
              'time': '09:00 - 09:45',
            },
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Science - Grade 5'), findsOneWidget);
  });
}
