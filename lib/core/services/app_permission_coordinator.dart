import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:schooldesk1/core/services/push_notification_service.dart';

/// Keeps the app's optional device capabilities usable after users change
/// permissions in Settings. It is deliberately app-wide so every role gets
/// the same recovery prompt rather than each feature inventing its own flow.
class AppPermissionCoordinator {
  AppPermissionCoordinator._();

  static Future<void> promptForMissing(BuildContext context) async {
    if (kIsWeb || !context.mounted) return;
    final permissions = _requiredPermissions;
    final statuses = await Future.wait(
      permissions.map(
        (permission) async => (permission, await permission.status),
      ),
    );
    final missing = statuses
        .where((entry) => !_isUsable(entry.$2))
        .map((entry) => entry.$1)
        .toList(growable: false);
    if (missing.isEmpty || !context.mounted) return;

    final shouldOpenSettings = statuses.any(
      (entry) => entry.$2.isPermanentlyDenied || entry.$2.isRestricted,
    );
    final action = await showDialog<_PermissionPromptAction>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enable device permissions'),
        content: const Text(
          'Camera, media, and notifications keep attendance scanning, uploads, and school alerts working. You can change these at any time in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _PermissionPromptAction.later),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              shouldOpenSettings
                  ? _PermissionPromptAction.settings
                  : _PermissionPromptAction.request,
            ),
            child: Text(shouldOpenSettings ? 'Open Settings' : 'Allow'),
          ),
        ],
      ),
    );
    if (action == _PermissionPromptAction.settings) {
      await openAppSettings();
      return;
    }
    if (action != _PermissionPromptAction.request) return;

    await Future.wait(missing.map((permission) => permission.request()));
    await PushNotificationService.instance.registerDeviceTokenIfPossible();
  }

  static List<Permission> get _requiredPermissions => [
    Permission.notification,
    Permission.camera,
    Permission.photos,
    if (defaultTargetPlatform == TargetPlatform.android) Permission.videos,
  ];

  static bool _isUsable(PermissionStatus status) =>
      status.isGranted || status.isLimited || status.isProvisional;
}

enum _PermissionPromptAction { later, request, settings }

class AppPermissionLifecycleGate extends StatefulWidget {
  final Widget child;

  const AppPermissionLifecycleGate({super.key, required this.child});

  @override
  State<AppPermissionLifecycleGate> createState() =>
      _AppPermissionLifecycleGateState();
}

class _AppPermissionLifecycleGateState extends State<AppPermissionLifecycleGate>
    with WidgetsBindingObserver {
  bool _promptVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPermissions());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    if (_promptVisible || !mounted) return;
    _promptVisible = true;
    try {
      await AppPermissionCoordinator.promptForMissing(context);
    } finally {
      _promptVisible = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
