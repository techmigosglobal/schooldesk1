import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'landing hero uses slide-specific showcase data without fake metrics',
    () {
      final source = File(
        'lib/presentation/landing_page_screen/landing_page_screen.dart',
      ).readAsStringSync();

      final showcaseTitles = RegExp(
        r"showcaseTitle: '([^']+)'",
      ).allMatches(source).map((match) => match.group(1)).toSet();

      expect(showcaseTitles, hasLength(greaterThanOrEqualTo(5)));
      expect(source, isNot(contains("'98%'")));
      expect(source, isNot(contains("'32+'")));
      expect(source, isNot(contains("'24/7'")));
    },
  );
}
