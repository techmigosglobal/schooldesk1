import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/modules/people/domain/admission_inquiry_repository.dart';

class ApiAdmissionInquiryRepository implements AdmissionInquiryRepository {
  ApiAdmissionInquiryRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<PaginatedList<Map<String, dynamic>>> loadPage({
    String? search,
    int page = 1,
    int pageSize = 20,
  }) {
    return _api.getAdmissionInquiriesPage(
      search: search,
      page: page,
      pageSize: pageSize,
    );
  }

  static ApiAdmissionInquiryRepository get legacyDefault =>
      ApiAdmissionInquiryRepository(BackendApiClient.instance);
}
