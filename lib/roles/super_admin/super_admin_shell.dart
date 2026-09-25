import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:schooldesk1/app/providers/app_providers.dart';
import 'package:schooldesk1/features/dashboard/presentation/screens/super_admin_dashboard_screen/super_admin_dashboard_screen.dart';

class SuperAdminShell extends ConsumerWidget {
  const SuperAdminShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SuperAdminDashboardScreen(
      dashboardRepository: ref.watch(superAdminDashboardRepositoryProvider),
    );
  }
}
