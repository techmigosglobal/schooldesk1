import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/services/feature_availability_service.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );
  }

  Future<List<FlutterErrorDetails>> collectFlutterErrors(
    WidgetTester tester,
    Widget child,
  ) async {
    final errors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = errors.add;

    await tester.binding.setSurfaceSize(const Size(360, 800));
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(1.35),
            ),
            child: Scaffold(body: child),
          ),
        ),
      );
      await tester.pump();
    } finally {
      FlutterError.onError = previousOnError;
      await tester.binding.setSurfaceSize(null);
    }
    return errors;
  }

  testWidgets('SchoolDeskKpiCard renders accessible metric content', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      wrap(
        SchoolDeskKpiCard(
          title: 'Attendance',
          value: '96%',
          subtitle: 'Today',
          icon: Icons.how_to_reg_rounded,
          semanticLabel: 'Attendance is 96 percent today',
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Attendance'), findsOneWidget);
    expect(find.text('96%'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(SchoolDeskKpiCard)),
      matchesSemantics(
        label: 'Attendance is 96 percent today',
        isButton: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.byType(SchoolDeskKpiCard));
    expect(tapped, isTrue);
  });

  testWidgets('FeatureUnavailablePanel explains disabled backend actions', (
    tester,
  ) async {
    final state = FeatureAvailabilityService.stateFor(
      SchoolDeskFeature.parentStudentLeave,
    );

    await tester.pumpWidget(wrap(FeatureUnavailablePanel(state: state)));

    expect(find.text('Backend not ready'), findsOneWidget);
    expect(find.textContaining('Student leave'), findsOneWidget);
    expect(find.byIcon(Icons.lock_clock_rounded), findsOneWidget);
  });

  testWidgets('SchoolDeskSectionCard keeps actions and title semantic', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SchoolDeskSectionCard(
          title: 'Quick actions',
          subtitle: 'Common workflows',
          action: TextButton(onPressed: () {}, child: const Text('View all')),
          child: const Text('Create notice'),
        ),
      ),
    );

    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('Common workflows'), findsOneWidget);
    expect(find.text('View all'), findsOneWidget);
    expect(find.text('Create notice'), findsOneWidget);
  });

  testWidgets('SchoolDeskQuickActionTile renders stable icon action content', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      wrap(
        SchoolDeskQuickActionTile(
          label: 'Take attendance',
          subtitle: 'Mark today',
          icon: Icons.how_to_reg_rounded,
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Take attendance'), findsOneWidget);
    expect(find.text('Mark today'), findsOneWidget);
    expect(find.byIcon(Icons.how_to_reg_rounded), findsOneWidget);

    await tester.tap(find.byType(SchoolDeskQuickActionTile));
    expect(tapped, isTrue);
  });

  testWidgets('SchoolDeskIllustratedActionTile renders asset action content', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      wrap(
        SchoolDeskIllustratedActionTile(
          label: 'Attendance',
          subtitle: 'Daily records',
          illustrationAsset: SchoolDeskUiIllustrations.attendance,
          semanticLabel: 'Open attendance daily records',
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Attendance'), findsOneWidget);
    expect(find.text('Daily records'), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(SchoolDeskIllustratedActionTile)),
      matchesSemantics(
        label: 'Open attendance daily records',
        isButton: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.byType(SchoolDeskIllustratedActionTile));
    expect(tapped, isTrue);
  });

  testWidgets('SchoolDeskAttentionCard renders glance-first signals', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const SchoolDeskAttentionCard(
          title: 'Attention signals',
          subtitle: 'Items needing review',
          items: [
            SchoolDeskAttentionItem(
              label: 'Approvals',
              value: '4',
              icon: Icons.task_alt_rounded,
            ),
            SchoolDeskAttentionItem(
              label: 'Urgent notices',
              value: '2',
              icon: Icons.campaign_rounded,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Attention signals'), findsOneWidget);
    expect(find.text('Approvals'), findsOneWidget);
    expect(find.text('Urgent notices'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('SchoolDeskDataToolbar supports search and table actions', (
    tester,
  ) async {
    String query = '';
    var filterTapped = false;
    var exportTapped = false;

    await tester.pumpWidget(
      wrap(
        SchoolDeskDataToolbar(
          searchLabel: 'Search students',
          onSearchChanged: (value) => query = value,
          onFilter: () => filterTapped = true,
          onExport: () => exportTapped = true,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Anaya');
    await tester.tap(find.text('Filters'));
    await tester.tap(find.text('Export'));

    expect(query, 'Anaya');
    expect(filterTapped, isTrue);
    expect(exportTapped, isTrue);
  });

  testWidgets('SchoolDeskStatusPanel renders loading empty and error states', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const Column(
          children: [
            SchoolDeskStatusPanel.loading(message: 'Loading attendance'),
            SchoolDeskStatusPanel.empty(
              title: 'No records',
              message: 'Try another class',
            ),
            SchoolDeskStatusPanel.error(
              title: 'Server error',
              message: 'Retry after checking the API',
            ),
          ],
        ),
      ),
    );

    expect(find.text('Loading attendance'), findsOneWidget);
    expect(find.text('No records'), findsOneWidget);
    expect(find.text('Server error'), findsOneWidget);
  });

  testWidgets('SchoolDeskBreadcrumbs renders route hierarchy compactly', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const SchoolDeskBreadcrumbs(items: ['Admin', 'Students', 'Edit'])),
    );

    expect(find.text('Admin'), findsOneWidget);
    expect(find.text('Students'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));
  });

  testWidgets('SchoolDeskResponsiveGrid avoids KPI overflow on phone widths', (
    tester,
  ) async {
    final errors = await collectFlutterErrors(
      tester,
      Padding(
        padding: const EdgeInsets.all(12),
        child: SchoolDeskResponsiveGrid(
          minTileWidth: 160,
          mainAxisExtent: 96,
          children: const [
            SchoolDeskKpiCard(
              title: 'Students',
              value: '128',
              subtitle: 'School-wide',
              icon: Icons.school_rounded,
            ),
            SchoolDeskKpiCard(
              title: 'Pending approvals',
              value: '12',
              subtitle: 'Needs attention',
              icon: Icons.check_circle_outline_rounded,
            ),
          ],
        ),
      ),
    );

    expect(
      errors.where((e) => e.exceptionAsString().contains('overflowed')),
      isEmpty,
    );
  });

  testWidgets('quick action tiles avoid overflow on phone text scaling', (
    tester,
  ) async {
    final errors = await collectFlutterErrors(
      tester,
      Padding(
        padding: const EdgeInsets.all(12),
        child: SchoolDeskResponsiveGrid(
          minTileWidth: 150,
          mainAxisExtent: 126,
          children: const [
            SchoolDeskQuickActionTile(
              label: 'Communication Center',
              subtitle: 'Circulars and notices',
              icon: Icons.campaign_rounded,
            ),
            SchoolDeskQuickActionTile(
              label: 'Fee Monitoring',
              subtitle: 'Collection risk',
              icon: Icons.account_balance_wallet_rounded,
            ),
          ],
        ),
      ),
    );

    expect(
      errors.where((e) => e.exceptionAsString().contains('overflowed')),
      isEmpty,
    );
  });

  testWidgets('illustrated action tiles avoid overflow on phone text scaling', (
    tester,
  ) async {
    final errors = await collectFlutterErrors(
      tester,
      Padding(
        padding: const EdgeInsets.all(12),
        child: SchoolDeskResponsiveGrid(
          minTileWidth: 142,
          mainAxisExtent: 158,
          children: const [
            SchoolDeskIllustratedActionTile(
              label: 'Class communication',
              subtitle: 'Parents and notices',
              illustrationAsset: SchoolDeskUiIllustrations.chat,
            ),
            SchoolDeskIllustratedActionTile(
              label: 'Lesson planner',
              subtitle: 'Plan classes',
              illustrationAsset: SchoolDeskUiIllustrations.lessonPlanner,
            ),
          ],
        ),
      ),
    );

    expect(
      errors.where((e) => e.exceptionAsString().contains('overflowed')),
      isEmpty,
    );
  });
}
