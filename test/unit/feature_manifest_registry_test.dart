import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/authorization/role_access_policy.dart';
import 'package:schooldesk1/core/authorization/feature_manifest.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/routes/feature_manifest_registry.dart';
import 'package:schooldesk1/routes/route_access_guard.dart';

void main() {
  test('every active route has one feature manifest', () {
    final manifests = FeatureManifestRegistry.all;
    final routes = manifests.map((manifest) => manifest.route).toSet();

    expect(routes, containsAll(AppRoutes.routes.keys));
    expect(manifests, hasLength(AppRoutes.routes.length));
    expect(
      manifests.every((manifest) => manifest.id.trim().isNotEmpty),
      isTrue,
    );
  });

  test('online-only mutations stay explicit while reads remain cacheable', () {
    final paymentForm = FeatureManifestRegistry.manifestForRoute(
      '/parent/payment-selection-screen',
    );
    final paymentHistory = FeatureManifestRegistry.manifestForRoute(
      '/parent/payment-history-screen',
    );
    final kiosk = FeatureManifestRegistry.manifestForRoute(
      AppRoutes.kioskQrAttendance,
    );

    expect(paymentForm.capability, SchoolDeskCapability.manageFinance);
    expect(paymentForm.onlineOnlyMutation, isTrue);
    expect(paymentForm.offlineReadable, isTrue);
    expect(paymentHistory.onlineOnlyMutation, isFalse);
    expect(kiosk.capability, SchoolDeskCapability.scanKioskAttendance);
  });

  test(
    'every registered screen declares the complete repository state contract',
    () {
      const required = RepositoryStateRequirement.values;
      for (final manifest in FeatureManifestRegistry.all) {
        expect(
          manifest.stateRequirements,
          containsAll(required),
          reason: manifest.route,
        );
        expect(manifest.offlineReadable, isTrue, reason: manifest.route);
      }
    },
  );

  test('role workflow surfaces are reachable without finance overgranting', () {
    const requiredByRole = <String, List<String>>{
      'principal': [
        AppRoutes.principalDashboard,
        AppRoutes.principalSchoolProfile,
        AppRoutes.staffManagement,
        AppRoutes.academicManagement,
        AppRoutes.principalAttendance,
        AppRoutes.feeHome,
        AppRoutes.approvalCenter,
        AppRoutes.reportsAnalytics,
        AppRoutes.communicationCenter,
        AppRoutes.principalDocuments,
        AppRoutes.principalAuditLogs,
      ],
      'coordinator': [
        AppRoutes.coordinatorDashboard,
        AppRoutes.academicManagement,
        AppRoutes.principalAttendance,
        AppRoutes.principalTimetable,
        AppRoutes.communicationCenter,
        AppRoutes.reportsAnalytics,
        AppRoutes.principalDocuments,
      ],
      'teacher': [
        AppRoutes.teacherDashboard,
        AppRoutes.teacherClasses,
        AppRoutes.teacherAttendance,
        AppRoutes.teacherHomework,
        AppRoutes.teacherLessonPlanner,
        AppRoutes.teacherLeave,
        AppRoutes.teacherEventPosts,
        AppRoutes.teacherDocuments,
        AppRoutes.teacherCommunication,
      ],
      'parent': [
        AppRoutes.parentDashboard,
        AppRoutes.parentAttendance,
        AppRoutes.parentFees,
        AppRoutes.parentPaymentRequestForm,
        AppRoutes.parentPaymentHistory,
        AppRoutes.parentReceipt,
        AppRoutes.parentLeave,
        AppRoutes.parentHealth,
        AppRoutes.parentCalendar,
        AppRoutes.parentDocuments,
        AppRoutes.parentTeacherChat,
      ],
      'kiosk': [AppRoutes.kioskQrAttendance],
      'super_admin': [
        AppRoutes.superAdminDashboard,
        AppRoutes.superAdminAccess,
        AppRoutes.superAdminIssues,
        AppRoutes.principalSchoolProfile,
      ],
    };

    for (final entry in requiredByRole.entries) {
      for (final route in entry.value) {
        expect(
          RouteAccessGuard.isRoleAllowedFor(routeName: route, role: entry.key),
          isTrue,
          reason: '${entry.key} must reach $route',
        );
      }
    }

    for (final route in [
      AppRoutes.feeHome,
      AppRoutes.feeStructures,
      AppRoutes.feeCollect,
      AppRoutes.feeLedger,
      AppRoutes.principalPaymentRequests,
      AppRoutes.principalPaymentRequestDecision,
      AppRoutes.principalFeeStructureForm,
      AppRoutes.principalPaymentRecordForm,
      AppRoutes.feePaymentConfig,
      AppRoutes.parentPaymentRequestForm,
    ]) {
      expect(
        RouteAccessGuard.isRoleAllowedFor(
          routeName: route,
          role: 'coordinator',
        ),
        isFalse,
        reason: 'Coordinator must not enter finance route $route',
      );
    }

    for (final role in ['principal', 'coordinator', 'teacher', 'parent']) {
      expect(
        RouteAccessGuard.isRoleAllowedFor(
          routeName: AppRoutes.kioskQrAttendance,
          role: role,
        ),
        isFalse,
      );
    }
  });
}
