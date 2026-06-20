import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('landing hero uses the supplied six artwork slides', () {
    final source = File(
      'lib/features/shell/presentation/screens/landing_page_screen/landing_page_screen.dart',
    ).readAsStringSync();

    final slideAssets = RegExp(
      r"'assets/images/landing_slide_[1-6]\.png'",
    ).allMatches(source);

    expect(slideAssets, hasLength(6));
    expect(source, contains('Image.asset'));
    expect(source, isNot(contains('_LandingSlide(')));
    expect(source, isNot(contains('showcaseTitle:')));
  });

  test('landing hero exposes only app-safe artwork actions', () {
    final source = File(
      'lib/features/shell/presentation/screens/landing_page_screen/landing_page_screen.dart',
    ).readAsStringSync();

    expect(source, contains('_LandingHeader'));
    expect(source, contains('_SignInButton'));
    expect(source, contains('AppRoutes.principalLogin'));
    expect(source, isNot(contains('Set Up School')));
    expect(source, isNot(contains('AppRoutes.onboarding')));
    expect(source, isNot(contains('Public Events')));
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
    expect(source, contains('AnimatedContainer'));
    expect(source, contains('Pause slideshow'));
    expect(source, contains('Resume slideshow'));
  });

  test('landing hero places slide dots at the bottom and frames brand images', () {
    final source = File(
      'lib/features/shell/presentation/screens/landing_page_screen/landing_page_screen.dart',
    ).readAsStringSync();

    expect(source, contains('_LandingFooter'));
    expect(source, contains('_TechmigasBrand'));
    expect(source, contains('_SlidePositionIndicator'));
    expect(source, contains('Learn Today, Lead Tomorrow'));
    expect(source, isNot(contains('Powered by SchoolDesk')));
    expect(
      source,
      isNot(
        contains(
          'Positioned(\n              left: sideInset,\n              right: sideInset,\n              top: isCompact ? 72 : 78,',
        ),
      ),
    );
  });
}
