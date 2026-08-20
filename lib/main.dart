import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';
import 'package:flutter/semantics.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:schooldesk1/core/app_export.dart';
import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/constants/app_constants.dart';
import 'package:schooldesk1/core/desktop/desktop_window_manager.dart';
import 'package:schooldesk1/core/desktop/desktop_layout_wrapper.dart';
import 'package:schooldesk1/core/desktop/desktop_platform.dart';
import 'package:schooldesk1/core/di/service_locator.dart';
import 'package:schooldesk1/firebase_runtime_options.dart';
import 'package:schooldesk1/routes/route_access_guard.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/push_notification_service.dart';
import 'package:schooldesk1/core/services/error_reporting_service.dart';
import 'package:schooldesk1/core/services/demo_local_api_service.dart';
import 'package:schooldesk1/core/services/demo_sandbox_service.dart';
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

  // ── Firebase — MUST be initialised before any Firebase API is called ─────
  // FlutterFire reads GoogleService-Info.plist (iOS) / google-services.json
  // (Android) automatically when options is null; Dart-define overrides
  // supplement that for environments that need runtime configuration.
  try {
    await Firebase.initializeApp(
      options: FirebaseRuntimeOptions.currentPlatform,
    );
    developer.log('[Firebase] Initialized successfully.', name: 'startup');
  } on Object catch (error) {
    // Firebase init failing is non-fatal for app rendering but push
    // notifications will be unavailable. Log clearly so it is visible.
    developer.log(
      '[Firebase] initializeApp failed (push notifications unavailable): $error',
      name: 'startup',
      level: 1000,
    );
  }

  // ── Background message handler — must be registered before runApp() ──────
  // FirebaseMessaging requires this to be a top-level call so the Dart VM
  // can find the entry-point when the app is woken for a background message.
  if (!DesktopPlatform.isWindows) {
    FirebaseMessaging.onBackgroundMessage(
      schoolDeskFirebaseMessagingBackgroundHandler,
    );
  }

  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
  );

  await BackendApiClient.initialize();
  await _restoreLocalDemoSessionIfNeeded();
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

  await DesktopWindowManager.init();

  // Initialize theme provider
  final themeProvider = await ThemeProvider.create();
  final appSettingsProvider = await AppSettingsProvider.create();

  // Never hide a framework error. A blank screen makes failures impossible for
  // a user to report and prevents the error boundary's retry action from being
  // reached when more than one widget fails in the same frame.
  ErrorWidget.builder = buildSchoolDeskErrorWidget;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<AppSettingsProvider>.value(
          value: appSettingsProvider,
        ),
      ],
      child: const AppProviders(child: MyApp()),
    ),
  );
  _deferStartupServices();
}

/// Restores only a verified fictional demo snapshot. This has no production
/// token, no stored demo password, and routes subsequent operational calls to
/// the on-device façade rather than the backend.
Future<void> _restoreLocalDemoSessionIfNeeded() async {
  final sandbox = DemoSandboxService.instance;
  if (!await sandbox.isActive()) return;

  final stored = await sandbox.snapshot();
  if (stored == null) {
    await sandbox.end();
    return;
  }

  final selectedRole = (await sandbox.selectedRole())?.trim().toLowerCase();
  const selectableRoles = {'principal', 'teacher', 'parent'};
  if (selectedRole == null || !selectableRoles.contains(selectedRole)) {
    DemoLocalApiService.instance.awaitRoleSelection();
    return;
  }

  final nestedSnapshot = stored['snapshot'];
  final snapshot = nestedSnapshot is Map
      ? Map<String, dynamic>.from(nestedSnapshot)
      : stored;
  DemoLocalApiService.instance.start(role: selectedRole, snapshot: snapshot);
  BackendApiClient.instance.beginLocalDemoSession(
    role: selectedRole,
    userId: DemoLocalApiService.localUserId,
    schoolId: DemoLocalApiService.localSchoolId,
  );
  RoleAccessService.resetSignOutGuard();
}

/// The application-wide error boundary is deliberately a pure builder so every
/// framework failure remains visible, including multiple failures in one frame.
Widget buildSchoolDeskErrorWidget(FlutterErrorDetails details) =>
    CustomErrorWidget(errorDetails: details);

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
  // A demo deliberately has no live session to restore. In particular, do not
  // let a stale production token replace its local role after startup.
  if (!DemoLocalApiService.instance.isActive &&
      !DemoLocalApiService.instance.isAwaitingRoleSelection) {
    await _withRetry(
      BackendApiClient.instance.restoreStoredSession,
      name: 'restoreStoredSession',
    );
  }
  await _withRetry(
    RoleAccessService.initialize,
    name: 'RoleAccessService.initialize',
  );
  // Push notification init is best-effort; no retry needed.
  if (!DesktopPlatform.isWindows) {
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
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Timer? _scopeRecoveryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scopeRecoveryTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (BackendApiClient.instance.isAuthenticated &&
          !RoleAccessService.isInitialized) {
        unawaited(_recoverRoleScopeIfOnline());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scopeRecoveryTimer?.cancel();
    _scopeRecoveryTimer = null;
    // Cancel FCM subscriptions when the app is permanently destroyed.
    unawaited(PushNotificationService.instance.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        BackendApiClient.instance.isAuthenticated) {
      // A device can regain Wi-Fi/mobile data while the process is still
      // alive. The probe prevents an offline resume from deleting the only
      // persistent snapshot before the backend is reachable again.
      unawaited(_recoverRoleScopeIfOnline());
    }
    if (state == AppLifecycleState.detached) {
      unawaited(PushNotificationService.instance.dispose());
    }
  }

  Future<void> _recoverRoleScopeIfOnline() async {
    final api = BackendApiClient.instance;
    try {
      await api.getProfile(forceRefresh: true);
    } on Object {
      return;
    }
    await api.invalidateCachedReads();
    await RoleAccessService.refreshAfterConnectivity();
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
              child: DesktopLayoutWrapper(
                child: AnimatedStartupSplash(child: child!),
              ),
            );
          },
          debugShowCheckedModeBanner: false,
          initialRoute: DemoLocalApiService.instance.isAwaitingRoleSelection
              ? AppRoutes.demoRoleSelector
              : RouteAccessGuard.initialRouteFor(
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
