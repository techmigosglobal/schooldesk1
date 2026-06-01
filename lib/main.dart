import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';

import 'package:schooldesk1/core/app_export.dart';
import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/di/service_locator.dart';
import 'package:schooldesk1/routes/route_access_guard.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/push_notification_service.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/services/theme_provider.dart';
import 'package:schooldesk1/core/widgets/custom_error_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  await BackendApiClient.initialize();
  await ServiceLocator.initialize();
  EnvConfig.validate();
  unawaited(RoleAccessService.initialize());
  await PushNotificationService.instance.initialize();
  unawaited(PushNotificationService.instance.registerDeviceTokenIfPossible());

  // Initialize theme provider
  final themeProvider = await ThemeProvider.create();
  final appSettingsProvider = await AppSettingsProvider.create();

  bool hasShownError = false;

  // 🚨 CRITICAL: Custom error handling - DO NOT REMOVE
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (!hasShownError) {
      hasShownError = true;

      // Reset flag after 3 seconds to allow error widget on new screens
      Future.delayed(Duration(seconds: 5), () {
        hasShownError = false;
      });

      return CustomErrorWidget(errorDetails: details);
    }
    return SizedBox.shrink();
  };

  runApp(
    ProviderScope(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
          ChangeNotifierProvider<AppSettingsProvider>.value(
            value: appSettingsProvider,
          ),
        ],
        child: const AppProviders(child: MyApp()),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final appSettingsProvider = context.watch<AppSettingsProvider>();
    return Sizer(
      builder: (context, orientation, screenType) {
        return MaterialApp(
          title: 'schooldesk',
          navigatorKey: PushNotificationService.navigatorKey,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            final effectiveTextScale = mediaQuery.textScaler.scale(
              appSettingsProvider.appTextScaleFactor,
            );
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(effectiveTextScale).clamp(
                  maxScaleFactor: SchoolDeskResponsive.maxSupportedTextScale,
                ),
              ),
              child: child!,
            );
          },
          debugShowCheckedModeBanner: false,
          initialRoute: RouteAccessGuard.initialRouteFor(
            isAuthenticated: BackendApiClient.instance.isAuthenticated,
            currentRole: BackendApiClient.instance.currentRoleName,
          ),
          onGenerateRoute: (settings) {
            final routeName = settings.name;
            final builder = AppRoutes.routes[routeName];

            if (builder == null) return null;

            final redirectRoute = RouteAccessGuard.redirectFor(
              routeName: routeName,
              isAuthenticated: BackendApiClient.instance.isAuthenticated,
              currentRole: BackendApiClient.instance.currentRoleName,
            );
            if (redirectRoute != null) {
              return MaterialPageRoute(
                settings: RouteSettings(name: redirectRoute),
                builder: (context) => AppRoutes.buildRoutePage(
                  context,
                  routeName: redirectRoute,
                  routeBuilder: AppRoutes.routes[redirectRoute]!,
                ),
              );
            }

            return MaterialPageRoute(
              settings: settings,
              builder: (context) => AppRoutes.buildRoutePage(
                context,
                routeName: routeName!,
                routeBuilder: builder,
              ),
            );
          },
        );
      },
    );
  }
}
