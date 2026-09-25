import 'package:schooldesk1/core/utils/result.dart';

abstract interface class ParentHealthRepository {
  Future<Result<List<Map<String, dynamic>>>> loadChildren();

  Future<Result<List<Map<String, dynamic>>>> loadReminders(String studentId);

  Future<Result<void>> createReminder(Map<String, dynamic> payload);

  Future<Result<void>> updateReminder(
    String reminderId,
    Map<String, dynamic> payload,
  );

  Future<Result<void>> deleteReminder(String reminderId);
}
