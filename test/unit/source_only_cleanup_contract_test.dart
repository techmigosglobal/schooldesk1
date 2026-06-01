import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repository keeps only canonical markdown documentation', () {
    final markdownFiles =
        (Process.runSync('find', [
                  '.',
                  '-name',
                  '*.md',
                  '-not',
                  '-path',
                  './.git/*',
                ]).stdout
                as String)
            .trim()
            .split('\n')
            .where((path) => path.isNotEmpty)
            .map((path) => path.replaceFirst('./', ''))
            .toList()
          ..sort();

    expect(markdownFiles, ['README.md', 'docs/PRD.md', 'docs/SPEC.md']);
  });

  test('historical artifacts and inactive preview screens are removed', () {
    for (final path in [
      'qa-screenshots',
      'test-artifacts',
      'test-results',
      'school-backend/tmp',
      'school-backend/uploads',
      'school-backend/school.db',
      'school-backend/school-backend',
      'school-backend.zip',
      'docs/SchoolDesk_UI_UX_REF.zip',
      'lib/config',
      'lib/lib',
      'lib/models',
      'lib/presentation',
      'lib/services',
      'lib/theme',
      'lib/widgets',
      'web/school_brochure.html',
    ]) {
      expect(
        FileSystemEntity.typeSync(path),
        FileSystemEntityType.notFound,
        reason: '$path must not return to source control.',
      );
    }
  });

  test('source declares Riverpod and feature-first module ownership', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final registry = File('lib/app/module_registry.dart').readAsStringSync();
    final docs = File('docs/SPEC.md').readAsStringSync();

    expect(pubspec, contains('flutter_riverpod:'));
    expect(main, contains('ProviderScope('));
    for (final module in [
      'Auth',
      'Shell',
      'Dashboard',
      'People',
      'Academics',
      'Attendance',
      'Calendar',
      'Documents',
      'Finance',
      'Communication',
      'Homework',
      'Leave',
      'Operations',
      'Reports',
      'Profile',
    ]) {
      expect(registry, contains("name: '$module'"));
      expect(docs, contains(module));
    }
  });

  test('Flutter source is owned by app core features and routes only', () {
    final rootDirs = Directory('lib')
        .listSync()
        .whereType<Directory>()
        .map((dir) => dir.uri.pathSegments.reversed.skip(1).first)
        .toSet();

    expect(rootDirs, {'app', 'core', 'features', 'routes'});

    for (final feature in [
      'academics',
      'attendance',
      'auth',
      'calendar',
      'communication',
      'dashboard',
      'documents',
      'finance',
      'homework',
      'leave',
      'operations',
      'people',
      'profile',
      'reports',
      'shell',
    ]) {
      expect(
        File('lib/features/$feature/$feature.dart').existsSync(),
        isTrue,
        reason: '$feature must expose a barrel for route imports.',
      );
      expect(
        Directory('lib/features/$feature/presentation/screens').existsSync(),
        isTrue,
        reason: '$feature must own its screens under presentation/screens.',
      );
    }

    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    expect(routes, isNot(contains('/presentation/screens/')));
    expect(routes, isNot(contains('package:schooldesk1/presentation')));
    expect(routes, contains("features/academics/academics.dart"));
    expect(routes, contains("features/people/people.dart"));
    expect(routes, contains("features/finance/finance.dart"));
  });

  test('backend v1 route registration is split into domain route files', () {
    final main = File('school-backend/main.go').readAsStringSync();
    final routes = File(
      'school-backend/internal/routes/routes.go',
    ).readAsStringSync();

    expect(main, contains('routes.RegisterV1Routes(r, cfg)'));
    expect(routes, contains('registerAuthRoutes(api, cfg, authHandler)'));
    expect(
      routes,
      contains('registerDashboardRoutes(api, cfg, dashboardHandler)'),
    );
    expect(routes, contains('registerPrincipalRoutes('));

    for (final path in [
      'school-backend/internal/routes/auth_routes.go',
      'school-backend/internal/routes/dashboard_routes.go',
      'school-backend/internal/routes/principal_routes.go',
      'school-backend/internal/routes/operational.go',
    ]) {
      expect(File(path).existsSync(), isTrue, reason: '$path should exist');
    }
  });
}
