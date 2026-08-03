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
      contains('getMyStudents(\n        refreshNonce: refreshNonce,'),
    );
    expect(
      parentDashboard,
      contains("api.getDashboard('parent', forceRefresh: forceRefresh)"),
    );
    expect(
      parentDashboard,
      contains("api.getMyStudents(\n          refreshNonce: forceRefresh"),
    );
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
      final principalDashboard = File(
        'lib/features/dashboard/presentation/screens/principal_dashboard_screen/principal_dashboard_screen.dart',
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
        contains('api.getPrincipalClassesOverview(forceRefresh: true)'),
      );
      expect(
        principalDashboard,
        contains('api.getDashboard(_leadershipRole, forceRefresh: true)'),
      );
    },
  );
}
