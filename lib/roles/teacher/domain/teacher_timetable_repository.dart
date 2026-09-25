import 'package:schooldesk1/core/utils/result.dart';

abstract interface class TeacherTimetableRepository {
  Future<Result<List<int>>> loadWorkingDays();

  Future<Result<List<Map<String, dynamic>>>> loadSlots({
    required String sectionId,
  });
}
