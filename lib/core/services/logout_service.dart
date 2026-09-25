import 'package:flutter/material.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/notification_service.dart';
import 'package:schooldesk1/core/services/push_notification_service.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/services/token_storage_service.dart';

import 'package:schooldesk1/core/navigation/schooldesk_navigation.dart';

class LogoutService {
  LogoutService._();

  static bool _signingOut = false;

  static Future<void> confirmAndSignOut(
    BuildContext context, {
    required String portalName,
  }) async {
    if (_signingOut) return;
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

  /// Signs the user out and navigates to the landing page.
  ///
  /// Navigation happens immediately; backend logout runs fire-and-forget so
  /// the UI is never blocked by slow network calls.
  static Future<void> signOut(BuildContext context) async {
    if (_signingOut) return;
    _signingOut = true;

    final navigator = Navigator.of(context, rootNavigator: true);

    // 1. Save the refresh token before clearing so the backend can be
    //    notified of the logout in the background.
    final refreshToken = await TokenStorageService.getRefreshToken();

    // 2. Revoke the device token while the authenticated session is still
    // available. This prevents a shared device from receiving private pushes
    // after another user signs in.
    try {
      await PushNotificationService.instance.revokeCurrentToken();
    } on Object catch (_) {
      // Logout must remain available when the device is offline.
    }

    // 3. Clear client-side state immediately.
    RoleAccessService.clear();
    BackendApiClient.instance.clearAuthToken();
    // Reset the notification singleton so stale notifications from this user
    // session are not visible if another user signs in on the same device.
    NotificationService.resetInstance();
    await TokenStorageService.clear();

    // 4. Navigate to landing page right away — do not await any network call.
    if (navigator.mounted) {
      SchoolDeskNavigation.goFromNavigator(
        navigator,
        AppRoutes.landingPage,
        legacyPredicate: (route) => false,
      );
    }

    // 5. Background cleanup — best-effort, never blocks the UI.
    _backgroundCleanup(refreshToken: refreshToken);

    // Allow future sign-outs after a short delay.
    Future.delayed(const Duration(seconds: 2), () {
      _signingOut = false;
    });
  }

  static void _backgroundCleanup({String? refreshToken}) {
    // Fire-and-forget: notify the backend.
    Future(() async {
      // Notify the backend about the logout using the saved refresh token.
      // We cannot use BackendApiClient.instance.logout() here because
      // the auth token has already been cleared.
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          await BackendApiClient.instance.dio.post(
            '/auth/logout',
            data: {'refresh_token': refreshToken},
          );
        } on Object catch (_) {
          // Ignore — backend logout is best-effort.
        }
      }
    });
  }
}
