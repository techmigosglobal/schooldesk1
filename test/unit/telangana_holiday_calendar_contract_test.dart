import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Telangana 2026-27 migration contains all 24 supplied holidays', () {
    final source = File(
      'supabase/migrations/20260815083849_seed_telangana_holiday_calendar_2026_27.sql',
    ).readAsStringSync();

    const holidays = [
      'Muharram (Ashoora)',
      'Bonalu',
      'Independence Day',
      'Varamahalakshmi Vratha',
      'Rakhi',
      'Krishna Jayanthi',
      'Vinayaka Chavithi',
      'Vinayaka Nimaranam',
      'Mahatma Gandhi Jayanti',
      'Dussehra Holidays',
      'Deepawali Holidays',
      'Gurunanak Jayanthi',
      'Christmas & New Year Holidays',
      'Bhogi / Makara Sankranti Holidays',
      'Republic Day',
      'Vasant Panchami',
      'Maha Shivaratri',
      'Ramzan Id (Tentative Date)',
      'Holi',
      'Good Friday',
      'Gudi Padwa',
      'Ambedkar Jayanthi',
      'Rama Navami',
      'Mahaveer Jayanthi',
    ];

    for (final holiday in holidays) {
      expect(source, contains("('$holiday'"), reason: holiday);
    }
    expect(source, contains("date '2026-10-10', date '2026-10-21'"));
    expect(source, contains("date '2027-03-10', date '2027-03-10'"));
    expect(source, contains('where not exists'));
  });

  test('the supplied PDF spelling and local seed order are preserved', () {
    const sources = [
      'supabase/migrations/20260830134507_fix_telangana_holiday_calendar_academic_year_range.sql',
      'supabase/seed.sql',
      'supabase/seed_local_security.sql',
    ];
    for (final path in sources) {
      final source = File(path).readAsStringSync();
      expect(source, contains("'Vinayaka Nimarjanam'"), reason: path);
      expect(source, contains("'Dussehra Holidays'"), reason: path);
      expect(source, contains("date '2027-04-19'"), reason: path);
    }
  });

  test('calendar keeps official holidays separate from events', () {
    final api = File(
      'lib/core/network/api_modules/events_api.dart',
    ).readAsStringSync();
    final calendar = File(
      'lib/features/calendar/presentation/screens/events_calendar_screen/events_calendar_screen.dart',
    ).readAsStringSync();
    final handler = File(
      'supabase/functions/api/handlers/calendar.ts',
    ).readAsStringSync();

    expect(api, contains("Future<List<Map<String, dynamic>>> getHolidays"));
    expect(api, contains("'/holidays'"));
    expect(calendar, contains('fromHoliday'));
    expect(calendar, contains('isStoredHoliday'));
    expect(handler, contains('isHolidayPayload'));
    expect(handler, contains('event_created'));
  });
}
