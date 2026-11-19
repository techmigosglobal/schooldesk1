import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/principal/domain/leadership_dashboard_repository.dart';
import 'package:schooldesk1/roles/principal/domain/leadership_dashboard_snapshot.dart';

class ApiLeadershipDashboardRepository
    implements LeadershipDashboardRepository {
  ApiLeadershipDashboardRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<LeadershipDashboardCriticalSnapshot?> readCachedDashboard({
    required String role,
  }) async {
    final cached = await _api.readCachedDashboard(role);
    if (cached == null) return null;
    return LeadershipDashboardCriticalSnapshot(
      dashboard: cached.data,
      profile: _api.cachedProfile,
      cacheMetadata: cached.metadata,
    );
  }

  @override
  Future<Result<LeadershipDashboardCriticalSnapshot>> loadCritical({
    required String role,
  }) {
    return guardApi(() async {
      var cache = const CacheMetadata(isStale: false);
      final dashboard = await _api.getDashboard(
        role,
        refreshNetwork: true,
        onCacheMetadata: (metadata) => cache = metadata,
      );
      return LeadershipDashboardCriticalSnapshot(
        dashboard: dashboard,
        profile: _api.cachedProfile,
        cacheMetadata: cache,
      );
    });
  }

  @override
  Future<Result<LeadershipDashboardIdentity>> loadIdentity() {
    return guardApi(() async {
      final school = _api.getCurrentSchool();
      final profile = _api.cachedProfile;
      if (profile != null) return (school: await school, profile: profile);
      final details = await Future.wait<Object>([school, _api.getProfile()]);
      return (
        school: details[0] as Map<String, dynamic>,
        profile: details[1] as UserResponse,
      );
    });
  }

  @override
  Future<Result<Map<String, int>>> loadAttention() {
    return guardApi(() async {
      final page = await _api.getApprovalFeed(status: 'pending', pageSize: 1);
      return page.countsByType;
    });
  }

  @override
  Future<Result<Map<String, dynamic>>> loadStaffAttendance() {
    return guardApi(_api.getStaffDailyAttendanceSummary);
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> loadNotifications() {
    return guardApi(_api.getNotifications);
  }

  @override
  Future<Result<LeadershipDashboardOptionalSnapshot>> loadOptional({
    required String role,
  }) {
    return guardApi(() async {
      // Setup checks describe missing configuration only after all required
      // reads succeed. Opening Home does not need any of these full lists.
      final values = await Future.wait<Object>([
        _api.getAcademicYears(),
        _api.getGrades(),
        _api.getSections(),
        _api.getRawList('/subjects'),
        role == 'coordinator'
            ? Future.value(<Map<String, dynamic>>[])
            : _api.getFeeStructures(),
      ]);
      return LeadershipDashboardOptionalSnapshot(
        academicYears: values[0] as List<AcademicYearModel>,
        grades: values[1] as List<GradeModel>,
        sections: values[2] as List<SectionModel>,
        subjects: values[3] as List<Map<String, dynamic>>,
        feeStructures: values[4] as List<Map<String, dynamic>>,
      );
    });
  }

  static ApiLeadershipDashboardRepository get legacyDefault =>
      ApiLeadershipDashboardRepository(BackendApiClient.instance);
}
