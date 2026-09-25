/// The authenticated scope used by repositories, navigation, and offline
/// persistence.  A role is never sufficient on its own: account, school, and
/// branch are part of the identity of every local read and mutation.
enum SchoolDeskRole {
  principal,
  coordinator,
  teacher,
  parent,
  kiosk,
  superAdmin,
}

extension SchoolDeskRoleParsing on SchoolDeskRole {
  String get wireName => switch (this) {
    SchoolDeskRole.principal => 'principal',
    SchoolDeskRole.coordinator => 'coordinator',
    SchoolDeskRole.teacher => 'teacher',
    SchoolDeskRole.parent => 'parent',
    SchoolDeskRole.kiosk => 'kiosk',
    SchoolDeskRole.superAdmin => 'super_admin',
  };

  static SchoolDeskRole? fromWireName(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'admin':
      case 'principal':
        return SchoolDeskRole.principal;
      case 'coordinator':
        return SchoolDeskRole.coordinator;
      case 'teacher':
      case 'co_teacher':
        return SchoolDeskRole.teacher;
      case 'parent':
      case 'guardian':
        return SchoolDeskRole.parent;
      case 'kiosk':
        return SchoolDeskRole.kiosk;
      case 'super_admin':
      case 'superadmin':
        return SchoolDeskRole.superAdmin;
      default:
        return null;
    }
  }
}

class RoleContext {
  const RoleContext({
    required this.accountId,
    required this.schoolId,
    required this.branchId,
    required this.role,
  });

  final String accountId;
  final String schoolId;
  final String? branchId;
  final SchoolDeskRole role;

  String get cacheScope => [
    accountId,
    schoolId,
    branchId ?? 'all-branches',
    role.wireName,
  ].join('|');

  RoleContext copyWith({String? branchId, SchoolDeskRole? role}) {
    return RoleContext(
      accountId: accountId,
      schoolId: schoolId,
      branchId: branchId ?? this.branchId,
      role: role ?? this.role,
    );
  }
}
