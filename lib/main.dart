import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';
import 'package:flutter/semantics.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:schooldesk1/core/app_export.dart';
import 'package:schooldesk1/app/app.dart';
import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/desktop/desktop_window_manager.dart';
import 'package:schooldesk1/core/desktop/desktop_platform.dart';
import 'package:schooldesk1/core/di/service_locator.dart';
import 'package:schooldesk1/firebase_runtime_options.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/offline/offline_sync_engine.dart';
import 'package:schooldesk1/core/offline/offline_background_sync.dart';
import 'package:schooldesk1/core/services/push_notification_service.dart';
import 'package:schooldesk1/core/services/error_reporting_service.dart';
import 'package:schooldesk1/core/services/android_update_service.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/services/theme_provider.dart';
import 'package:schooldesk1/core/widgets/custom_error_widget.dart';

SemanticsHandle? _appSemanticsHandle;

@visibleForTesting
void disposeAppSemanticsHandleForTesting() {
  _appSemanticsHandle?.dispose();
  _appSemanticsHandle = null;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _appSemanticsHandle ??= SemanticsBinding.instance.ensureSemantics();
  GoogleFonts.config.allowRuntimeFetching = false;

  // ── Validate environment FIRST ───────────────────────────────────────────
  // This must be the first substantive call so that a missing/misconfigured
  // build-time define fails loudly before any SDK or network code runs.
  // If this throws in production it means the APK/AAB was built without the
  // required --dart-define-from-file=env.supabase.json flag.
  EnvConfig.validate();

  final offlineSync = await _startupStep(
    'OfflineSyncEngine.initialize',
    OfflineSyncEngine.initialize,
  );
  BackendApiClient.instance.attachOfflineSync(offlineSync);

  // ── Firebase — MUST be initialised before any Firebase API is called ─────
  // FlutterFire reads GoogleService-Info.plist (iOS) / google-services.json
  // (Android) automatically when options is null; Dart-define overrides
  // supplement that for environments that need runtime configuration.
  try {
    await _startupStep(
      'Firebase.initializeApp',
      () => Firebase.initializeApp(
        options: FirebaseRuntimeOptions.currentPlatform,
      ),
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

  await _startupStep(
    'Supabase.initialize',
    () => Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      anonKey: EnvConfig.supabaseAnonKey,
    ),
  );

  await _startupStep(
    'BackendApiClient.initialize',
    BackendApiClient.initialize,
  );
  if (EnvConfig.enableLogging) {
    developer.log(
      '[API CONFIG] Backend attached: ${BackendApiClient.instance.baseUrl}',
      name: 'BackendApiClient',
    );
  }
  await _startupStep(
    'ErrorReportingService.initialize',
    ErrorReportingService.instance.initialize,
  );
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(ErrorReportingService.instance.recordFlutterError(details));
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(ErrorReportingService.instance.recordPlatformError(error, stack));
    return false;
  };
  await _startupStep('ServiceLocator.initialize', ServiceLocator.initialize);
  unawaited(offlineSync.start());
  unawaited(OfflineBackgroundSyncScheduler.initialize());

  await _startupStep('DesktopWindowManager.init', DesktopWindowManager.init);

  // Initialize theme provider
  final themeProvider = await _startupStep(
    'ThemeProvider.create',
    ThemeProvider.create,
  );
  final appSettingsProvider = await _startupStep(
    'AppSettingsProvider.create',
    AppSettingsProvider.create,
  );

  // Never hide a framework error. A blank screen makes failures impossible for
  // a user to report and prevents the error boundary's retry action from being
  // reached when more than one widget fails in the same frame.
  ErrorWidget.builder = buildSchoolDeskErrorWidget;

  developer.log('[startup] runApp begin', name: 'startup');
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

Future<T> _startupStep<T>(String name, Future<T> Function() operation) async {
  developer.log('[startup] $name begin', name: 'startup');
  try {
    final result = await operation();
    developer.log('[startup] $name complete', name: 'startup');
    return result;
  } on Object catch (error, stackTrace) {
    developer.log(
      '[startup] $name failed',
      name: 'startup',
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
    rethrow;
  }
}

/// The application-wide error boundary is deliberately a pure builder so every
/// framework failure remains visible, including multiple failures in one frame.
Widget buildSchoolDeskErrorWidget(FlutterErrorDetails details) =>
    CustomErrorWidget(errorDetails: details);

void _deferStartupServices() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_checkAndroidUpdate());
    unawaited(_initializeDeferredStartupServices());
  });
}

Future<void> _checkAndroidUpdate() async {
  // Give MaterialApp.router time to attach the root navigator before showing
  // the non-blocking update affordance.
  await Future<void>.delayed(const Duration(milliseconds: 1500));
  final info = await AndroidUpdateService.instance.checkOncePerDay();
  if (info == null) return;
  final navigatorState = PushNotificationService.navigatorKey.currentState;
  if (navigatorState == null) return;
  ScaffoldMessenger.of(navigatorState.context).showSnackBar(
    SnackBar(
      content: const Text('A new SchoolDesk update is available.'),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'Update',
        onPressed: () =>
            unawaited(AndroidUpdateService.instance.startUpdate(info)),
      ),
    ),
  );
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
  DateTime? _backgroundedAt;

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
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _backgroundedAt ??= DateTime.now();
      if (EnvConfig.enableLogging) {
        developer.log('App moved to $state', name: 'lifecycle');
      }
      return;
    }
    if (state == AppLifecycleState.resumed) {
      final backgroundedAt = _backgroundedAt;
      _backgroundedAt = null;
      final wasBackgroundedLongEnough =
          backgroundedAt != null &&
          DateTime.now().difference(backgroundedAt) >=
              const Duration(seconds: 45);
      if (EnvConfig.enableLogging) {
        developer.log(
          'App resumed; recovery=${wasBackgroundedLongEnough ? 'scheduled' : 'skipped'}',
          name: 'lifecycle',
        );
      }
      // Android sends short inactive/hidden transitions for the notification
      // shade, screenshots, permission surfaces, and some media pickers. A
      // quick resume is not a connectivity recovery event and must not reset
      // the visible screen or delete its cached snapshot.
      if (wasBackgroundedLongEnough &&
          BackendApiClient.instance.isAuthenticated) {
        unawaited(_recoverRoleScopeIfOnline());
        unawaited(OfflineSyncEngine.instance.syncNow());
      }
    }
    if (state == AppLifecycleState.detached) {
      unawaited(PushNotificationService.instance.dispose());
    }
  }

  Future<void> _recoverRoleScopeIfOnline() async {
    // A cached profile is not proof that the backend is reachable. Do not
    // invalidate the only local snapshot during an offline resume.
    if (!await OfflineSyncEngine.instance.probeBackend()) return;
    try {
      // RoleAccessService performs the authoritative role-specific refresh.
      // Do not invalidate every cached read here: doing so caused a visible
      // blank/reload cycle when Android briefly backgrounded the activity.
      await RoleAccessService.refreshAfterConnectivity();
    } on Object {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final appSettingsProvider = context.watch<AppSettingsProvider>();
    return SchoolDeskApp(
      themeMode: themeProvider.themeMode,
      textScaleFactor: appSettingsProvider.appTextScaleFactor,
    );
  }
}
