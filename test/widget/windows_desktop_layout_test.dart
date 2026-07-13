import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:schooldesk1/core/desktop/desktop_responsive_breakpoints.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/features/dashboard/presentation/widgets/parent_dashboard_desktop_shell.dart';
import 'package:schooldesk1/features/dashboard/presentation/widgets/principal_dashboard_desktop_shell.dart';
import 'package:schooldesk1/features/dashboard/presentation/widgets/teacher_dashboard_desktop_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Windows breakpoints cover compact through ultra-wide windows', () {
    expect(DesktopBreakpoints.isDesktopWidth(1024), isTrue);
    expect(DesktopBreakpoints.isTwoPaneWidth(1199), isFalse);
    expect(DesktopBreakpoints.isTwoPaneWidth(1200), isTrue);
    expect(DesktopBreakpoints.gridColumnsForWidth(1024), 4);
    expect(DesktopBreakpoints.gridColumnsForWidth(1440), 5);
    expect(DesktopBreakpoints.contentMaxWidth(2560), 1680);
  });

  for (final size in const [
    Size(1024, 640),
    Size(1280, 800),
    Size(1440, 900),
    Size(1920, 1080),
  ]) {
    testWidgets(
      'Windows dashboard shells avoid layout failures at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        for (final dashboard in _dashboards()) {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(body: dashboard),
            ),
          );
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: '${dashboard.runtimeType} failed at $size',
          );
        }
      },
    );
  }
}

List<Widget> _dashboards() => [
  PrincipalDashboardDesktopBody(
    header: const _TestPanel(label: 'Principal header', height: 80),
    searchBar: const _TestPanel(label: 'Search', height: 48),
    statsRow: const _TestPanel(label: 'Statistics', height: 96),
    academicsSection: const _TestPanel(label: 'Academics', height: 180),
    highlights: const _TestPanel(label: 'Highlights', height: 160),
    setupSection: const _TestPanel(label: 'Setup', height: 140),
  ),
  TeacherDashboardDesktopBody(
    teacherName: 'Windows Teacher',
    assignedClass: 'Class 5 A',
    assignedSubject: 'Science',
    timetable: const [],
    announcements: const [],
    attendancePending: 0,
    roleScopeLoaded: true,
    hasStaffLink: false,
    hasAssignedClasses: false,
    onRefresh: () {},
  ),
  ParentDashboardDesktopBody(
    children: const [],
    dashboard: const {},
    activeChildIndex: 0,
    eventPosts: const [],
    onChildSelected: (_) {},
  ),
];

class _TestPanel extends StatelessWidget {
  final String label;
  final double height;

  const _TestPanel({required this.label, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: height, child: Text(label));
  }
}
