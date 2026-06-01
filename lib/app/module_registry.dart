enum SchoolDeskModuleLayer { data, domain, presentation }

class SchoolDeskModuleDefinition {
  const SchoolDeskModuleDefinition({
    required this.name,
    required this.path,
    required this.layers,
    required this.ownerRoutes,
  });

  final String name;
  final String path;
  final Set<SchoolDeskModuleLayer> layers;
  final Set<String> ownerRoutes;

  bool get isLayered =>
      layers.contains(SchoolDeskModuleLayer.data) &&
      layers.contains(SchoolDeskModuleLayer.domain) &&
      layers.contains(SchoolDeskModuleLayer.presentation);
}

class SchoolDeskModuleRegistry {
  const SchoolDeskModuleRegistry._();

  static const modules = <SchoolDeskModuleDefinition>[
    SchoolDeskModuleDefinition(
      name: 'Auth',
      path: 'lib/features/auth',
      layers: {
        SchoolDeskModuleLayer.data,
        SchoolDeskModuleLayer.domain,
        SchoolDeskModuleLayer.presentation,
      },
      ownerRoutes: {
        '/principal-login-screen',
        '/admin-login-screen',
        '/teacher-login-screen',
        '/parent-login-screen',
      },
    ),
    SchoolDeskModuleDefinition(
      name: 'Shell',
      path: 'lib/features/shell',
      layers: {
        SchoolDeskModuleLayer.data,
        SchoolDeskModuleLayer.domain,
        SchoolDeskModuleLayer.presentation,
      },
      ownerRoutes: {'/', '/landing-page-screen', '/onboarding-screen'},
    ),
    SchoolDeskModuleDefinition(
      name: 'Dashboard',
      path: 'lib/features/dashboard',
      layers: {
        SchoolDeskModuleLayer.data,
        SchoolDeskModuleLayer.domain,
        SchoolDeskModuleLayer.presentation,
      },
      ownerRoutes: {
        '/principal-dashboard-screen',
        '/admin-dashboard-screen',
        '/teacher-dashboard-screen',
        '/parent-dashboard-screen',
      },
    ),
    SchoolDeskModuleDefinition(
      name: 'People',
      path: 'lib/features/people',
      layers: {
        SchoolDeskModuleLayer.data,
        SchoolDeskModuleLayer.domain,
        SchoolDeskModuleLayer.presentation,
      },
      ownerRoutes: {
        '/staff-management-screen',
        '/student-oversight-screen',
        '/guardian-directory-screen',
        '/admin-user-access-screen',
      },
    ),
    SchoolDeskModuleDefinition(
      name: 'Academics',
      path: 'lib/features/academics',
      layers: {
        SchoolDeskModuleLayer.data,
        SchoolDeskModuleLayer.domain,
        SchoolDeskModuleLayer.presentation,
      },
      ownerRoutes: {
        '/academic-management-screen',
        '/principal-classes-screen',
        '/principal-subjects-screen',
        '/principal-timetable-screen',
        '/principal-exams-screen',
        '/principal-results-screen',
      },
    ),
    SchoolDeskModuleDefinition(
      name: 'Attendance',
      path: 'lib/features/attendance',
      layers: {
        SchoolDeskModuleLayer.data,
        SchoolDeskModuleLayer.domain,
        SchoolDeskModuleLayer.presentation,
      },
      ownerRoutes: {
        '/principal-attendance-screen',
        '/admin-attendance-screen',
        '/teacher-attendance-screen',
        '/teacher-my-attendance-screen',
        '/parent-attendance-screen',
      },
    ),
    SchoolDeskModuleDefinition(
      name: 'Calendar',
      path: 'lib/features/calendar',
      layers: {
        SchoolDeskModuleLayer.data,
        SchoolDeskModuleLayer.domain,
        SchoolDeskModuleLayer.presentation,
      },
      ownerRoutes: {'/events-calendar-screen', '/parent-calendar-screen'},
    ),
    SchoolDeskModuleDefinition(
      name: 'Documents',
      path: 'lib/features/documents',
      layers: {
        SchoolDeskModuleLayer.data,
        SchoolDeskModuleLayer.domain,
        SchoolDeskModuleLayer.presentation,
      },
      ownerRoutes: {
        '/admin-documents-screen',
        '/parent-documents-screen',
        '/id-card-generation-screen',
      },
    ),
    SchoolDeskModuleDefinition(
      name: 'Finance',
      path: 'lib/features/finance',
      layers: {
        SchoolDeskModuleLayer.data,
        SchoolDeskModuleLayer.domain,
        SchoolDeskModuleLayer.presentation,
      },
      ownerRoutes: {
        '/fee-monitoring-screen',
        '/admin-fees-screen',
        '/parent-fees-screen',
        '/fee-payment-receipt-screen',
      },
    ),
    SchoolDeskModuleDefinition(
      name: 'Communication',
      path: 'lib/features/communication',
      layers: {
        SchoolDeskModuleLayer.data,
        SchoolDeskModuleLayer.domain,
        SchoolDeskModuleLayer.presentation,
      },
      ownerRoutes: {
        '/communication-center-screen',
        '/complaint-management-screen',
        '/teacher-communication-screen',
        '/parent-teacher-chat-screen',
        '/notification-center-screen',
      },
    ),
    SchoolDeskModuleDefinition(
      name: 'Homework',
      path: 'lib/features/homework',
      layers: {
        SchoolDeskModuleLayer.data,
        SchoolDeskModuleLayer.domain,
        SchoolDeskModuleLayer.presentation,
      },
      ownerRoutes: {
        '/teacher-homework-screen',
        '/teacher-homework-screen/form',
        '/teacher-homework-screen/submissions',
        '/parent-homework-screen',
        '/parent-homework-screen/submit',
      },
    ),
    SchoolDeskModuleDefinition(
      name: 'Leave',
      path: 'lib/features/leave',
      layers: {
        SchoolDeskModuleLayer.data,
        SchoolDeskModuleLayer.domain,
        SchoolDeskModuleLayer.presentation,
      },
      ownerRoutes: {
        '/teacher-leave-screen',
        '/teacher-leave-screen/request',
        '/parent-leave-screen',
        '/parent-leave-screen/request',
      },
    ),
    SchoolDeskModuleDefinition(
      name: 'Operations',
      path: 'lib/features/operations',
      layers: {
        SchoolDeskModuleLayer.data,
        SchoolDeskModuleLayer.domain,
        SchoolDeskModuleLayer.presentation,
      },
      ownerRoutes: {'/admin-helpdesk-screen'},
    ),
    SchoolDeskModuleDefinition(
      name: 'Reports',
      path: 'lib/features/reports',
      layers: {
        SchoolDeskModuleLayer.data,
        SchoolDeskModuleLayer.domain,
        SchoolDeskModuleLayer.presentation,
      },
      ownerRoutes: {
        '/reports-analytics-screen',
        '/admin-reports-screen',
        '/teacher-reports-screen',
        '/report-card-generator-screen',
        '/principal-analytics-screen',
      },
    ),
    SchoolDeskModuleDefinition(
      name: 'Profile',
      path: 'lib/features/profile',
      layers: {
        SchoolDeskModuleLayer.data,
        SchoolDeskModuleLayer.domain,
        SchoolDeskModuleLayer.presentation,
      },
      ownerRoutes: {
        '/profile-screen',
        '/settings-screen',
        '/principal-school-profile-screen',
      },
    ),
  ];
}
