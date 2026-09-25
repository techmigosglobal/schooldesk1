import 'package:schooldesk1/core/network/models/backend_models.dart';

abstract interface class UserAccessRepository {
  Future<PaginatedList<UserAccountModel>> loadUsers({
    String? role,
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
  });

  Future<List<Map<String, dynamic>>> loadActivities();

  Future<Map<String, dynamic>> loadPermissions();

  Future<UserAccountModel> createUser({
    required String username,
    required String password,
    required String role,
    String fullName = '',
    String email = '',
    String phone = '',
    bool isActive = true,
    bool requestPrincipalApproval = false,
  });

  Future<UserAccountModel> updateUser(
    String id, {
    String? username,
    String? password,
    String? role,
    String? fullName,
    String? email,
    String? phone,
    bool? isActive,
  });

  Future<Map<String, dynamic>> resetCredentials(String id);

  Future<void> deleteUser(String id, {bool permanent = false});

  Future<void> deleteLinkedStaff(String staffId);

  Future<void> assignParentStudents({
    required String parentUserId,
    required List<String> admissionNumbers,
    List<String> studentIds = const [],
  });
}
