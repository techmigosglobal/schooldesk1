import 'package:schooldesk1/core/utils/result.dart';

abstract interface class ComplaintRepository {
  Future<Result<List<Map<String, dynamic>>>> loadForRole(String role);

  Future<Result<Map<String, dynamic>>> save(
    Map<String, dynamic> complaint, {
    required String role,
  });

  Future<Result<void>> reportToSuperAdmin({
    required Map<String, dynamic> complaint,
    required String role,
  });
}
