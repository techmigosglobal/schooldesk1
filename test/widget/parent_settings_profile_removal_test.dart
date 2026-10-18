import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/theme_provider.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/features/profile/presentation/screens/settings_screen/settings_screen.dart';

void main() {
  testWidgets(
    'parent Settings keeps password and sign out without personal-profile links',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      GoogleFonts.config.allowRuntimeFetching = false;
      BackendApiClient.instance.setCurrentRole('parent');
      final theme = await ThemeProvider.create();
      final settings = await AppSettingsProvider.create();
      tester.view.physicalSize = const Size(900, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: theme),
            ChangeNotifierProvider.value(value: settings),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const AppSettingsScreen(role: 'parent'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('My account'), findsNothing);
      expect(find.text('My Profile'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Change Password'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Change Password'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Sign Out'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Sign Out'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      theme.dispose();
      settings.dispose();
    },
  );
}
