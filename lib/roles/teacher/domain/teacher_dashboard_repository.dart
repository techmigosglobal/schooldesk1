// A named interface keeps role composition testable and overrideable.
// ignore_for_file: one_member_abstracts

import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_dashboard_snapshot.dart';

abstract interface class TeacherDashboardRepository {
  Future<Result<TeacherDashboardSnapshot>> load({
    bool forceRefresh = false,
  });
}
