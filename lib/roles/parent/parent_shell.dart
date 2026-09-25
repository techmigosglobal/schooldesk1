import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:schooldesk1/app/providers/app_providers.dart';
import 'package:schooldesk1/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart';

class ParentShell extends ConsumerWidget {
  const ParentShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ParentDashboardScreen(
      dashboardRepository: ref.watch(parentDashboardRepositoryProvider),
    );
  }
}
