import 'package:schooldesk1/core/network/models/backend_models.dart';

abstract interface class CalendarRepository {
  String? get currentRoleName;

  Future<List<AcademicYearModel>> loadAcademicYears();

  Future<List<Map<String, dynamic>>> loadEvents({String? academicYearId});

  Future<List<Map<String, dynamic>>> loadHolidays({String? academicYearId});

  Future<Map<String, dynamic>> loadPreferences();

  Future<Map<String, dynamic>> resetCalendar();

  Future<void> deleteEvent(String eventId);

  Future<Map<String, dynamic>> updateEvent(
    String eventId,
    Map<String, dynamic> payload,
  );

  Future<void> createEvent(Map<String, dynamic> payload);
}
