import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/services/android_update_service.dart';

void main() {
  test('uses the local calendar date for the once-per-day gate', () {
    final first = AndroidUpdateService.dateKey(DateTime(2026, 10, 2, 23, 59));
    final sameDay = AndroidUpdateService.dateKey(DateTime(2026, 10, 2, 1, 0));
    final nextDay = AndroidUpdateService.dateKey(DateTime(2026, 10, 3, 0, 1));

    expect(first, sameDay);
    expect(first, isNot(nextDay));
  });
}
