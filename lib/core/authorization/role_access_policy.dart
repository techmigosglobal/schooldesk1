import 'package:schooldesk1/core/auth/role_context.dart';

enum SchoolDeskCapability {
  viewDashboard,
  managePeople,
  recordAttendance,
  manageHomework,
  communicate,
  viewDocuments,
  viewReports,
  manageFinance,
  approveRequests,
  manageBranches,
  manageAccounts,
  manageSupport,
  scanKioskAttendance,
}

/// UX-level capability policy. The API remains the authority for every
/// operation; this policy only prevents invalid navigation and makes the
/// client behavior predictable before a request is made.
class RoleAccessPolicy {
  const RoleAccessPolicy._();

  static final Map<SchoolDeskRole, Set<SchoolDeskCapability>> _capabilities = {
    SchoolDeskRole.principal: {
      SchoolDeskCapability.viewDashboard,
      SchoolDeskCapability.managePeople,
      SchoolDeskCapability.recordAttendance,
      SchoolDeskCapability.manageHomework,
      SchoolDeskCapability.communicate,
      SchoolDeskCapability.viewDocuments,
      SchoolDeskCapability.viewReports,
      SchoolDeskCapability.manageFinance,
      SchoolDeskCapability.approveRequests,
    },
    SchoolDeskRole.coordinator: {
      SchoolDeskCapability.viewDashboard,
      SchoolDeskCapability.managePeople,
      SchoolDeskCapability.recordAttendance,
      SchoolDeskCapability.manageHomework,
      SchoolDeskCapability.communicate,
      SchoolDeskCapability.viewDocuments,
      SchoolDeskCapability.viewReports,
      SchoolDeskCapability.approveRequests,
      SchoolDeskCapability.manageAccounts,
    },
    SchoolDeskRole.teacher: {
      SchoolDeskCapability.viewDashboard,
      SchoolDeskCapability.recordAttendance,
      SchoolDeskCapability.manageHomework,
      SchoolDeskCapability.communicate,
      SchoolDeskCapability.viewDocuments,
    },
    SchoolDeskRole.parent: {
      SchoolDeskCapability.viewDashboard,
      SchoolDeskCapability.communicate,
      SchoolDeskCapability.viewDocuments,
    },
    SchoolDeskRole.kiosk: {
      SchoolDeskCapability.scanKioskAttendance,
    },
    SchoolDeskRole.superAdmin: {
      SchoolDeskCapability.viewDashboard,
      SchoolDeskCapability.viewReports,
      SchoolDeskCapability.communicate,
      SchoolDeskCapability.manageBranches,
      SchoolDeskCapability.manageAccounts,
      SchoolDeskCapability.manageSupport,
    },
  };

  static bool allows(RoleContext context, SchoolDeskCapability capability) {
    return _capabilities[context.role]?.contains(capability) ?? false;
  }

  static Set<SchoolDeskCapability> forRole(SchoolDeskRole role) {
    return Set.unmodifiable(_capabilities[role] ?? const {});
  }

  static bool isOnlineOnly(SchoolDeskCapability capability) {
    return capability == SchoolDeskCapability.manageFinance ||
        capability == SchoolDeskCapability.approveRequests ||
        capability == SchoolDeskCapability.manageBranches;
  }
}
