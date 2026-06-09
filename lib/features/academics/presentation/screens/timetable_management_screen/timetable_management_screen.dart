import 'package:flutter/material.dart';

import 'package:schooldesk1/features/academics/presentation/screens/principal_command_center_screens/principal_academic_command_screens.dart';

@Deprecated('Use PrincipalTimetableScreen. Principal timetable is read-only.')
class TimetableManagementScreen extends StatelessWidget {
  const TimetableManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => const PrincipalTimetableScreen();
}
