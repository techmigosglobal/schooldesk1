import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/routes/schooldesk_screen_registry.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/schooldesk_route_frame.dart';

void main() {
  test('every active route has product metadata for the redesign shell', () {
    final missing = <String>[];

    for (final route in AppRoutes.routes.keys) {
      final metadata = SchoolDeskScreenRegistry.byRoute(route);
      if (metadata == null ||
          metadata.title.trim().isEmpty ||
          metadata.module.trim().isEmpty) {
        missing.add(route);
      }
    }

    expect(missing, isEmpty);
  });

  test('student routes remain intentionally owned by the parent portal', () {
    expect(
      SchoolDeskScreenRegistry.all.any((screen) => screen.portal == 'student'),
      isFalse,
    );
    expect(
      AppRoutes.routes.keys.any((route) => route.contains('student-dashboard')),
      isFalse,
    );
    expect(
      SchoolDeskScreenRegistry.all.any(
        (screen) => screen.route == AppRoutes.parentDashboard,
      ),
      isTrue,
    );
  });

  testWidgets('route frame exposes screen metadata to semantics', (
    tester,
  ) async {
    const metadata = SchoolDeskScreenMetadata(
      route: '/example',
      title: 'Example Screen',
      module: 'Testing',
      portal: 'admin',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const SchoolDeskRouteFrame(
          metadata: metadata,
          child: Scaffold(body: Text('Example body')),
        ),
      ),
    );

    expect(find.text('Example body'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(SchoolDeskRouteFrame)),
      matchesSemantics(label: 'Admin portal, Testing, Example Screen'),
    );
  });
}
