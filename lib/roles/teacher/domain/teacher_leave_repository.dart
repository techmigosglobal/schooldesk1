import 'package:schooldesk1/core/network/models/backend_models.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_leave_context.dart';

abstract interface class TeacherLeaveRepository {
  Future<Result<TeacherLeaveContext>> load({
    String? staffId,
    bool forceRefresh = false,
  });

  Future<Result<void>> submit(LeaveApplicationRequest request);

  Future<Result<void>> recall(String applicationId);
}
