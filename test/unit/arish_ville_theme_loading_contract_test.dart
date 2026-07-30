import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Arish Ville uniform palette is the Flutter theme source of truth', () {
    expect(AppTheme.primary, const Color(0xFF0E5EA8));
    expect(AppTheme.secondary, const Color(0xFF0B2F5B));
    expect(AppTheme.accent, const Color(0xFFF4C430));
    expect(AppTheme.background, const Color(0xFFF8FBFE));
    expect(AppTheme.onSurface, const Color(0xFF102A43));

    final light = AppTheme.lightTheme.colorScheme;
    final dark = AppTheme.darkTheme.colorScheme;
    expect(light.primary, AppTheme.primary);
    expect(light.secondary, AppTheme.secondary);
    expect(dark.primary, AppTheme.primaryLight);
    expect(dark.surface, const Color(0xFF0B294B));
  });

  test('initial app and portal loading states use structured skeletons', () {
    final loginLoading = File(
      'lib/features/auth/presentation/screens/login_loading_screen/login_loading_screen.dart',
    ).readAsStringSync();
    final erpComponents = File(
      'lib/core/widgets/erp_components.dart',
    ).readAsStringSync();
    final principalDashboard = File(
      'lib/features/dashboard/presentation/screens/principal_dashboard_screen/principal_dashboard_screen.dart',
    ).readAsStringSync();
    final superAdminDashboard = File(
      'lib/features/dashboard/presentation/screens/super_admin_dashboard_screen/super_admin_dashboard_screen.dart',
    ).readAsStringSync();

    expect(loginLoading, contains('LoadingSkeletonWidget'));
    expect(erpComponents, contains('LoadingSkeletonWidget'));
    expect(
      principalDashboard,
      contains('SchoolDeskPageSkeleton(cardCount: 6)'),
    );
    expect(
      superAdminDashboard,
      contains('SchoolDeskPageSkeleton(cardCount: 4)'),
    );
  });
}
