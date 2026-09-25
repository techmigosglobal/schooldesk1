import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_dashboard_repository.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_dashboard_snapshot.dart';

class ApiTeacherDashboardRepository implements TeacherDashboardRepository {
  ApiTeacherDashboardRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Result<TeacherDashboardSnapshot>> load({bool forceRefresh = false}) {
    return guardApi(() async {
      final announcements = await _api.getAnnouncements(
        forceRefresh: forceRefresh,
      );

      var schoolName = 'School';
      try {
        final school = await _api.getCurrentSchool(forceRefresh: forceRefresh);
        final value = '${school['organization_name'] ?? school['name'] ?? ''}'
            .trim();
        if (value.isNotEmpty) schoolName = value;
      } on Object {
        // School identity is supplementary. Cached dashboard data remains
        // useful when this separate identity read is unavailable.
      }

      StaffAttendanceModel? attendance;
      try {
        attendance = await _api.getMyStaffAttendanceToday();
      } on Object {
        // Attendance is supplementary. Dashboard remains useful without it.
      }

      PaginatedList<Map<String, dynamic>>? feed;
      Object? feedError;
      try {
        feed = await _api.getTeacherSchoolFeedPage(page: 1, pageSize: 20);
      } on Object catch (error) {
        feedError = error;
      }

      return TeacherDashboardSnapshot(
        announcements: announcements,
        myAttendance: attendance,
        feed: feed,
        feedError: feedError,
        schoolName: schoolName,
      );
    });
  }

  /// Kept for legacy route entry points until all routes receive Riverpod
  /// overrides. Production composition uses [teacherDashboardRepositoryProvider].
  static ApiTeacherDashboardRepository get legacyDefault =>
      ApiTeacherDashboardRepository(BackendApiClient.instance);
}
