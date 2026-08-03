import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Subjects cards provide scoped class subject management', () {
    final source = File(
      'lib/features/academics/presentation/screens/principal_subjects_screen/principal_subjects_screen.dart',
    ).readAsStringSync();

    expect(source, contains('PopupMenuButton<String>'));
    expect(source, contains("value: 'manage_subjects'"));
    expect(source, contains("'action': 'subjects'"));
    expect(source, contains("'sectionId': classSubjects.sectionId"));
    expect(source, contains("'gradeId': classSubjects.gradeId"));
  });

  test(
    'Principal navigation uses one shared mobile shell and hides access menu',
    () {
      final classes = File(
        'lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart',
      ).readAsStringSync();
      final navigation = File(
        'lib/core/widgets/app_navigation.dart',
      ).readAsStringSync();
      final principalDrawer = navigation.substring(
        navigation.indexOf('class PrincipalDrawer'),
        navigation.indexOf('class PrincipalShellBottomBar'),
      );

      expect(classes, contains('const PrincipalShellBottomBar()'));
      expect(classes, isNot(contains('_ClassesDirectoryBottomBar')));
      expect(principalDrawer, isNot(contains('PrincipalNav.access')));
      expect(principalDrawer, isNot(contains('principalUserManagement')));
    },
  );

  test('Principal fee entry routes use the operational fee home', () {
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final feeHome = File(
      'lib/features/finance/presentation/screens/fee_home_screen/fee_home_screen.dart',
    ).readAsStringSync();

    expect(
      routes,
      contains('feeMonitoring: (context) => const FeeHomeScreen()'),
    );
    expect(
      routes,
      contains('principalFees: (context) => const FeeHomeScreen()'),
    );
    expect(feeHome, contains("title: 'Collect Fee'"));
    expect(feeHome, contains("title: 'Student Ledger & Dues'"));
  });

  test('Approval and notification workflows keep actions explicit', () {
    final approvals = File(
      'lib/features/people/presentation/screens/approval_center_screen/approval_center_screen.dart',
    ).readAsStringSync();
    final notifications = File(
      'lib/features/communication/presentation/screens/notification_center_screen/notification_center_screen.dart',
    ).readAsStringSync();

    expect(approvals, contains("'Student & Accounts'"));
    expect(approvals, contains("'Class & Academic'"));
    expect(approvals, contains("'Content'"));
    expect(approvals, isNot(contains("'Event Posts'")));
    expect(notifications, contains("label: const Text('Mark as read')"));
    expect(notifications, isNot(contains('_visibilityReadScheduled')));
  });
}
