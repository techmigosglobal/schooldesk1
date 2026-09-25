import 'package:schooldesk1/core/authorization/feature_manifest.dart';
import 'package:schooldesk1/core/authorization/role_access_policy.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/routes/schooldesk_screen_registry.dart';

/// Route-level feature inventory used by navigation and offline UX.
///
/// Reads remain available from the account-scoped cache. Mutating surfaces
/// show an online-required state when transport is unavailable. The backend
/// remains authoritative for every capability decision.
class FeatureManifestRegistry {
  FeatureManifestRegistry._();

  static List<FeatureManifest> get all => [
    for (final route in AppRoutes.routes.keys) manifestForRoute(route),
  ];

  static FeatureManifest manifestForRoute(String route) {
    final normalized = route.trim().toLowerCase();
    final metadata = SchoolDeskScreenRegistry.byRoute(route);
    final capability = _capabilityFor(normalized, metadata?.portal);
    final id = normalized
        .replaceFirst(RegExp(r'^/+'), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    return FeatureManifest(
      id: id.isEmpty ? 'landing' : id,
      route: route,
      capability: capability,
      offlineReadable: true,
      onlineOnlyMutation: _hasOnlineOnlyMutation(normalized),
    );
  }

  static SchoolDeskCapability _capabilityFor(String route, String? portal) {
    if (portal == 'public') return SchoolDeskCapability.viewDashboard;
    if (route.contains('kiosk')) {
      return SchoolDeskCapability.scanKioskAttendance;
    }
    if (route.contains('super-admin-access')) {
      return SchoolDeskCapability.manageAccounts;
    }
    if (route.contains('super-admin-issues')) {
      return SchoolDeskCapability.manageSupport;
    }
    if (route.contains('super-admin') || route.contains('school-profile')) {
      return SchoolDeskCapability.manageBranches;
    }
    if (route.contains('fee') ||
        route.contains('payment') ||
        route.contains('finance')) {
      return SchoolDeskCapability.manageFinance;
    }
    if (route.contains('approval') || route.contains('decision')) {
      return SchoolDeskCapability.approveRequests;
    }
    if (route.contains('staff') ||
        route.contains('student') ||
        route.contains('guardian') ||
        route.contains('admission') ||
        route.contains('user-management') ||
        route.contains('access')) {
      return SchoolDeskCapability.managePeople;
    }
    if (route.contains('attendance')) {
      return SchoolDeskCapability.recordAttendance;
    }
    if (route.contains('homework') || route.contains('lesson-planner')) {
      return portal == 'parent'
          ? SchoolDeskCapability.communicate
          : SchoolDeskCapability.manageHomework;
    }
    if (route.contains('document') || route.contains('id-card')) {
      return SchoolDeskCapability.viewDocuments;
    }
    if (route.contains('report') || route.contains('analytic')) {
      return SchoolDeskCapability.viewReports;
    }
    if (route.contains('communication') ||
        route.contains('chat') ||
        route.contains('complaint') ||
        route.contains('issue') ||
        route.contains('event') ||
        route.contains('notification')) {
      return SchoolDeskCapability.communicate;
    }
    return SchoolDeskCapability.viewDashboard;
  }

  static bool _hasOnlineOnlyMutation(String route) {
    const mutationTokens = [
      'create',
      'edit',
      'form',
      'assign',
      'collect',
      'decision',
      'delete',
      'management',
      'password',
      'submit',
      'upload',
      'config',
    ];
    if (mutationTokens.any(route.contains)) return true;
    return route.contains('approval-center') ||
        route.contains('payment-selection') ||
        route.contains('payment-flow') ||
        route.contains('payment-request') ||
        route.contains('fee-collect') ||
        route.contains('help-screen') ||
        route.contains('school-gallery');
  }
}
