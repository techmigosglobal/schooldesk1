// ignore_for_file: one_member_abstracts

import 'package:schooldesk1/core/network/models/backend_models.dart';

abstract interface class AdmissionInquiryRepository {
  Future<PaginatedList<Map<String, dynamic>>> loadPage({
    String? search,
    int page = 1,
    int pageSize = 20,
  });
}
