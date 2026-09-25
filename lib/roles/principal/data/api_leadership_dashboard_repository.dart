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
  Future<Result<LeadershipDashboardCriticalSnapshot>> loadCritical({
    required String role,
  }) {
    return guardApi(() async {
      final results = await Future.wait<Object>([
        _api.getDashboard(role, forceRefresh: true),
        _api.getCurrentSchool(),
        _api.getProfile(),
      ]);
      return LeadershipDashboardCriticalSnapshot(
        dashboard: Map<String, dynamic>.from(results[0] as Map),
        school: Map<String, dynamic>.from(results[1] as Map),
        profile: results[2] as UserResponse,
      );
    });
  }

  @override
  Future<Result<LeadershipDashboardOptionalSnapshot>> loadOptional({
    required String role,
    required Map<String, dynamic> dashboard,
  }) {
    return guardApi(() async {
      final values = await Future.wait<Object>([
        _try(() => _api.getAcademicYears(), <AcademicYearModel>[]),
        _try(() => _api.getGrades(), <GradeModel>[]),
        _try(() => _api.getSections(), <SectionModel>[]),
        _try(() => _api.getRawList('/subjects'), <Map<String, dynamic>>[]),
        _try(
          () => _api.getStaff(page: 1, pageSize: 1),
          const PaginatedList<StaffModel>(
            data: [],
            total: 0,
            page: 1,
            pageSize: 1,
          ),
        ),
        _try(
          () => _api.getStudents(page: 1, pageSize: 1),
          const PaginatedList<StudentModel>(
            data: [],
            total: 0,
            page: 1,
            pageSize: 1,
          ),
        ),
        role == 'coordinator'
            ? Future.value(<Map<String, dynamic>>[])
            : _try(() => _api.getFeeStructures(), <Map<String, dynamic>>[]),
        _try(() => _api.getNotifications(), <Map<String, dynamic>>[]),
        _try(() => _api.getStaffDailyAttendanceSummary(), <String, dynamic>{}),
        _try(
          () => _api.getRawList(
            '/audit-logs',
            queryParameters: const {'page': 1, 'page_size': 3},
          ),
          <Map<String, dynamic>>[],
        ),
      ]).timeout(const Duration(seconds: 45));

      return LeadershipDashboardOptionalSnapshot(
        academicYears: values[0] as List<AcademicYearModel>,
        grades: values[1] as List<GradeModel>,
        sections: values[2] as List<SectionModel>,
        subjects: values[3] as List<Map<String, dynamic>>,
        staff: values[4] as PaginatedList<StaffModel>,
        students: values[5] as PaginatedList<StudentModel>,
        feeStructures: values[6] as List<Map<String, dynamic>>,
        notifications: values[7] as List<Map<String, dynamic>>,
        staffAttendanceSummary: values[8] as Map<String, dynamic>,
        recentSchoolActivity: values[9] as List<Map<String, dynamic>>,
      );
    });
  }

  Future<T> _try<T>(Future<T> Function() read, T fallback) async {
    try {
      return await read();
    } on Object {
      return fallback;
    }
  }

  /// Legacy route fallback until all route entry points receive overrides.
  static ApiLeadershipDashboardRepository get legacyDefault =>
      ApiLeadershipDashboardRepository(BackendApiClient.instance);
}
