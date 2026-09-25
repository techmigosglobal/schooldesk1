import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:schooldesk1/app/providers/app_providers.dart';
import 'package:schooldesk1/features/dashboard/presentation/screens/teacher_dashboard_screen/teacher_dashboard_screen.dart';

class TeacherShell extends ConsumerWidget {
  const TeacherShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TeacherDashboardScreen(
      dashboardRepository: ref.watch(teacherDashboardRepositoryProvider),
    );
  }
}
