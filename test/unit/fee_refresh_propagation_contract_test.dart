import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parent fee surfaces force-refresh linked student fee summaries', () {
    final studentsApi = File(
      'lib/core/network/api_modules/students_api.dart',
    ).readAsStringSync();
    final parentFees = File(
      'lib/features/finance/presentation/screens/parent_hub/parent_fee_hub.dart',
    ).readAsStringSync();
    final parentDashboard = File(
      'lib/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart',
    ).readAsStringSync();
    final parentDashboardRepository = File(
      'lib/roles/parent/data/api_parent_dashboard_repository.dart',
    ).readAsStringSync();

    expect(
      studentsApi,
      contains('Future<List<Map<String, dynamic>>> getMyStudents({'),
    );
    expect(
      studentsApi,
      contains("if (refreshNonce != null) 'refresh_nonce': refreshNonce"),
    );
    expect(
      parentFees,
      contains(
        '_repository.loadChildren(\n        refreshNonce: refreshNonce,',
      ),
    );
    expect(
      parentDashboardRepository,
      contains(
        "_api.getDashboard(\n        'parent',\n        forceRefresh: forceRefresh,",
      ),
    );
    // Parent dashboard children are returned by its role-scoped DTO. The
    // fee hub owns its own refreshable child request, so the dashboard must
    // not issue a second child-list call.
    expect(parentDashboard, isNot(contains('api.getMyStudents(')));
  });

  test(
    'principal summary surfaces bypass stale class and dashboard fee totals',
    () {
      final principalApi = File(
        'lib/core/network/api_modules/principal_api.dart',
      ).readAsStringSync();
      final principalClasses = File(
        'lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart',
      ).readAsStringSync();
      final principalClassesRepository = File(
        'lib/roles/principal/data/api_principal_classes_repository.dart',
      ).readAsStringSync();
      final principalDashboard = File(
        'lib/features/dashboard/presentation/screens/principal_dashboard_screen/principal_dashboard_screen.dart',
      ).readAsStringSync();
      final leadershipRepository = File(
        'lib/roles/principal/data/api_leadership_dashboard_repository.dart',
      ).readAsStringSync();

      expect(
        principalApi,
        contains('Future<Map<String, dynamic>> getPrincipalClassesOverview({'),
      );
      expect(
        principalApi,
        contains("? {'refresh_nonce': DateTime.now().millisecondsSinceEpoch}"),
      );
      expect(
        principalClasses,
        contains('_repository.loadOverview(forceRefresh: true)'),
      );
      expect(
        principalClassesRepository,
        contains(
          '_api.getPrincipalClassesOverview(forceRefresh: forceRefresh)',
        ),
      );
      expect(leadershipRepository, contains('_api.getDashboard(role'));
      expect(
        principalDashboard,
        contains('loadCritical(role: _leadershipRole)'),
      );
    },
  );
}
