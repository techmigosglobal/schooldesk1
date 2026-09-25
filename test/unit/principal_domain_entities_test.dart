import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/modules/principal/domain/entities/principal_dashboard.dart';
import 'package:schooldesk1/modules/principal/domain/entities/setup_step.dart';

void main() {
  PrincipalDashboard dashboard({int totalStudents = 10}) {
    return PrincipalDashboard(
      principalName: 'Principal',
      schoolName: 'School',
      schoolBoard: 'CBSE',
      schoolLogoUrl: '',
      schoolBannerUrl: '',
      totalStudents: totalStudents,
      totalStaff: 4,
      totalClasses: 2,
      pendingApprovals: 1,
      attendancePct: 95,
      attendancePresent: 95,
      attendanceMarked: 100,
      collectionPct: 80,
      totalPaid: 1000,
      unreadNotifications: 3,
      setupSteps: const [
        SetupStep(label: 'Classes', isComplete: true, route: '/classes'),
      ],
    );
  }

  test('principal dashboard equality includes metrics', () {
    expect(dashboard(), equals(dashboard()));
    expect(dashboard(), isNot(equals(dashboard(totalStudents: 11))));
  });

  test('setup step copyWith can explicitly clear nullable route', () {
    const step = SetupStep(
      label: 'Classes',
      isComplete: false,
      route: '/classes',
    );

    expect(step.copyWith().route, '/classes');
    expect(step.copyWith(route: null).route, isNull);
  });
}
