import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import 'backend_api_client.dart';
import 'push_notification_service.dart';
import 'role_access_service.dart';

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
    await BackendApiClient.instance.logout();
    RoleAccessService.clear();
    if (!navigator.mounted) return;
    navigator.pushNamedAndRemoveUntil(AppRoutes.landingPage, (route) => false);
  }
}
