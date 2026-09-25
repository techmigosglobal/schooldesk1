import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:schooldesk1/app/providers/app_providers.dart';
import 'package:schooldesk1/features/dashboard/presentation/screens/principal_dashboard_screen/principal_dashboard_screen.dart';

/// Coordinator role composition boundary.
///
/// Coordinators share the leadership dashboard presentation, but remain a
/// distinct role so route policy and finance exclusions stay explicit.
class CoordinatorShell extends ConsumerWidget {
  const CoordinatorShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PrincipalDashboardScreen(
      dashboardRepository: ref.watch(leadershipDashboardRepositoryProvider),
    );
  }
}
