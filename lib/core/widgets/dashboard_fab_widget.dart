import 'package:flutter/material.dart';

import 'package:schooldesk1/core/theme/app_theme.dart';

/// Role identifiers for the dashboard FAB
enum DashboardRole { principal, admin, teacher, parent }

/// A small floating action button that navigates back to the role dashboard.
/// Place this as the [floatingActionButton] on any non-dashboard screen.
///
/// If the screen already has its own FAB, wrap both in a [Column]:
/// ```dart
/// floatingActionButton: Column(
///   mainAxisSize: MainAxisSize.min,
///   children: [
///     DashboardFabWidget(role: DashboardRole.teacher),
///     const SizedBox(height: 12),
///     FloatingActionButton.extended(...), // existing FAB
///   ],
/// ),
/// ```
class DashboardFabWidget extends StatelessWidget {
  final DashboardRole role;

  const DashboardFabWidget({super.key, required this.role});

  String get _dashboardRoute {
    switch (role) {
      case DashboardRole.principal:
        return '/principal-dashboard-screen';
      case DashboardRole.admin:
        return '/admin-dashboard-screen';
      case DashboardRole.teacher:
        return '/teacher-dashboard-screen';
      case DashboardRole.parent:
        return '/parent-dashboard-screen';
    }
  }

  Color get _roleColor {
    switch (role) {
      case DashboardRole.principal:
        return AppTheme.primary;
      case DashboardRole.admin:
        return const Color(0xFF0D3B6E);
      case DashboardRole.teacher:
        return const Color(0xFF1A5276);
      case DashboardRole.parent:
        return const Color(0xFF1A6B4A);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'dashboard_fab_${role.name}',
      onPressed: () {
        Navigator.pushNamedAndRemoveUntil(
          context,
          _dashboardRoute,
          (route) => route.settings.name == _dashboardRoute || route.isFirst,
        );
      },
      backgroundColor: _roleColor,
      foregroundColor: Colors.white,
      tooltip: 'Go to Dashboard',
      child: const Icon(Icons.dashboard_rounded, size: 20),
    );
  }
}
