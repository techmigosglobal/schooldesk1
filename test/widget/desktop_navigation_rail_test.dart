import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:schooldesk1/core/desktop/desktop_navigation_rail.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/widgets/erp_navigation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'desktop rail navigates items even when selection callback is passive',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var selectedIndex = -1;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          routes: {
            '/students': (_) => const Scaffold(body: Text('Students page')),
          },
          home: Scaffold(
            body: _rail(
              onSelected: (index) => selectedIndex = index,
              sections: const [
                SchoolDeskNavigationSection(
                  label: 'School',
                  items: [
                    SchoolDeskNavigationItem(
                      index: 4,
                      icon: Icons.people_outline,
                      activeIcon: Icons.people,
                      label: 'Students',
                      route: '/students',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('Students'));
      await tester.pumpAndSettle();

      expect(selectedIndex, 4);
      expect(find.text('Students page'), findsOneWidget);
    },
  );

  testWidgets('desktop rail footer actions navigate to their declared route', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        routes: {'/search': (_) => const Scaffold(body: Text('Search page'))},
        home: Scaffold(
          body: _rail(
            sections: const [],
            footerActions: const [
              SchoolDeskNavigationFooterAction(
                icon: Icons.search_rounded,
                label: 'Global Search',
                route: '/search',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Global Search'));
    await tester.pumpAndSettle();

    expect(find.text('Search page'), findsOneWidget);
  });

  testWidgets('disabled desktop rail items cannot change the active module', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var selectedIndex = -1;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: _rail(
            onSelected: (index) => selectedIndex = index,
            sections: const [
              SchoolDeskNavigationSection(
                label: 'School',
                items: [
                  SchoolDeskNavigationItem(
                    index: 9,
                    icon: Icons.lock_outline,
                    activeIcon: Icons.lock,
                    label: 'Unavailable module',
                    enabled: false,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Unavailable module'), warnIfMissed: false);
    await tester.pump();

    expect(selectedIndex, -1);
  });
}

Widget _rail({
  List<SchoolDeskNavigationSection> sections = const [],
  List<SchoolDeskNavigationFooterAction> footerActions = const [],
  ValueChanged<int>? onSelected,
}) {
  return DesktopNavigationRail(
    role: SchoolDeskRole.principal,
    portalLabel: 'Principal Portal',
    organizationName: 'SchoolDesk Academy',
    organizationSubtitle: 'Operations',
    userName: 'Principal User',
    userSubtitle: 'Principal',
    initials: 'PU',
    portalIcon: Icons.account_balance_rounded,
    selectedIndex: 0,
    onDestinationSelected: onSelected ?? (_) {},
    sections: sections,
    footerActions: footerActions,
  );
}
