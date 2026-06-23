import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/widgets/animated_startup_splash.dart';

void main() {
  testWidgets('animated startup splash plays over app and then dismisses', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AnimatedStartupSplash(
          animationDuration: Duration(milliseconds: 240),
          child: Scaffold(body: Text('Home ready')),
        ),
      ),
    );

    expect(find.text('Home ready'), findsOneWidget);
    expect(find.byKey(AnimatedStartupSplash.overlayKey), findsOneWidget);
    expect(find.byKey(AnimatedStartupSplash.logoKey), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byKey(AnimatedStartupSplash.overlayKey), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 180));
    expect(find.byKey(AnimatedStartupSplash.overlayKey), findsNothing);
    expect(find.text('Home ready'), findsOneWidget);
  });
}
