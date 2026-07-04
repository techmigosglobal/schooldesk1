import 'package:flutter/material.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/push_notification_service.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/services/notification_topic_manager.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';

class LogoutService {
  LogoutService._();

  static Future<void> confirmAndSignOut(
    BuildContext context, {
    required String portalName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign Out'),
        content: Text('Are you sure you want to sign out of the $portalName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await signOut(context);
    }
  }

  static Future<void> signOut(BuildContext context) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    try {
      await PushNotificationService.instance.revokeCurrentToken();
    } catch (_) {
      // Continue logout even if the token was already stale or offline.
    }
    
    // Clean up notification topics for all roles (safe to unsubscribe from topics not subscribed to)
    try {
      for (final role in SchoolDeskRole.values) {
        await NotificationTopicManager().cleanupTopicsForRole(role);
      }
    } catch (_) {
      // Continue logout even if topic cleanup fails
    }
    
    await BackendApiClient.instance.logout();
    RoleAccessService.clear();
    if (!navigator.mounted) return;
    navigator.pushNamedAndRemoveUntil(AppRoutes.landingPage, (route) => false);
  }
}
