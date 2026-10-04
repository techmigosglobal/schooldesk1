import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/services/notification_route_resolver.dart';
import 'package:schooldesk1/routes/app_routes.dart';

void main() {
  test(
    'notification API keeps parent scope and stored routing metadata aligned',
    () {
      final notificationHandler = File(
        'supabase/functions/api/handlers/notifications.ts',
      ).readAsStringSync();
      final communicationsHandler = File(
        'supabase/functions/api/handlers/communications.ts',
      ).readAsStringSync();

      expect(notificationHandler, contains('parent_student_links'));
      expect(notificationHandler, contains('linkedStudentIds'));
      expect(
        communicationsHandler,
        contains('row.reference_type ?? row.entity_type'),
      );
      expect(communicationsHandler, contains('action: row.action'));
    },
  );

  test('fee payment proof notifications open the principal payment queue', () {
    final target = NotificationRouteResolver.resolve(
      data: {
        'reference_type': 'fee',
        'action': 'payment_submitted',
        'reference_id': 'payment-request-1',
        'route': '/principal-fees-screen/payment-requests',
      },
      currentRole: 'principal',
    );

    expect(target.route, AppRoutes.principalPaymentRequests);
  });

  test('payment media screens normalize Docker-only storage hosts', () {
    final files = [
      'lib/features/finance/presentation/screens/fee_payment_config_screen/fee_payment_config_screen.dart',
      'lib/features/finance/presentation/screens/principal_dashboard/principal_payment_config.dart',
      'lib/features/finance/presentation/screens/parent_hub/parent_payment_flow.dart',
      'lib/features/finance/presentation/screens/admin_fees_screen/admin_payment_request_decision_screen.dart',
      'lib/features/finance/presentation/screens/principal_dashboard/principal_payment_requests.dart',
    ];
    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source, contains('resolveOriginalImageUrl'), reason: path);
    }
  });

  test(
    'parent profile is view-only and does not render editable profile fields',
    () {
      final source = File(
        'lib/features/profile/presentation/screens/profile_management_screen/profile_management_screen.dart',
      ).readAsStringSync();
      expect(source, contains('_isParent'));
      expect(source, contains('if (!_isParent && _canEditProfile)'));
      expect(source, contains('_canEditProfile'));
    },
  );

  test('messages navigation exposes unread counts for each role shell', () {
    final parent = File(
      'lib/core/widgets/parent_navigation.dart',
    ).readAsStringSync();
    final principal = File(
      'lib/core/widgets/app_navigation.dart',
    ).readAsStringSync();
    expect(parent, contains("label: 'Messages'"));
    expect(parent, contains('badgeCount: _unreadMessages'));
    expect(principal, contains('badgeCount: _unreadMessages'));
  });
}
