import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/modules/principal/domain/entities/principal_dashboard.dart';
import 'package:schooldesk1/modules/principal/domain/entities/principal_profile.dart';

/// Abstract repository interface for principal dashboard operations.
abstract class PrincipalRepository {
  Future<Result<PrincipalDashboard>> getDashboardData();
  Future<Result<Map<String, dynamic>>> getSchoolInfo();
  Future<Result<PrincipalProfile>> getProfile();
}
