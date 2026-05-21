import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/theme/app_theme.dart';
import 'package:schooldesk1/theme/design_tokens.dart';
import 'package:schooldesk1/widgets/erp_navigation.dart';

void main() {
  testWidgets('SchoolDeskNavigationDrawer renders role navigation accessibly', (
    tester,
  ) async {
    var selectedIndex = -1;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        routes: {
          AppRoutes.adminStudents: (_) =>
              const Scaffold(body: Text('Students page')),
        },
        home: Scaffold(
          drawer: SchoolDeskNavigationDrawer(
            role: SchoolDeskRole.admin,
            portalLabel: 'Admin Portal',
            organizationName: 'Public School',
            organizationSubtitle: 'Operations',
            userName: 'Admin User',
            userSubtitle: 'Administrator',
            initials: 'AD',
            portalIcon: Icons.manage_accounts_rounded,
            selectedIndex: 0,
            onDestinationSelected: (index) => selectedIndex = index,
            sections: const [
              SchoolDeskNavigationSection(
                label: 'Overview',
                items: [
                  SchoolDeskNavigationItem(
                    index: 0,
                    icon: Icons.dashboard_outlined,
                    activeIcon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                    route: AppRoutes.adminDashboard,
                  ),
                  SchoolDeskNavigationItem(
                    index: 1,
                    icon: Icons.school_outlined,
                    activeIcon: Icons.school_rounded,
                    label: 'Students',
                    route: AppRoutes.adminStudents,
                  ),
                ],
              ),
            ],
          ),
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              child: const Text('Open drawer'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open drawer'));
    await tester.pumpAndSettle();

    expect(find.text('Admin Portal'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Dashboard')),
      matchesSemantics(
        label: 'Dashboard, selected',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasSelectedState: true,
        isSelected: true,
      ),
    );

    await tester.tap(find.text('Students'));
    await tester.pumpAndSettle();

    expect(selectedIndex, 1);
    expect(find.text('Students page'), findsOneWidget);
  });

  testWidgets('SchoolDeskNavigationDrawer shows honest unavailable states', (
    tester,
  ) async {
    var selectedIndex = -1;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          drawer: SchoolDeskNavigationDrawer(
            role: SchoolDeskRole.parent,
            portalLabel: 'Parent Portal',
            organizationName: 'Public School',
            organizationSubtitle: 'Family access',
            userName: 'Parent',
            userSubtitle: 'Parent Portal',
            initials: 'PR',
            portalIcon: Icons.family_restroom_rounded,
            selectedIndex: 0,
            onDestinationSelected: (index) => selectedIndex = index,
            sections: const [
              SchoolDeskNavigationSection(
                label: 'School',
                items: [
                  SchoolDeskNavigationItem(
                    index: 7,
                    icon: Icons.event_busy_outlined,
                    activeIcon: Icons.event_busy_rounded,
                    label: 'Leave Requests',
                    route: AppRoutes.parentLeave,
                    enabled: false,
                    disabledReason: 'Backend not ready',
                  ),
                ],
              ),
            ],
          ),
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              child: const Text('Open drawer'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open drawer'));
    await tester.pumpAndSettle();

    expect(find.text('Unavailable'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Leave Requests')),
      matchesSemantics(
        label: 'Leave Requests, unavailable, Backend not ready',
        isButton: true,
        hasEnabledState: true,
        isEnabled: false,
        hasSelectedState: true,
      ),
    );

    await tester.tap(find.text('Leave Requests'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(selectedIndex, -1);
  });
}
