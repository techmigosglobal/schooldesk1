import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production bootstrap does not restore a fictional local session', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, isNot(contains('DemoLocalApiService')));
    expect(source, isNot(contains('DemoSandboxService')));
    expect(source, isNot(contains('demoRoleSelector')));
  });

  test('primary transport has no local response interceptor', () {
    final source = File(
      'lib/core/network/api_modules/client_interceptors.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('_DemoLocalApiInterceptor')));
  });

  test(
    'production client and super-admin UI expose no demo account workflow',
    () {
      final client = File(
        'lib/core/network/backend_api_client.dart',
      ).readAsStringSync();
      final dashboard = File(
        'lib/features/dashboard/presentation/screens/super_admin_dashboard_screen/super_admin_dashboard_screen.dart',
      ).readAsStringSync();

      expect(client, isNot(contains('demo_api.dart')));
      expect(dashboard, isNot(contains('Mobile Demo')));
      expect(dashboard, isNot(contains('_manageDemo')));
    },
  );

  test('screen registry contains no fictional demo route', () {
    final source = File(
      'lib/routes/schooldesk_screen_registry.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('demo-role-selector-screen')));
    expect(source, isNot(contains('Choose Demo Role')));
  });

  test('role navigation renders the API school identity', () {
    for (final path in [
      'lib/core/widgets/parent_navigation.dart',
      'lib/core/widgets/teacher_navigation.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains("school['organization_name'] ?? school['name']"));
      expect(source, isNot(contains("_schoolName = 'Arish Ville Preschool'")));
    }
  });

  test('teacher dashboard renders repository school identity', () {
    final dashboard = File(
      'lib/features/dashboard/presentation/screens/teacher_dashboard_screen/teacher_dashboard_screen.dart',
    ).readAsStringSync();
    final snapshot = File(
      'lib/roles/teacher/domain/teacher_dashboard_snapshot.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/roles/teacher/data/api_teacher_dashboard_repository.dart',
    ).readAsStringSync();

    expect(
      dashboard,
      contains("_repositoryState.data?.schoolName ?? 'School'"),
    );
    expect(dashboard, isNot(contains("title: 'Arish Ville Preschool'")));
    expect(snapshot, contains('final String schoolName;'));
    expect(repository, contains('getCurrentSchool'));
  });

  test('shared help and gallery screens use repository state boundaries', () {
    final help = File(
      'lib/shared/screens/help_screen/help_screen.dart',
    ).readAsStringSync();
    final gallery = File(
      'lib/shared/screens/school_gallery_screen.dart',
    ).readAsStringSync();

    for (final source in [help, gallery]) {
      expect(source, isNot(contains('BackendApiClient.instance')));
      expect(source, contains('RepositoryState<'));
      expect(source, contains('SchoolDeskRepositoryStateView<'));
    }
  });

  test('principal analytics uses its capability repository', () {
    final screen = File(
      'lib/features/reports/presentation/screens/principal_analytics_screen/principal_analytics_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/roles/principal/data/api_principal_analytics_repository.dart',
    ).readAsStringSync();

    expect(screen, isNot(contains('BackendDataService')));
    expect(screen, contains('PrincipalAnalyticsRepository'));
    expect(repository, contains('getInvoicesPage'));
    expect(repository, contains('getNotifications'));
    expect(repository, contains('getStaff'));
  });
}
