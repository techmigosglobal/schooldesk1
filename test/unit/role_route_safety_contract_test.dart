import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/routes/route_access_guard.dart';
import 'package:schooldesk1/routes/schooldesk_screen_registry.dart';

void main() {
  final appRoutesSource = File('lib/routes/app_routes.dart').readAsStringSync();
  final routeConstants = _routeConstants(appRoutesSource);

  // ─── Class-scoped route extraction ────────────────────────────────────────
  // app_navigation.dart contains both PrincipalDrawer and SuperAdminDrawer.
  // To prevent cross-contamination, we extract routes from each drawer class
  // separately by splitting the file at the SuperAdminDrawer boundary.
  final appNavigationSource = File(
    'lib/core/widgets/app_navigation.dart',
  ).readAsStringSync();
  final principalSection = _extractBeforeClass(
    appNavigationSource,
    'SuperAdminDrawer',
  );
  final superAdminSection = _extractAfterClass(
    appNavigationSource,
    'SuperAdminDrawer',
  );

  final teacherNavigationSource = File(
    'lib/core/widgets/teacher_navigation.dart',
  ).readAsStringSync();
  final parentNavigationSource = File(
    'lib/core/widgets/parent_navigation.dart',
  ).readAsStringSync();

  final roleSources = {
    'principal': [
      principalSection,
      File(
        'lib/features/dashboard/presentation/screens/principal_dashboard_screen/principal_dashboard_screen.dart',
      ).readAsStringSync(),
    ],
    'teacher': [
      teacherNavigationSource,
      File(
        'lib/features/dashboard/presentation/screens/teacher_dashboard_screen/teacher_dashboard_screen.dart',
      ).readAsStringSync(),
    ],
    'parent': [
      parentNavigationSource,
      File(
        'lib/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart',
      ).readAsStringSync(),
    ],
    'super_admin': [
      superAdminSection,
      File(
        'lib/features/dashboard/presentation/screens/super_admin_dashboard_screen/super_admin_dashboard_screen.dart',
      ).readAsStringSync(),
    ],
  };

  for (final entry in roleSources.entries) {
    test('${entry.key} visible routes are registered, allowed, and nonblank', () {
      final routeNames = <String>{};
      for (final source in entry.value) {
        routeNames.addAll(_referencedRouteNames(source));
      }

      for (final routeName in routeNames) {
        final route = routeConstants[routeName];
        expect(
          route,
          isNotNull,
          reason: '$routeName must be an AppRoutes const',
        );
        if (route == null) continue;

        expect(
          AppRoutes.routes,
          contains(route),
          reason: '$routeName ($route) must be registered in AppRoutes.routes',
        );

        expect(
          RouteAccessGuard.isRoleAllowedFor(routeName: route, role: entry.key),
          isTrue,
          reason:
              '$routeName ($route) must be explicitly allowed for ${entry.key}',
        );

        final redirect = RouteAccessGuard.redirectFor(
          routeName: route,
          isAuthenticated: true,
          currentRole: entry.key,
        );
        expect(
          redirect,
          isNull,
          reason: '$routeName ($route) must be role-allowed for ${entry.key}',
        );

        final metadata = SchoolDeskScreenRegistry.byRoute(route);
        expect(
          metadata,
          isNotNull,
          reason: '$routeName ($route) must have screen registry metadata',
        );
        final wrongRole = _wrongRoleFor(route);
        if (wrongRole == null) continue;
        expect(
          wrongRole,
          isNotNull,
          reason:
              '$routeName ($route) should have at least one wrong-role redirect target',
        );
        if (wrongRole == null) continue;

        expect(
          RouteAccessGuard.redirectFor(
            routeName: route,
            isAuthenticated: true,
            currentRole: wrongRole,
          ),
          RouteAccessGuard.dashboardForRole(wrongRole),
          reason:
              '$routeName ($route) must redirect $wrongRole to their dashboard',
        );
      }
    });
  }

  // ─── Cross-contamination guard ────────────────────────────────────────────
  test('principal section does not contain super_admin-specific routes', () {
    final superAdminOnlyRoutes = [
      'superAdminDashboard',
      'superAdminAuditLogs',
      'superAdminSystemMonitor',
      'superAdminAccess',
    ];
    for (final routeName in superAdminOnlyRoutes) {
      expect(
        principalSection,
        isNot(contains('AppRoutes.$routeName')),
        reason:
            'Principal section should not reference $routeName — it belongs to SuperAdminDrawer',
      );
    }
  });

  test('super_admin section does not contain principal-only routes', () {
    // These routes are in PrincipalDrawer and should NOT appear in SuperAdminDrawer.
    final principalOnlyRoutes = [
      'principalDashboard',
      'principalAcademicInfo',
      'principalAnalytics',
      'principalEventApprovals',
      'principalDocuments',
      'communicationCenter',
      'complaintManagement',
      'reportsAnalytics',
    ];
    for (final routeName in principalOnlyRoutes) {
      expect(
        superAdminSection,
        isNot(contains('AppRoutes.$routeName')),
        reason:
            'Super admin section should not reference $routeName — it belongs to PrincipalDrawer',
      );
    }
  });

  // ─── Teacher drawer content ───────────────────────────────────────────────
  test(
    'teacher drawer exposes active screens and hides retired duplicate routes',
    () {
      for (final routeName in [
        'teacherDashboard',
        'teacherClasses',
        'teacherTimetable',
        'teacherAttendance',
        'teacherAttendanceHistory',
        'teacherMyAttendance',
        'teacherEventPosts',
        'teacherLessonPlanner',
        'teacherStudentNotes',
        'teacherDocuments',
        'schoolGallery',
        'teacherCommunication',
        'teacherParentInteraction',
        'teacherLeave',
        'notificationCenter',
        'profileScreen',
        'settingsScreen',
      ]) {
        expect(
          teacherNavigationSource,
          contains('AppRoutes.$routeName'),
          reason: '$routeName should be reachable from TeacherDrawer',
        );
      }

      expect(
        teacherNavigationSource,
        isNot(contains('AppRoutes.teacherPerformance')),
      );
      expect(
        teacherNavigationSource,
        isNot(contains('AppRoutes.teacherReports')),
      );

      expect(
        teacherNavigationSource,
        isNot(contains('AppRoutes.teacherPTM')),
        reason: 'TeacherPTM is no longer part of Teacher navigation',
      );
      final routes = File('lib/routes/app_routes.dart').readAsStringSync();
      final guard = File(
        'lib/routes/route_access_guard.dart',
      ).readAsStringSync();
      final registry = File(
        'lib/routes/schooldesk_screen_registry.dart',
      ).readAsStringSync();
      final communicationBarrel = File(
        'lib/features/communication/communication.dart',
      ).readAsStringSync();
      expect(
        routes,
        isNot(contains('teacherPTM')),
        reason: 'TeacherParentInteraction is the canonical PTM route',
      );
      expect(
        guard,
        isNot(contains('teacherPTM')),
        reason: 'Duplicate TeacherPTM route should not stay guard-active',
      );
      expect(
        registry,
        isNot(contains('/teacher-ptm-screen')),
        reason: 'Duplicate PTM screen metadata should be retired',
      );
      expect(
        communicationBarrel,
        isNot(contains('teacher_ptm_screen.dart')),
        reason: 'Duplicate PTM screen should not be exported',
      );
      for (final removedRouteName in [
        'teacherStudyMaterials',
        'teacherStudyMaterialForm',
        'teacherHomeworkForm',
        'teacherHomeworkSubmissions',
        'teacherDiscipline',
      ]) {
        expect(
          teacherNavigationSource,
          isNot(contains('AppRoutes.$removedRouteName')),
          reason: '$removedRouteName is no longer part of Teacher navigation',
        );
      }
    },
  );

  // ─── Super admin drawer route safety ──────────────────────────────────────
  test(
    'super_admin drawer exposes system administration and school oversight routes',
    () {
      for (final routeName in [
        'superAdminAuditLogs',
        'superAdminSystemMonitor',
        'superAdminAccess',
        'idCardGeneration',
        'principalSchoolProfile',
        'principalUserManagement',
        'staffManagement',
        'studentOversight',
        'help',
        'superAdminDashboard',
        'notificationCenter',
        'profileScreen',
        'settingsScreen',
        'globalSearch',
      ]) {
        final route = routeConstants[routeName];
        if (route == null) continue;
        expect(
          RouteAccessGuard.isRoleAllowedFor(
            routeName: route,
            role: 'super_admin',
          ),
          isTrue,
          reason: '$routeName ($route) must be accessible for super_admin',
        );
      }
    },
  );

  test('super_admin-specific routes are NOT allowed for other roles', () {
    final superAdminOnlyRoutes = [
      'superAdminAuditLogs',
      'superAdminSystemMonitor',
      'superAdminAccess',
    ];
    for (final routeName in superAdminOnlyRoutes) {
      final route = routeConstants[routeName];
      if (route == null) continue;
      for (final otherRole in ['principal', 'teacher', 'parent']) {
        // Note: isRoleAllowedFor returns true for super_admin on all routes
        // due to the bypass, so we only check non-super_admin roles.
        expect(
          RouteAccessGuard.isRoleAllowedFor(routeName: route, role: otherRole),
          isFalse,
          reason: '$routeName ($route) must NOT be accessible for $otherRole',
        );
      }
    }
  });
}

// ─── Helpers ────────────────────────────────────────────────────────────────

/// Extracts everything from the start of [fileContent] up to the first
/// occurrence of `class [className]` (exclusive).
String _extractBeforeClass(String fileContent, String className) {
  final marker = 'class $className ';
  final idx = fileContent.indexOf(marker);
  // Fail loudly if marker not found — don't silently return entire file
  // which would reintroduce cross-contamination.
  assert(idx != -1, 'Class boundary marker "$marker" not found in file');
  if (idx == -1) return '';
  return fileContent.substring(0, idx);
}

/// Extracts everything from the first occurrence of `class [className]`
/// to the end of [fileContent] (inclusive).
String _extractAfterClass(String fileContent, String className) {
  final marker = 'class $className ';
  final idx = fileContent.indexOf(marker);
  assert(idx != -1, 'Class boundary marker "$marker" not found in file');
  if (idx == -1) return '';
  return fileContent.substring(idx);
}

Map<String, String> _routeConstants(String source) {
  final constants = <String, String>{};
  final regex = RegExp(
    r"static\s+const\s+String\s+(\w+)\s*=\s*'([^']+)';",
    multiLine: true,
  );
  for (final match in regex.allMatches(source)) {
    constants[match.group(1)!] = match.group(2)!;
  }
  return constants;
}

Set<String> _referencedRouteNames(String source) {
  return RegExp(r'AppRoutes\.(\w+)')
      .allMatches(source)
      .map((match) => match.group(1)!)
      .where((name) => name != 'routes')
      .toSet();
}

String? _wrongRoleFor(String route) {
  // Public routes are accessible to everyone — no wrong roles.
  if (RouteAccessGuard.publicRoutes.contains(route)) return null;
  final allowedRoles = RouteAccessGuard.allowedRolesFor(route);
  for (final role in RouteAccessGuard.authenticatedRoles) {
    // super_admin bypasses all route checks via redirectFor(), so it is
    // never a 'wrong role' for any route — skip it to avoid false failures.
    if (role == 'super_admin') continue;
    if (!allowedRoles.contains(role)) {
      return role;
    }
  }
  return null;
}
