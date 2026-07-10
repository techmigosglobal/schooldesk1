import 'dart:async';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import 'package:flutter/semantics.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';

import 'package:schooldesk1/core/app_export.dart';
import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/constants/app_constants.dart';
import 'package:schooldesk1/core/di/service_locator.dart';
import 'package:schooldesk1/routes/route_access_guard.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/push_notification_service.dart';
import 'package:schooldesk1/core/services/error_reporting_service.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/services/theme_provider.dart';
import 'package:schooldesk1/core/widgets/animated_startup_splash.dart';
import 'package:schooldesk1/core/widgets/custom_error_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  GoogleFonts.config.allowRuntimeFetching = false;

  // ── Validate environment FIRST ───────────────────────────────────────────
  // This must be the first substantive call so that a missing/misconfigured
  // build-time define fails loudly before any SDK or network code runs.
  // If this throws in production it means the APK/AAB was built without the
  // required --dart-define-from-file=env.supabase.json flag.
  EnvConfig.validate();

  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
  );

  await BackendApiClient.initialize();
  if (EnvConfig.enableLogging) {
    developer.log(
      '[API CONFIG] Backend attached: ${BackendApiClient.instance.baseUrl}',
      name: 'BackendApiClient',
    );
  }
  await ErrorReportingService.instance.initialize();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(ErrorReportingService.instance.recordFlutterError(details));
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(ErrorReportingService.instance.recordPlatformError(error, stack));
    return false;
  };
  await ServiceLocator.initialize();

  // Initialize theme provider
  final themeProvider = await ThemeProvider.create();
  final appSettingsProvider = await AppSettingsProvider.create();

  bool hasShownError = false;

  // 🚨 CRITICAL: Custom error handling - DO NOT REMOVE
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (!hasShownError) {
      hasShownError = true;

      // Reset flag after 3 seconds to allow error widget on new screens
      Future.delayed(const Duration(seconds: 5), () {
        hasShownError = false;
      });

      return CustomErrorWidget(errorDetails: details);
    }
    return const SizedBox.shrink();
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
  _deferStartupServices();
}

void _deferStartupServices() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initializeDeferredStartupServices());
  });
}

/// Retries [fn] up to [maxAttempts] times with exponential backoff.
/// Delays: 1 s, 2 s, 4 s, … capped at [maxDelay].
Future<void> _withRetry(
  Future<void> Function() fn, {
  String name = 'op',
  int maxAttempts = 4,
  Duration maxDelay = const Duration(seconds: 16),
}) async {
  var delay = const Duration(seconds: 1);
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      await fn();
      return;
    } on Object catch (error) {
      if (attempt == maxAttempts) {
        developer.log(
          '$name failed after $maxAttempts attempts: $error',
          name: 'startup',
          level: 1000,
        );
        return;
      }
      developer.log(
        '$name attempt $attempt failed ($error). Retrying in ${delay.inSeconds}s…',
        name: 'startup',
      );
      await Future<void>.delayed(delay);
      delay = delay * 2;
      if (delay > maxDelay) delay = maxDelay;
    }
  }
}

Future<void> _initializeDeferredStartupServices() async {
  // Session restore and role init are retried with backoff (network-dependent).
  await _withRetry(
    BackendApiClient.instance.restoreStoredSession,
    name: 'restoreStoredSession',
  );
  await _withRetry(
    RoleAccessService.initialize,
    name: 'RoleAccessService.initialize',
  );
  // Push notification init is best-effort; no retry needed.
  try {
    await PushNotificationService.instance.initialize();
    await PushNotificationService.instance.registerDeviceTokenIfPossible();
  } on Object catch (error) {
    developer.log(
      'Push notification init failed (non-fatal): $error',
      name: 'startup',
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Cancel FCM subscriptions when the app is permanently destroyed.
    unawaited(PushNotificationService.instance.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      unawaited(PushNotificationService.instance.dispose());
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final appSettingsProvider = context.watch<AppSettingsProvider>();
    return Sizer(
      builder: (context, orientation, screenType) {
        return MaterialApp(
          title: AppConstants.schoolName,
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
              child: AnimatedStartupSplash(child: child!),
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
