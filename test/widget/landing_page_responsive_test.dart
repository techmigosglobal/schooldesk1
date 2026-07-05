import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/features/shell/presentation/screens/landing_page_screen/landing_page_screen.dart';
import 'package:schooldesk1/routes/app_routes.dart';

void main() {
  final mobileSizes = <Size>[
    const Size(320, 568),
    const Size(360, 640),
    const Size(390, 844),
    const Size(412, 915),
    const Size(430, 932),
  ];

  for (final size in mobileSizes) {
    testWidgets(
      'landing page has no layout overflow at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: const LandingPageScreen(),
            onGenerateRoute: (settings) {
              if (settings.name == AppRoutes.principalLogin) {
                return MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('Login')),
                );
              }
              return null;
            },
          ),
        );
        await tester.pump();

        final exception = tester.takeException();
        if (exception != null) {
          fail(
            exception is FlutterError
                ? exception.toStringDeep()
                : exception.toString(),
          );
        }
        expect(find.text('Arish Ville Preschool'), findsOneWidget);
        expect(find.text('TechMigos'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
