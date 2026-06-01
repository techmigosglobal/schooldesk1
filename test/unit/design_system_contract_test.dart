import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/services/feature_availability_service.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('operational SaaS themes expose shared design tokens', (
    tester,
  ) async {
    SchoolDeskTheme? lightTokens;
    SchoolDeskTheme? darkTokens;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: Builder(
          builder: (context) {
            lightTokens = Theme.of(context).extension<SchoolDeskTheme>();
            darkTokens = AppTheme.darkTheme.extension<SchoolDeskTheme>();
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(lightTokens, isNotNull);
    expect(darkTokens, isNotNull);
    final light = lightTokens!;
    final dark = darkTokens!;
    expect(light.spacing.scale, [4, 8, 12, 16, 20, 24, 32]);
    expect(light.spacing.md, 16);
    expect(light.spacing.relaxed, 20);
    expect(light.spacing.xxl, 32);
    expect(light.typography.scale, [32, 26, 20, 18, 15, 13]);
    expect(light.sizing.toolbarHeight, 64);
    expect(light.sizing.appBarHeight, 64);
    expect(light.sizing.buttonHeight, 48);
    expect(light.sizing.formFieldHeight, 48);
    expect(light.sizing.searchBarHeight, 48);
    expect(light.sizing.fabSize, 56);
    expect(light.sizing.iconContainer, 44);
    expect(light.sizing.bottomNavigationHeight, 72);
    expect(light.sizing.bottomSheetMaxWidth, 720);
    expect(light.radius.card, 8);
    expect(light.motion.fast, const Duration(milliseconds: 140));
    expect(light.roleColor(SchoolDeskRole.admin), isA<Color>());
    expect(light.roleColor(SchoolDeskRole.teacher), isA<Color>());
    expect(dark.isDark, isTrue);
  });

  test('responsive helpers enforce app-wide layout breakpoints', () {
    expect(SchoolDeskResponsive.effectiveTextScale(1.0), 1.0);
    expect(SchoolDeskResponsive.effectiveTextScale(1.3), 1.3);
    expect(SchoolDeskResponsive.effectiveTextScale(1.8), 1.3);
    expect(SchoolDeskResponsive.gridColumnsForWidth(240), 1);
    expect(SchoolDeskResponsive.gridColumnsForWidth(360), 2);
    expect(SchoolDeskResponsive.gridColumnsForWidth(700), 3);
    expect(SchoolDeskResponsive.gridColumnsForWidth(900), 4);
    expect(
      SchoolDeskResponsive.gridColumnsForWidth(1400),
      greaterThanOrEqualTo(4),
    );

    const spacing = SchoolDeskSpacing.standard;
    expect(
      SchoolDeskResponsive.contentHorizontalPaddingForWidth(390, spacing),
      16,
    );
    expect(
      SchoolDeskResponsive.contentHorizontalPaddingForWidth(720, spacing),
      20,
    );
  });

  testWidgets('responsive grid adapts from phone to tablet columns', (
    tester,
  ) async {
    Future<void> pumpGrid(double width) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 900),
              textScaler: const TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: width,
                  child: SchoolDeskResponsiveGrid(
                    children: [
                      for (var index = 0; index < 8; index++)
                        ColoredBox(
                          key: ValueKey('grid-$index'),
                          color: Colors.blue,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpGrid(360);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('grid-0'))).dy,
      tester.getTopLeft(find.byKey(const ValueKey('grid-1'))).dy,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('grid-2'))).dy,
      greaterThan(tester.getTopLeft(find.byKey(const ValueKey('grid-1'))).dy),
    );

    await pumpGrid(700);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('grid-0'))).dy,
      tester.getTopLeft(find.byKey(const ValueKey('grid-2'))).dy,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('grid-3'))).dy,
      greaterThan(tester.getTopLeft(find.byKey(const ValueKey('grid-2'))).dy),
    );

    await pumpGrid(920);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('grid-0'))).dy,
      tester.getTopLeft(find.byKey(const ValueKey('grid-3'))).dy,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('grid-4'))).dy,
      greaterThan(tester.getTopLeft(find.byKey(const ValueKey('grid-3'))).dy),
    );

    await tester.binding.setSurfaceSize(null);
  });

  test('Material theme maps to the SchoolDesk typography and sizing scale', () {
    final theme = AppTheme.lightTheme;
    final textTheme = theme.textTheme;

    expect(textTheme.displayLarge?.fontSize, 32);
    expect(textTheme.displayMedium?.fontSize, 26);
    expect(textTheme.headlineLarge?.fontSize, 20);
    expect(textTheme.headlineMedium?.fontSize, 18);
    expect(textTheme.bodyLarge?.fontSize, 15);
    expect(textTheme.bodySmall?.fontSize, 13);
    expect(theme.appBarTheme.toolbarHeight, 64);
    expect(
      theme.elevatedButtonTheme.style?.minimumSize?.resolve(<WidgetState>{}),
      const Size(64, 48),
    );
    expect(
      theme.iconButtonTheme.style?.minimumSize?.resolve(<WidgetState>{}),
      const Size.square(44),
    );
    expect(theme.inputDecorationTheme.constraints?.minHeight, 48);
    expect(
      theme.floatingActionButtonTheme.sizeConstraints,
      BoxConstraints.tight(const Size(56, 56)),
    );
  });

  testWidgets('global UI components share canonical dimensions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          appBar: const SchoolDeskAppBar(title: 'Dashboard', subtitle: 'ERP'),
          bottomNavigationBar: SchoolDeskBottomNavigationBar(
            items: [
              SchoolDeskBottomNavItem(
                label: 'Home',
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                selected: true,
                onTap: () {},
              ),
              SchoolDeskBottomNavItem(
                label: 'Search',
                icon: Icons.search_rounded,
                activeIcon: Icons.manage_search_rounded,
                selected: false,
                onTap: () {},
              ),
            ],
          ),
          body: const SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  SchoolDeskCard(child: Text('Card')),
                  SizedBox(height: 16),
                  SchoolDeskStatBox(
                    label: 'Students',
                    value: '128',
                    icon: Icons.school_outlined,
                  ),
                  SizedBox(height: 16),
                  SchoolDeskTextField(label: 'Name'),
                  SizedBox(height: 16),
                  SchoolDeskSearchBar(label: 'Search students'),
                  SizedBox(height: 16),
                  SchoolDeskButton(label: 'Save', onPressed: null),
                  SizedBox(height: 16),
                  SchoolDeskListTile(
                    title: 'Class 8 A',
                    subtitle: '32 students',
                    leadingIcon: Icons.groups_outlined,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byType(SchoolDeskIconContainer).first).width,
      40,
    );
    expect(
      tester.getSize(find.byType(SchoolDeskButton)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byType(SchoolDeskSearchBar)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byType(SchoolDeskBottomNavigationBar)).height,
      greaterThanOrEqualTo(72),
    );

    await tester.binding.setSurfaceSize(null);
  });

  test('feature availability keeps incomplete backend actions honest', () {
    final unavailable = FeatureAvailabilityService.stateFor(
      SchoolDeskFeature.reportsExports,
    );
    final available = FeatureAvailabilityService.stateFor(
      SchoolDeskFeature.adminStudents,
    );

    expect(unavailable.isAvailable, isTrue);
    expect(unavailable.reason, contains('backend'));
    expect(unavailable.recommendedAction, contains('coverage'));
    expect(available.isAvailable, isTrue);
    expect(available.reason, isNull);
  });

  test('legacy Material widgets inherit ERP component styling', () {
    final light = AppTheme.lightTheme;
    final dark = AppTheme.darkTheme;

    expect(light.listTileTheme.shape, isA<RoundedRectangleBorder>());
    expect(light.popupMenuTheme.shape, isA<RoundedRectangleBorder>());
    expect(light.dataTableTheme.headingRowColor, isNotNull);
    expect(light.dataTableTheme.dataRowColor, isNotNull);
    expect(light.drawerTheme.shape, isA<RoundedRectangleBorder>());
    expect(
      light.navigationBarTheme.indicatorShape,
      isA<RoundedRectangleBorder>(),
    );
    expect(light.iconButtonTheme.style, isNotNull);
    expect(light.progressIndicatorTheme.color, AppTheme.primary);

    expect(dark.listTileTheme.shape, isA<RoundedRectangleBorder>());
    expect(dark.dataTableTheme.headingRowColor, isNotNull);
    expect(dark.drawerTheme.shape, isA<RoundedRectangleBorder>());
    expect(dark.progressIndicatorTheme.color, AppTheme.primaryLight);
  });

  test('app respects system text scaling instead of forcing 1.0', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, isNot(contains('TextScaler.linear(1.0)')));
    expect(
      source,
      contains('maxScaleFactor: SchoolDeskResponsive.maxSupportedTextScale'),
    );
    expect(source, isNot(contains('setPreferredOrientations')));
    expect(source, isNot(contains('DeviceOrientation.portraitUp')));
  });

  test('ui illustration assets are registered and available', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final secureLogin = File('assets/images/ui/secure-login.svg');
    final emptyState = File('assets/images/ui/empty-state.svg');

    expect(pubspec, contains('assets/images/ui/'));
    expect(secureLogin.existsSync(), isTrue);
    expect(emptyState.existsSync(), isTrue);
  });

  test('student portal stays as a future blueprint, not an active route', () {
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final prd = File('docs/PRD.md').readAsStringSync();

    expect(prd, contains('No student portal route in the current release'));
    expect(routes, isNot(contains('studentDashboard')));
    expect(routes, isNot(contains('/student-dashboard-screen')));
  });
}
