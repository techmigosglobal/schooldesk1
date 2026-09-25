import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/services/backend_data_service.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/modules/documents/domain/id_card_repository.dart';

class ApiIdCardRepository implements IdCardRepository {
  ApiIdCardRepository(this._service);

  final BackendDataService _service;

  @override
  Future<Result<IdCardData>> load({bool forceRefresh = false}) =>
      guardApi(() async {
        final values = await Future.wait<Object>([
          _service.getList(BackendDataService.kAdminStudents),
          _service.getCurrentAcademicYearLabel(),
          _service.getCurrentSchool(),
        ]);
        return IdCardData(
          students: List<Map<String, dynamic>>.from(
            values[0] as List<Map<String, dynamic>>,
          ),
          academicYear: values[1] as String,
          school: Map<String, dynamic>.from(values[2] as Map<String, dynamic>),
        );
      });

  static ApiIdCardRepository get legacyDefault =>
      ApiIdCardRepository(BackendDataService.instance);
}
