import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/services/backend_data_service.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/modules/dashboard/domain/admin_dashboard_repository.dart';

class ApiAdminDashboardRepository implements AdminDashboardRepository {
  ApiAdminDashboardRepository(this._service);

  final BackendDataService _service;

  @override
  Future<Result<AdminDashboardData>> load({bool forceRefresh = false}) =>
      guardApi(() async {
        final values = await Future.wait<Object>([
          _service.getList(BackendDataService.kAdminStudents),
          _service.getList(BackendDataService.kAdminTeachers),
          _service.getList(BackendDataService.kAcademicClasses),
          _service.getList(BackendDataService.kRuntimeNotifications),
          _service.getList(BackendDataService.kStudentFees),
        ]);
        return AdminDashboardData(
          students: List<Map<String, dynamic>>.from(
            values[0] as List<Map<String, dynamic>>,
          ),
          staff: List<Map<String, dynamic>>.from(
            values[1] as List<Map<String, dynamic>>,
          ),
          classes: List<Map<String, dynamic>>.from(
            values[2] as List<Map<String, dynamic>>,
          ),
          alerts: List<Map<String, dynamic>>.from(
            values[3] as List<Map<String, dynamic>>,
          ),
          invoices: List<Map<String, dynamic>>.from(
            values[4] as List<Map<String, dynamic>>,
          ),
        );
      });

  static ApiAdminDashboardRepository get legacyDefault =>
      ApiAdminDashboardRepository(BackendDataService.instance);
}
