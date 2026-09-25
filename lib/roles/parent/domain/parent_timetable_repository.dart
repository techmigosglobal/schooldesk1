import 'package:schooldesk1/core/utils/result.dart';

abstract interface class ParentTimetableRepository {
  Future<Result<List<Map<String, dynamic>>>> loadChildren();

  Future<Result<List<Map<String, dynamic>>>> loadSlots({
    required String sectionId,
  });
}
