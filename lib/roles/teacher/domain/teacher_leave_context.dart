import 'package:schooldesk1/core/network/models/backend_models.dart';

class TeacherLeaveContext {
  final String staffId;
  final List<Map<String, dynamic>> leaveTypes;
  final List<Map<String, dynamic>> balances;
  final List<LeaveApplicationModel> applications;

  const TeacherLeaveContext({
    required this.staffId,
    required this.leaveTypes,
    required this.balances,
    required this.applications,
  });
}
