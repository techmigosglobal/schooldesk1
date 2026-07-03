class LocalTestCredentials {
  const LocalTestCredentials({
    required this.role,
    required this.username,
    required this.password,
    required this.dashboardMarkers,
  });

  final String role;
  final String username;
  final String password;
  final List<String> dashboardMarkers;

  bool get isConfigured => username.trim().isNotEmpty && password.isNotEmpty;
}

const localRoleCredentials = <LocalTestCredentials>[
  LocalTestCredentials(
    role: 'Principal',
    username: String.fromEnvironment('QA_PRINCIPAL_USERNAME'),
    password: String.fromEnvironment('QA_PRINCIPAL_PASSWORD'),
    dashboardMarkers: ['Oversight Overview', 'Pending Approvals'],
  ),
  LocalTestCredentials(
    role: 'Admin',
    username: String.fromEnvironment('QA_ADMIN_USERNAME'),
    password: String.fromEnvironment('QA_ADMIN_PASSWORD'),
    dashboardMarkers: ['Oversight Overview', 'Total Students', 'Total Staff'],
  ),
  LocalTestCredentials(
    role: 'Teacher',
    username: String.fromEnvironment('QA_TEACHER_USERNAME'),
    password: String.fromEnvironment('QA_TEACHER_PASSWORD'),
    dashboardMarkers: ["Today's Overview", 'Class Students'],
  ),
  LocalTestCredentials(
    role: 'Parent',
    username: String.fromEnvironment('QA_PARENT_USERNAME'),
    password: String.fromEnvironment('QA_PARENT_PASSWORD'),
    dashboardMarkers: ['Fee Dues', 'Notices'],
  ),
];
