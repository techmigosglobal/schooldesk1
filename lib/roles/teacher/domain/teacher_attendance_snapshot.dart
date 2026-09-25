import 'package:schooldesk1/core/network/models/backend_models.dart';

class TeacherAttendanceSnapshot {
  final StaffAttendanceModel? today;
  final List<StaffAttendanceModel> log;

  const TeacherAttendanceSnapshot({required this.today, required this.log});
}
