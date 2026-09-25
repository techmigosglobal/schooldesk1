import 'package:schooldesk1/core/network/models/backend_models.dart';

/// API-shaped data needed by Teacher dashboard.
///
/// Repository owns transport and partial-read rules. Screen owns presentation.
class TeacherDashboardSnapshot {
  const TeacherDashboardSnapshot({
    required this.announcements,
    required this.myAttendance,
    required this.feed,
    this.feedError,
    this.schoolName = 'School',
  });

  final List<AnnouncementModel> announcements;
  final StaffAttendanceModel? myAttendance;
  final PaginatedList<Map<String, dynamic>>? feed;
  final Object? feedError;
  final String schoolName;

  bool get feedIsStale => feed?.isStale ?? false;
}
