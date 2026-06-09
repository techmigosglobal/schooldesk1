import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('class CSV timetable generation stays on the Admin timetable path', () {
    final importer = File(
      'lib/core/services/bulk_csv_import_service.dart',
    ).readAsStringSync();
    final adminTimetable = File(
      'lib/features/academics/presentation/screens/admin_timetable_screen/admin_timetable_screen.dart',
    ).readAsStringSync();
    final adminTimetableForms = File(
      'lib/features/academics/presentation/screens/admin_timetable_screen/admin_timetable_form_screens.dart',
    ).readAsStringSync();
    final timetableHandler = File(
      'school-backend/internal/handlers/timetable.go',
    ).readAsStringSync();
    final principalClasses = File(
      'lib/features/academics/presentation/screens/principal_classes_screen/principal_classes_screen.dart',
    ).readAsStringSync();
    final timetableApi = File(
      'lib/core/network/api_modules/timetable_api.dart',
    ).readAsStringSync();

    expect(importer, contains('BulkCsvImportTarget.classTimetables'));
    expect(importer, contains('generateSmartTimetable('));
    expect(
      importer,
      contains('breaks: _breakRowsFor(row, days, periodsPerDay)'),
    );
    expect(importer, contains('short_break_period'));
    expect(importer, contains('short_break_start_time'));
    expect(importer, contains('short_break_end_time'));
    expect(importer, contains('long_break_period'));
    expect(importer, contains('long_break_start_time'));
    expect(importer, contains('long_break_end_time'));
    expect(importer, contains('Lunch Break'));
    expect(importer, contains("route: AppRoutes.adminTimetable"));
    expect(importer, contains('timetable writes are Admin-owned'));
    expect(importer, contains('all-features class CSV'));
    expect(importer, contains('getTerms(year.id)'));
    expect(importer, contains('section.academicYearId != academicYearId'));
    expect(importer, contains('working_days'));
    expect(importer, contains('periods_per_week'));
    expect(importer, contains('created_slots'));
    expect(importer, contains('conflicts'));
    expect(importer, contains('logs'));

    expect(adminTimetable, contains('BulkCsvImportService.importCsv'));
    expect(adminTimetable, contains('BulkCsvImportTarget.classTimetables'));
    expect(adminTimetable, contains('Generate from class CSV'));
    expect(adminTimetable, contains('await _loadBackendTimetable();'));
    expect(adminTimetable, contains('api.getRooms()'));
    expect(adminTimetable, contains('Class room:'));
    expect(
      adminTimetableForms,
      contains("decoration: const InputDecoration(labelText: 'Room')"),
    );
    expect(adminTimetableForms, contains("'room_id': _roomId"));
    expect(timetableHandler, contains('room is already booked during period'));
    expect(timetableHandler, contains('chooseTimetableRoom'));
    expect(timetableApi, contains("'breaks': breaks"));

    expect(principalClasses, contains('BulkCsvImportTarget.classes'));
    expect(principalClasses, contains("label: 'Room Number'"));
    expect(principalClasses, contains("label: 'Short break period'"));
    expect(principalClasses, contains("label: 'Short break start'"));
    expect(principalClasses, contains("label: 'Short break end'"));
    expect(principalClasses, contains("label: 'Long break period'"));
    expect(principalClasses, contains("label: 'Long break start'"));
    expect(principalClasses, contains("label: 'Long break end'"));
    expect(principalClasses, contains('breaks: _breakRows'));
    expect(
      principalClasses,
      isNot(contains('BulkCsvImportTarget.classTimetables')),
    );
  });

  test('teacher timetable output remains the same backend slot source', () {
    final timetableApi = File(
      'lib/core/network/api_modules/timetable_api.dart',
    ).readAsStringSync();
    final principalTimetable = File(
      'lib/features/academics/presentation/screens/principal_command_center_screens/principal_academic_command_screens.dart',
    ).readAsStringSync();

    expect(timetableApi, contains('staff_id'));
    expect(timetableApi, contains('/timetable/slots'));
    expect(timetableApi, contains('/timetable/smart/generate'));
    expect(principalTimetable, contains('_TimetableHomeMode.teachers'));
    expect(principalTimetable, contains('Teacher Timetable'));
  });
}
