import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:schooldesk1/core/navigation/schooldesk_navigation.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/schooldesk_route_frame.dart';
import 'package:schooldesk1/routes/schooldesk_screen_registry.dart';

void main() {
  testWidgets('navigation adapter preserves typed extra through GoRouter', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => Scaffold(
            body: ElevatedButton(
              onPressed: () => SchoolDeskNavigation.push(
                context,
                '/target',
                arguments: const {'student_id': 'student-1'},
              ),
              child: const Text('Open target'),
            ),
          ),
        ),
        GoRoute(
          path: '/target',
          builder: (context, state) => Scaffold(
            body: Text((state.extra as Map)['student_id'] as String),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Open target'));
    await tester.pumpAndSettle();

    expect(find.text('student-1'), findsOneWidget);
  });

  testWidgets('navigation adapter uses GoRouter go for replacement', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => Scaffold(
            body: ElevatedButton(
              onPressed: () => SchoolDeskNavigation.go(context, '/target'),
              child: const Text('Replace target'),
            ),
          ),
        ),
        GoRoute(
          path: '/target',
          builder: (context, state) => const Scaffold(
            body: Text('Target page'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Replace target'));
    await tester.pumpAndSettle();

    expect(find.text('Target page'), findsOneWidget);
    expect(router.canPop(), isFalse);
  });

  testWidgets('route frame lets GoRouter pop notification-style deep links', (
    tester,
  ) async {
    const homeMetadata = SchoolDeskScreenMetadata(
      route: '/teacher-dashboard-screen',
      title: 'Teacher Dashboard',
      module: 'Overview',
      portal: 'teacher',
    );
    const detailMetadata = SchoolDeskScreenMetadata(
      route: '/teacher-classes-screen',
      title: 'Teacher Classes',
      module: 'Academics',
      portal: 'teacher',
    );
    final router = GoRouter(
      initialLocation: homeMetadata.route,
      routes: [
        GoRoute(
          path: homeMetadata.route,
          builder: (context, state) => const SchoolDeskRouteFrame(
            metadata: homeMetadata,
            child: Scaffold(body: Text('Teacher home')),
          ),
        ),
        GoRoute(
          path: detailMetadata.route,
          builder: (context, state) => const SchoolDeskRouteFrame(
            metadata: detailMetadata,
            child: Scaffold(body: Text('Teacher classes')),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    );
    router.push(detailMetadata.route);
    await tester.pumpAndSettle();
    expect(find.text('Teacher classes'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Teacher home'), findsOneWidget);
  });
}
