import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/constants/schooldesk_glossary.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/services/backend_api_client.dart';
import 'package:schooldesk1/theme/app_theme.dart';
import 'package:schooldesk1/widgets/erp_module_scaffold.dart';

void main() {
  testWidgets('SchoolDeskModuleScaffold exposes accessible page chrome', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: SchoolDeskModuleScaffold(
          title: 'Students',
          subtitle: 'Admissions and student records',
          drawer: const Drawer(child: Text('Navigation')),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {},
            ),
          ],
          body: const Text('Student list'),
        ),
      ),
    );

    expect(find.text('Students'), findsOneWidget);
    expect(find.text('Admissions and student records'), findsOneWidget);
    expect(find.text('Student list'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(SchoolDeskModuleScaffold)),
      matchesSemantics(label: 'Students module'),
    );
  });

  testWidgets('compact role shell exposes easy-find global actions', (
    tester,
  ) async {
    BackendApiClient.instance.clearAuthToken();
    BackendApiClient.instance.setCurrentRole('parent');
    addTearDown(BackendApiClient.instance.clearAuthToken);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: SchoolDeskModuleScaffold(
          title: 'Homework',
          drawer: const Drawer(child: Text('Navigation')),
          body: const Text('Homework list'),
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text(SchoolDeskGlossary.search), findsOneWidget);
    expect(find.text(SchoolDeskGlossary.notifications), findsOneWidget);
    expect(find.text(SchoolDeskGlossary.profile), findsOneWidget);
  });

  testWidgets('compact role shell supports admin visual shortcuts', (
    tester,
  ) async {
    BackendApiClient.instance.clearAuthToken();
    BackendApiClient.instance.setCurrentRole('admin');
    addTearDown(BackendApiClient.instance.clearAuthToken);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: SchoolDeskModuleScaffold(
          title: 'Admin',
          drawer: const Drawer(child: Text('Full module navigation')),
          mobileBottomActions: const [
            SchoolDeskModuleBottomAction(
              label: 'Home',
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              route: AppRoutes.initial,
            ),
            SchoolDeskModuleBottomAction(
              label: 'Students',
              icon: Icons.school_outlined,
              activeIcon: Icons.school_rounded,
              route: AppRoutes.adminStudents,
            ),
            SchoolDeskModuleBottomAction(
              label: 'Staff',
              icon: Icons.groups_outlined,
              activeIcon: Icons.groups_rounded,
              route: AppRoutes.adminTeachers,
            ),
            SchoolDeskModuleBottomAction(
              label: 'Chat',
              icon: Icons.chat_bubble_outline_rounded,
              activeIcon: Icons.chat_bubble_rounded,
              route: AppRoutes.adminCommunication,
            ),
            SchoolDeskModuleBottomAction(
              label: 'More',
              icon: Icons.menu_rounded,
              activeIcon: Icons.menu_rounded,
              route: SchoolDeskModuleScaffold.openNavigationAction,
            ),
          ],
          body: const Text('Admin content'),
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Students'), findsOneWidget);
    expect(find.text('Staff'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
    expect(find.text(SchoolDeskGlossary.search), findsNothing);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    expect(find.text('Full module navigation'), findsOneWidget);
  });

  testWidgets('desktop role shell exposes persistent search chrome', (
    tester,
  ) async {
    BackendApiClient.instance.clearAuthToken();
    BackendApiClient.instance.setCurrentRole('admin');
    addTearDown(BackendApiClient.instance.clearAuthToken);
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: SchoolDeskModuleScaffold(
          title: 'Dashboard',
          drawer: const Drawer(child: Text('Navigation')),
          body: const Text('Dashboard content'),
        ),
      ),
    );

    expect(find.text(SchoolDeskGlossary.search), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
  });

  testWidgets('SchoolDeskRecordCard keeps row content and actions semantic', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SchoolDeskRecordCard(
            title: 'Asha Kumar',
            subtitle: 'Class 5 A',
            leadingIcon: Icons.school_rounded,
            semanticLabel: 'Student Asha Kumar, Class 5 A',
            chips: const [
              SchoolDeskRecordChip(
                label: 'Active',
                tone: RecordChipTone.success,
              ),
              SchoolDeskRecordChip(label: 'Roll 12'),
            ],
            trailing: IconButton(
              tooltip: 'More actions',
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () {},
            ),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Asha Kumar'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(SchoolDeskRecordCard)),
      matchesSemantics(
        label: 'Student Asha Kumar, Class 5 A',
        isButton: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.byType(SchoolDeskRecordCard));
    expect(tapped, isTrue);
  });
}
