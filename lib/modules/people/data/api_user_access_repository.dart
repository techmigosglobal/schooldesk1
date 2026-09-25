import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/modules/people/domain/user_access_repository.dart';

class ApiUserAccessRepository implements UserAccessRepository {
  ApiUserAccessRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<PaginatedList<UserAccountModel>> loadUsers({
    String? role,
    String? status,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) => _api.getUsers(
    role: role,
    status: status,
    search: search,
    page: page,
    pageSize: pageSize,
  );

  @override
  Future<List<Map<String, dynamic>>> loadActivities() => _api.getRawList(
    '/audit-logs',
    queryParameters: const {'page': 1, 'page_size': 20},
  );

  @override
  Future<Map<String, dynamic>> loadPermissions() => _api.getAccessPermissions();

  @override
  Future<UserAccountModel> createUser({
    required String username,
    required String password,
    required String role,
    String fullName = '',
    String email = '',
    String phone = '',
    bool isActive = true,
    bool requestPrincipalApproval = false,
  }) => _api.createUser(
    username: username,
    password: password,
    role: role,
    fullName: fullName,
    email: email,
    phone: phone,
    isActive: isActive,
    requestPrincipalApproval: requestPrincipalApproval,
  );

  @override
  Future<UserAccountModel> updateUser(
    String id, {
    String? username,
    String? password,
    String? role,
    String? fullName,
    String? email,
    String? phone,
    bool? isActive,
  }) => _api.updateUser(
    id,
    username: username,
    password: password,
    role: role,
    fullName: fullName,
    email: email,
    phone: phone,
    isActive: isActive,
  );

  @override
  Future<Map<String, dynamic>> resetCredentials(String id) =>
      _api.resetUserCredentials(id);

  @override
  Future<void> deleteUser(String id, {bool permanent = false}) =>
      _api.deleteUser(id, permanent: permanent);

  @override
  Future<void> deleteLinkedStaff(String staffId) => _api.deleteStaff(staffId);

  @override
  Future<void> assignParentStudents({
    required String parentUserId,
    required List<String> admissionNumbers,
    List<String> studentIds = const [],
  }) => _api.assignParentStudents(
    parentUserId: parentUserId,
    admissionNumbers: admissionNumbers,
    studentIds: studentIds,
  );

  static ApiUserAccessRepository get legacyDefault =>
      ApiUserAccessRepository(BackendApiClient.instance);
}
