import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/routes/schooldesk_screen_registry.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final profiles = <_ScreenQaProfile>[
    const _ScreenQaProfile(name: 'compact phone', size: Size(320, 640)),
    const _ScreenQaProfile(
      name: 'accessibility text',
      size: Size(390, 844),
      textScale: 1.3,
    ),
    const _ScreenQaProfile(name: 'tablet', size: Size(800, 1280)),
    const _ScreenQaProfile(name: 'landscape', size: Size(844, 390)),
  ];

  for (final profile in profiles) {
    testWidgets('routed screen frames keep layout stable on ${profile.name}', (
      tester,
    ) async {
      final layoutErrors = <String>[];

      for (final route in AppRoutes.routes.keys) {
        final errors = <FlutterErrorDetails>[];
        final previousOnError = FlutterError.onError;
        FlutterError.onError = errors.add;

        await tester.binding.setSurfaceSize(profile.size);
        try {
          await tester.pumpWidget(
            _RoutedScreenHarness(route: route, profile: profile),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 150));

          final routeErrors = errors.where(_isLayoutError).toList();
          if (routeErrors.isNotEmpty) {
            layoutErrors.add(
              '$route: ${routeErrors.map((e) => e.exceptionAsString()).join(' | ')}',
            );
          }

          final exception = tester.takeException();
          if (exception != null &&
              _isLayoutExceptionText(exception.toString())) {
            layoutErrors.add('$route: $exception');
          }
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          FlutterError.onError = previousOnError;
          await tester.binding.setSurfaceSize(null);
        }
      }

      expect(
        layoutErrors,
        isEmpty,
        reason:
            'All routed screen frames should avoid overflow, clipping, and invalid constraints on ${profile.name}.',
      );
    });
  }

  test('all active routes use registered design-system metadata', () {
    final missing = <String>[];
    for (final route in AppRoutes.routes.keys) {
      final metadata = SchoolDeskScreenRegistry.byRoute(route);
      if (metadata == null ||
          metadata.title.trim().isEmpty ||
          metadata.module.trim().isEmpty ||
          metadata.portal.trim().isEmpty) {
        missing.add(route);
      }
    }

    expect(missing, isEmpty);
  });
}

class _ScreenQaProfile {
  final String name;
  final Size size;
  final double textScale;

  const _ScreenQaProfile({
    required this.name,
    required this.size,
    this.textScale = 1,
  });
}

class _RoutedScreenHarness extends StatelessWidget {
  final String route;
  final _ScreenQaProfile profile;

  const _RoutedScreenHarness({required this.route, required this.profile});

  @override
  Widget build(BuildContext context) {
    final metadata = SchoolDeskScreenRegistry.byRoute(route);
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: profile.size,
          textScaler: TextScaler.linear(profile.textScale),
          padding: const EdgeInsets.only(top: 24),
        ),
        child: Builder(
          builder: (context) {
            return AppRoutes.buildRoutePage(
              context,
              routeName: route,
              child: _DesignSystemProbeScreen(
                route: route,
                title: metadata?.title ?? route,
                module: metadata?.module ?? 'Unknown',
                portal: metadata?.portal ?? 'shared',
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DesignSystemProbeScreen extends StatelessWidget {
  final String route;
  final String title;
  final String module;
  final String portal;

  const _DesignSystemProbeScreen({
    required this.route,
    required this.title,
    required this.module,
    required this.portal,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SchoolDeskAppBar(
        title: title,
        subtitle: '$portal portal - $module',
      ),
      bottomNavigationBar: SchoolDeskBottomNavigationBar(
        items: [
          SchoolDeskBottomNavItem(
            label: 'Home',
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            selected: true,
            onTap: () {},
          ),
          SchoolDeskBottomNavItem(
            label: 'Search Records',
            icon: Icons.search_rounded,
            activeIcon: Icons.manage_search_rounded,
            selected: false,
            onTap: () {},
          ),
          SchoolDeskBottomNavItem(
            label: 'Alerts',
            icon: Icons.notifications_none_rounded,
            activeIcon: Icons.notifications_rounded,
            selected: false,
            badgeCount: 125,
            onTap: () {},
          ),
          SchoolDeskBottomNavItem(
            label: 'Profile',
            icon: Icons.account_circle_outlined,
            activeIcon: Icons.account_circle_rounded,
            selected: false,
            onTap: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SchoolDeskPageHeader(
                title: title,
                subtitle:
                    'Validates global frame density, section balance, card alignment, and navigation scale.',
              ),
              SchoolDeskResponsiveGrid(
                children: const [
                  SchoolDeskStatBox(
                    label: 'Responsive scale',
                    value: 'OK',
                    caption: '130%',
                    icon: Icons.fit_screen_rounded,
                  ),
                  SchoolDeskStatBox(
                    label: 'Bottom navigation',
                    value: '4',
                    caption: 'Items',
                    icon: Icons.space_dashboard_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SchoolDeskSectionCard(
                title: module,
                subtitle:
                    'Long module labels should wrap without creating oversized cards or visual zoom.',
                child: SchoolDeskListTile(
                  title: '$portal route shell',
                  subtitle: route,
                  leadingIcon: Icons.route_rounded,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isLayoutError(FlutterErrorDetails error) {
  return _isLayoutExceptionText(error.exceptionAsString());
}

bool _isLayoutExceptionText(String text) {
  final lower = text.toLowerCase();
  return lower.contains('overflowed') ||
      lower.contains('renderflex') ||
      lower.contains('boxconstraints forces an infinite') ||
      lower.contains('vertical viewport was given unbounded') ||
      lower.contains('horizontal viewport was given unbounded') ||
      lower.contains('renderbox was not laid out');
}
