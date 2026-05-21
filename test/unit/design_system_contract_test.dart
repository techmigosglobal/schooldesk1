import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/services/feature_availability_service.dart';
import 'package:schooldesk1/theme/app_theme.dart';
import 'package:schooldesk1/theme/design_tokens.dart';

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
    expect(light.spacing.md, 16);
    expect(light.radius.card, 8);
    expect(light.motion.fast, const Duration(milliseconds: 140));
    expect(light.roleColor(SchoolDeskRole.admin), isA<Color>());
    expect(light.roleColor(SchoolDeskRole.teacher), isA<Color>());
    expect(dark.isDark, isTrue);
  });

  test('feature availability keeps incomplete backend actions honest', () {
    final unavailable = FeatureAvailabilityService.stateFor(
      SchoolDeskFeature.teacherResources,
    );
    final available = FeatureAvailabilityService.stateFor(
      SchoolDeskFeature.adminStudents,
    );

    expect(unavailable.isAvailable, isFalse);
    expect(unavailable.reason, contains('Backend'));
    expect(unavailable.recommendedAction, contains('Track'));
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
    expect(source, contains('clamp(maxScaleFactor: 1.35'));
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
    final blueprint = File('docs/student-portal-ui-blueprint.md');

    expect(blueprint.existsSync(), isTrue);
    expect(routes, isNot(contains('studentDashboard')));
    expect(routes, isNot(contains('/student-dashboard-screen')));
  });
}
