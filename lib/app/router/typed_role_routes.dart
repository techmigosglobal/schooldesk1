import 'package:flutter/widgets.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:go_router/go_router.dart';

import 'package:schooldesk1/core/auth/role_context.dart';
import 'package:schooldesk1/features/communication/presentation/screens/notification_center_screen/notification_center_screen.dart';
import 'package:schooldesk1/features/profile/presentation/screens/profile_management_screen/profile_management_screen.dart';
import 'package:schooldesk1/features/profile/presentation/screens/settings_screen/settings_screen.dart';
import 'package:schooldesk1/features/shell/presentation/screens/global_search_screen/global_search_screen.dart';
import 'package:schooldesk1/shared/screens/help_screen/help_screen.dart';
import 'package:schooldesk1/features/communication/presentation/screens/chat_workspace/chat_workspace_screen.dart';
import 'package:schooldesk1/features/communication/presentation/screens/principal_chat_communications_screen/principal_chat_communications_screen.dart';
import 'package:schooldesk1/roles/coordinator/coordinator_shell.dart';
import 'package:schooldesk1/roles/kiosk/kiosk_shell.dart';
import 'package:schooldesk1/roles/parent/parent_shell.dart';
import 'package:schooldesk1/roles/principal/principal_shell.dart';
import 'package:schooldesk1/roles/super_admin/super_admin_shell.dart';
import 'package:schooldesk1/roles/teacher/teacher_shell.dart';

/// Typed role entry routes. Feature routes are assembled by the explicit
/// typed screen inventory in [TypedAppRouteRegistry].
class PrincipalDashboardRoute extends GoRouteData {
  const PrincipalDashboardRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const PrincipalShell();
  }
}

class CoordinatorDashboardRoute extends GoRouteData {
  const CoordinatorDashboardRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const CoordinatorShell();
  }
}

class TeacherDashboardRoute extends GoRouteData {
  const TeacherDashboardRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const TeacherShell();
  }
}

class ParentDashboardRoute extends GoRouteData {
  const ParentDashboardRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const ParentShell();
  }
}

class KioskAttendanceRoute extends GoRouteData {
  const KioskAttendanceRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const KioskShell();
  }
}

class SuperAdminDashboardRoute extends GoRouteData {
  const SuperAdminDashboardRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const SuperAdminShell();
  }
}

/// Typed role context used by shared surfaces that need to preserve the
/// active portal in a deep link. The query parameter remains a compatibility
/// bridge for existing notification links; callers can use [location] when
/// they already have a typed role.
class SharedRoleRouteArgs {
  const SharedRoleRouteArgs({required this.role});

  final SchoolDeskRole role;

  static SharedRoleRouteArgs fromState(GoRouterState state) {
    final api = BackendApiClient.instance;
    final extra = state.extra;
    final legacyRole = extra is SharedRoleRouteArgs
        ? extra.roleName
        : extra is String
        ? extra
        : extra is Map
        ? '${extra['role'] ?? extra['role_name'] ?? ''}'
        : null;
    return SharedRoleRouteArgs(
      role:
          SchoolDeskRoleParsing.fromWireName(api.currentRoleName) ??
          SchoolDeskRoleParsing.fromWireName(legacyRole) ??
          SchoolDeskRoleParsing.fromWireName(
            state.uri.queryParameters['role'],
          ) ??
          SchoolDeskRole.principal,
    );
  }

  String get roleName => role.wireName;
}

class NotificationCenterRoute extends GoRouteData {
  const NotificationCenterRoute({
    this.args = const SharedRoleRouteArgs(role: SchoolDeskRole.principal),
  });

  final SharedRoleRouteArgs args;

  static NotificationCenterRoute fromState(GoRouterState state) {
    return NotificationCenterRoute(args: SharedRoleRouteArgs.fromState(state));
  }

  @override
  String get location => '/notification-center-screen?role=${args.roleName}';

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return NotificationCenterScreen(role: args.roleName);
  }
}

class SettingsRoute extends GoRouteData {
  const SettingsRoute({
    this.args = const SharedRoleRouteArgs(role: SchoolDeskRole.principal),
  });

  final SharedRoleRouteArgs args;

  static SettingsRoute fromState(GoRouterState state) {
    return SettingsRoute(args: SharedRoleRouteArgs.fromState(state));
  }

  @override
  String get location => '/settings-screen?role=${args.roleName}';

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return AppSettingsScreen(role: args.roleName);
  }
}

class ProfileRoute extends GoRouteData {
  const ProfileRoute({
    this.args = const SharedRoleRouteArgs(role: SchoolDeskRole.principal),
  });

  final SharedRoleRouteArgs args;

  static ProfileRoute fromState(GoRouterState state) {
    return ProfileRoute(args: SharedRoleRouteArgs.fromState(state));
  }

  @override
  String get location => '/profile-screen?role=${args.roleName}';

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return args.role == SchoolDeskRole.parent
        ? const AppSettingsScreen(role: 'parent')
        : ProfileManagementScreen(role: args.roleName);
  }
}

class GlobalSearchRoute extends GoRouteData {
  const GlobalSearchRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const GlobalSearchScreen();
  }
}

class HelpRoute extends GoRouteData {
  const HelpRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const HelpScreen();
  }
}

class HomeworkMessagingRoute extends GoRouteData {
  const HomeworkMessagingRoute({
    this.args = const SharedRoleRouteArgs(role: SchoolDeskRole.teacher),
  });

  final SharedRoleRouteArgs args;

  static HomeworkMessagingRoute fromState(GoRouterState state) {
    return HomeworkMessagingRoute(args: SharedRoleRouteArgs.fromState(state));
  }

  @override
  String get location => '/homework-messaging-screen?role=${args.roleName}';

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return args.role == SchoolDeskRole.superAdmin
        ? const PrincipalChatCommunicationsScreen()
        : ChatWorkspaceScreen(
            role: args.roleName,
            initialConversationId: _chatArgument(state, 'conversation_id'),
            initialStudentId: _chatArgument(state, 'student_id'),
          );
  }
}

String _chatArgument(GoRouterState state, String key) => state.extra is Map
    ? '${(state.extra as Map)[key] ?? state.uri.queryParameters[key] ?? ''}'
    : state.uri.queryParameters[key] ?? '';
