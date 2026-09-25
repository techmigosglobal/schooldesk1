import 'package:schooldesk1/core/utils/result.dart';

class IdCardData {
  const IdCardData({
    required this.students,
    required this.academicYear,
    required this.school,
  });

  final List<Map<String, dynamic>> students;
  final String academicYear;
  final Map<String, dynamic> school;
}

abstract interface class IdCardRepository {
  Future<Result<IdCardData>> load({bool forceRefresh = false});
}
