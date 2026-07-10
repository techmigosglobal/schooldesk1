import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'package:schooldesk1/core/constants/app_constants.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/routes/schooldesk_screen_registry.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';

class SchoolDeskRouteFrame extends StatefulWidget {
  final SchoolDeskScreenMetadata metadata;
  final Widget child;

  const SchoolDeskRouteFrame({
    super.key,
    required this.metadata,
    required this.child,
  });

  @override
  State<SchoolDeskRouteFrame> createState() => _SchoolDeskRouteFrameState();
}

class _SchoolDeskRouteFrameState extends State<SchoolDeskRouteFrame> {
  DateTime? _lastBackPressedAt;

  bool get _isPortalHomeRoute {
    switch (widget.metadata.route) {
      case '/principal-dashboard-screen':
      case '/teacher-dashboard-screen':
      case '/parent-dashboard-screen':
      case '/kiosk-qr-attendance-screen':
        return true;
      default:
        return false;
    }
  }

  bool get _canExitOnBack {
    if (widget.metadata.isPublic) return true;
    if (_isPortalHomeRoute) return false;
    return Navigator.of(context).canPop();
  }

  void _handleBackWithoutPop() {
    if (widget.metadata.isPublic) return;
    if (!_isPortalHomeRoute) {
      _returnToPortalHome();
      return;
    }

    final now = DateTime.now();
    final last = _lastBackPressedAt;
    if (last != null && now.difference(last) <= const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPressedAt = now;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit ${AppConstants.appName}'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
  }

  void _returnToPortalHome() {
    final target = _homeRouteForCurrentContext();
    if (target == null || target == widget.metadata.route) return;
    Navigator.of(context).pushNamedAndRemoveUntil(target, (route) => false);
  }

  String? _homeRouteForCurrentContext() {
    switch (widget.metadata.portal) {
      case 'principal':
        return '/principal-dashboard-screen';
      case 'teacher':
        return '/teacher-dashboard-screen';
      case 'parent':
        return '/parent-dashboard-screen';
      case 'kiosk':
        return '/kiosk-qr-attendance-screen';
      case 'shared':
        return _homeRouteForRole(BackendApiClient.instance.currentRoleName);
      default:
        return null;
    }
  }

  String? _homeRouteForRole(String? role) {
    switch ((role ?? '').trim().toLowerCase()) {
      case 'principal':
      case 'admin':
        return '/principal-dashboard-screen';
      case 'super_admin':
        return '/super-admin-dashboard-screen';
      case 'teacher':
        return '/teacher-dashboard-screen';
      case 'parent':
        return '/parent-dashboard-screen';
      case 'kiosk':
        return '/kiosk-qr-attendance-screen';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).schoolDesk;
    return PopScope(
      canPop: _canExitOnBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBackWithoutPop();
      },
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Semantics(
          label: widget.metadata.semanticLabel,
          container: true,
          explicitChildNodes: true,
          child: DecoratedBox(
            decoration: BoxDecoration(color: tokens.pageBackground),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
