import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:schooldesk1/app/providers/app_providers.dart';
import 'package:schooldesk1/features/dashboard/presentation/screens/principal_dashboard_screen/principal_dashboard_screen.dart';

/// Principal role composition boundary. Feature screens move behind this shell
/// as their repositories are migrated out of the legacy feature tree.
class PrincipalShell extends ConsumerWidget {
  const PrincipalShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PrincipalDashboardScreen(
      dashboardRepository: ref.watch(leadershipDashboardRepositoryProvider),
    );
  }
}
