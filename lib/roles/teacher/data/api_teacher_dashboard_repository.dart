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
      // None of these reads depends on another read's result. Keep the
      // announcements request authoritative while allowing supplementary
      // dashboard sections to fail independently as before.
      final results = await Future.wait<Object?>([
        _api.getAnnouncements(forceRefresh: forceRefresh),
        _loadSchoolName(forceRefresh: forceRefresh),
        _loadAttendance(),
        _loadFeed(),
      ]);
      final announcements = results[0] as List<AnnouncementModel>;
      final schoolName = results[1] as String;
      final attendance = results[2] as StaffAttendanceModel?;
      final feedRead = results[3] as _TeacherFeedRead;

      return TeacherDashboardSnapshot(
        announcements: announcements,
        myAttendance: attendance,
        feed: feedRead.feed,
        feedError: feedRead.error,
        schoolName: schoolName,
      );
    });
  }

  Future<String> _loadSchoolName({required bool forceRefresh}) async {
    try {
      final school = await _api.getCurrentSchool(forceRefresh: forceRefresh);
      final value = '${school['organization_name'] ?? school['name'] ?? ''}'
          .trim();
      return value.isEmpty ? 'School' : value;
    } on Object {
      // School identity is supplementary. Cached dashboard data remains
      // useful when this separate identity read is unavailable.
      return 'School';
    }
  }

  Future<StaffAttendanceModel?> _loadAttendance() async {
    try {
      return await _api.getMyStaffAttendanceToday();
    } on Object {
      // Attendance is supplementary. Dashboard remains useful without it.
      return null;
    }
  }

  Future<_TeacherFeedRead> _loadFeed() async {
    try {
      return _TeacherFeedRead(
        feed: await _api.getTeacherSchoolFeedPage(page: 1, pageSize: 10),
      );
    } on Object catch (error) {
      return _TeacherFeedRead(error: error);
    }
  }

  /// Kept for legacy route entry points until all routes receive Riverpod
  /// overrides. Production composition uses [teacherDashboardRepositoryProvider].
  static ApiTeacherDashboardRepository get legacyDefault =>
      ApiTeacherDashboardRepository(BackendApiClient.instance);
}

class _TeacherFeedRead {
  const _TeacherFeedRead({this.feed, this.error});

  final PaginatedList<Map<String, dynamic>>? feed;
  final Object? error;
}
