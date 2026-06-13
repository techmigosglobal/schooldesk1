import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('landing hero uses slide-specific showcase data without fake metrics', () {
    final source = File(
      'lib/features/shell/presentation/screens/landing_page_screen/landing_page_screen.dart',
    ).readAsStringSync();

    final showcaseTitles = RegExp(
      r"showcaseTitle: '([^']+)'",
    ).allMatches(source).map((match) => match.group(1)).toSet();

    expect(showcaseTitles, hasLength(greaterThanOrEqualTo(5)));
    expect(source, isNot(contains("'98%'")));
    expect(source, isNot(contains("'32+'")));
    expect(source, isNot(contains("'24/7'")));
  });

  test('landing hero carousel has production autoplay controls', () {
    final source = File(
      'lib/features/shell/presentation/screens/landing_page_screen/landing_page_screen.dart',
    ).readAsStringSync();

    expect(source, contains('_autoSlideInterval'));
    expect(source, contains('_restartAutoSlideTimer'));
    expect(source, contains('_pauseAutoSlide'));
    expect(source, contains('_resumeAutoSlide'));
    expect(source, contains('_autoSlidePausedByUser'));
    expect(source, contains('MediaQuery.disableAnimationsOf(context)'));
    expect(source, contains('NotificationListener<ScrollNotification>'));
    expect(source, contains('LinearProgressIndicator'));
    expect(source, contains('Pause carousel'));
    expect(source, contains('Resume carousel'));
  });
}
