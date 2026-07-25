import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/constants/app_constants.dart';
import 'package:schooldesk1/firebase_runtime_options.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/demo_local_api_service.dart';
import 'package:schooldesk1/core/services/notification_route_resolver.dart';
import 'package:schooldesk1/core/services/notification_service.dart';

@pragma('vm:entry-point')
Future<void> schoolDeskFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  // Firebase must be re-initialised in the background isolate because it runs
  // in a separate Dart VM context. Guard against double-initialisation.
  await PushNotificationService.ensureFirebaseInitialized();
  // Background message handling is intentionally minimal — the OS delivers
  // the notification UI automatically. Any heavy work risks being killed.
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const _pendingPayloadKey = 'schooldesk.pending_notification_payload';
  static const _firebaseOperationTimeout = Duration(seconds: 4);
  static const _deviceRegistrationTimeout = Duration(seconds: 5);
  static const _apnsRegistrationTimeout = Duration(seconds: 10);
  static const _androidChannel = AndroidNotificationChannel(
    'schooldesk_updates',
    '${AppConstants.appName} updates',
    description:
        'Important ${AppConstants.appName} alerts, messages, and reminders.',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  FirebaseMessaging? _messaging;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;
  StreamSubscription<String>? _onTokenRefreshSub;
  bool _initialized = false;
  bool _firebaseAvailable = false;
  bool _localNotificationsReady = false;
  bool _deviceRegistrationAttempted = false;
  bool _deviceRegistrationSucceeded = false;
  String? _currentToken;
  String? _permissionStatus;
  String? _lastRegistrationError;

  PushNotificationRuntimeStatus get runtimeStatus =>
      PushNotificationRuntimeStatus(
        initialized: _initialized,
        firebaseAvailable: _firebaseAvailable,
        localNotificationsReady: _localNotificationsReady || kIsWeb,
        hasDeviceToken: (_currentToken ?? '').isNotEmpty,
        deviceTokenPreview: _maskToken(_currentToken),
        deviceRegistrationAttempted: _deviceRegistrationAttempted,
        deviceRegistrationSucceeded: _deviceRegistrationSucceeded,
        permissionStatus: _permissionStatus ?? 'unknown',
        lastRegistrationError: _lastRegistrationError ?? '',
      );

  String get lastRegistrationError => _lastRegistrationError ?? '';

  String _maskToken(String? value) {
    final token = (value ?? '').trim();
    if (token.isEmpty) return '';
    if (token.length <= 10) return '***';
    return '${token.substring(0, 6)}...${token.substring(token.length - 4)}';
  }

  // ─── Topic Subscriptions (replaces legacy FcmService) ─────────────────────

  /// Subscribe to an FCM topic.
  Future<void> subscribeToTopic(String topic) async {
    final messaging = _messaging;
    if (messaging == null) return;
    try {
      await messaging
          .subscribeToTopic(topic)
          .timeout(_firebaseOperationTimeout);
    } on Object catch (error) {
      developer.log(
        'Failed to subscribe to topic $topic: $error',
        name: 'PushNotificationService',
      );
    }
  }

  /// Unsubscribe from an FCM topic.
  Future<void> unsubscribeFromTopic(String topic) async {
    final messaging = _messaging;
    if (messaging == null) return;
    try {
      await messaging
          .unsubscribeFromTopic(topic)
          .timeout(_firebaseOperationTimeout);
    } on Object catch (error) {
      developer.log(
        'Failed to unsubscribe from topic $topic: $error',
        name: 'PushNotificationService',
      );
    }
  }

  static Future<bool> ensureFirebaseInitialized() async {
    if (Firebase.apps.isNotEmpty) return true;
    try {
      final options = FirebaseRuntimeOptions.currentPlatform;
      if (options == null) {
        await Firebase.initializeApp();
      } else {
        await Firebase.initializeApp(options: options);
      }
      return true;
    } on Object catch (error) {
      developer.log(
        'Firebase initialization failed: $error',
        name: 'PushNotificationService',
      );
      return false;
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Firebase.initializeApp() is called in main() before runApp(), and
    // FirebaseMessaging.onBackgroundMessage() is also registered there.
    // Here we only verify the app is available before proceeding.
    _firebaseAvailable = Firebase.apps.isNotEmpty;
    if (!_firebaseAvailable) {
      // Attempt recovery in case the main() init was skipped (e.g. unit tests).
      _firebaseAvailable = await ensureFirebaseInitialized();
    }
    if (!_firebaseAvailable) return;

    _messaging = FirebaseMessaging.instance;
    await _requestPermissionAtStartup();
    await _initializeLocalNotifications();
    await _refreshToken();

    _onMessageSub = FirebaseMessaging.onMessage.listen(_handleForeground);
    _onOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleRemoteInteraction,
    );
    _onTokenRefreshSub = _messaging!.onTokenRefresh.listen((token) async {
      _currentToken = token;
      unawaited(registerDeviceTokenIfPossible());
    });

    final initial = await _messaging!.getInitialMessage().timeout(
      _firebaseOperationTimeout,
      onTimeout: () => null,
    );
    if (initial != null) {
      await _handleRemoteInteraction(initial);
    }
  }

  Future<void> registerDeviceTokenIfPossible() async {
    if (DemoLocalApiService.instance.isActive) return;
    if (!_firebaseAvailable || !BackendApiClient.instance.isAuthenticated) {
      _deviceRegistrationSucceeded = false;
      _lastRegistrationError = !_firebaseAvailable
          ? 'Firebase is not initialized on this device.'
          : 'Sign in before registering this device for push notifications.';
      return;
    }
    if (_currentToken == null || _currentToken!.isEmpty) {
      await _refreshToken();
    }
    final token = _currentToken;
    if (token == null || token.isEmpty) {
      _deviceRegistrationSucceeded = false;
      _lastRegistrationError = 'Firebase did not return a device token.';
      return;
    }

    try {
      _deviceRegistrationAttempted = true;
      final info = await PackageInfo.fromPlatform().timeout(
        _deviceRegistrationTimeout,
      );
      await BackendApiClient.instance
          .registerNotificationDeviceToken(
            token: token,
            platform: _platformName,
            deviceId: _platformName,
            appVersion: '${info.version}+${info.buildNumber}',
          )
          .timeout(_deviceRegistrationTimeout);
      _deviceRegistrationSucceeded = true;
      _lastRegistrationError = null;
    } on Object catch (error) {
      _deviceRegistrationSucceeded = false;
      _lastRegistrationError = error.toString();
      developer.log(
        'Failed to register device token with backend: $error',
        name: 'PushNotificationService',
      );
      // Push registration is best-effort and should never block app startup/login.
    }
  }

  Future<void> revokeCurrentToken() async {
    if (DemoLocalApiService.instance.isActive) return;
    final token = _currentToken;
    if (token == null ||
        token.isEmpty ||
        !BackendApiClient.instance.isAuthenticated) {
      return;
    }
    await BackendApiClient.instance
        .revokeNotificationDeviceToken(token: token)
        .timeout(_deviceRegistrationTimeout);
  }

  Future<void> handlePendingNotificationAfterLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pendingPayloadKey);
    if (raw == null || raw.isEmpty) return;
    await prefs.remove(_pendingPayloadKey);
    final payload = jsonDecode(raw);
    if (payload is Map<String, dynamic>) {
      await _openPayload(payload);
    }
  }

  Future<void> _requestPermissionAtStartup() async {
    final messaging = _messaging;
    if (messaging == null) return;
    try {
      final settings = _isApplePlatform
          ? await messaging.requestPermission(
              alert: true,
              announcement: false,
              badge: true,
              carPlay: false,
              criticalAlert: false,
              provisional: false,
              sound: true,
            )
          : await messaging.getNotificationSettings().timeout(
              _firebaseOperationTimeout,
            );
      _permissionStatus = settings.authorizationStatus.name;
      if (!kIsWeb) {
        await messaging
            .setForegroundNotificationPresentationOptions(
              alert: true,
              badge: true,
              sound: true,
            )
            .timeout(_firebaseOperationTimeout);
      }
    } on Object catch (error) {
      _permissionStatus = 'unavailable';
      _lastRegistrationError = error.toString();
      developer.log(
        'Failed to get notification settings at startup: $error',
        name: 'PushNotificationService',
      );
      // Keep the app usable if the platform cannot get settings.
    }
  }

  Future<void> _initializeLocalNotifications() async {
    if (kIsWeb) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
      linux: LinuxInitializationSettings(defaultActionName: 'Open'),
    );
    try {
      await _localNotifications
          .initialize(
            settings: settings,
            onDidReceiveNotificationResponse: (response) {
              final payload = response.payload;
              if (payload == null || payload.isEmpty) return;
              final decoded = jsonDecode(payload);
              if (decoded is Map<String, dynamic>) {
                _routeOrStore(decoded);
              }
            },
          )
          .timeout(_firebaseOperationTimeout);
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin
          ?.createNotificationChannel(_androidChannel)
          .timeout(_firebaseOperationTimeout);
      final androidNotificationsAllowed =
          await _requestAndroidNotificationPermission(androidPlugin);
      _localNotificationsReady = androidNotificationsAllowed != false;
    } on Object catch (error) {
      _localNotificationsReady = false;
      developer.log(
        'Failed to initialize local notifications: $error',
        name: 'PushNotificationService',
      );
    }
  }

  Future<bool?> _requestAndroidNotificationPermission(
    AndroidFlutterLocalNotificationsPlugin? androidPlugin,
  ) async {
    if (androidPlugin == null) return null;
    final enabled = await androidPlugin.areNotificationsEnabled().timeout(
      _firebaseOperationTimeout,
    );
    if (enabled == true) {
      _permissionStatus = 'authorized';
      return true;
    }

    final granted = await androidPlugin
        .requestNotificationsPermission()
        .timeout(_firebaseOperationTimeout);
    if (granted == false) {
      _permissionStatus = 'denied';
      _lastRegistrationError = 'Android notification permission was denied.';
      return false;
    }
    if (granted == true) {
      _permissionStatus = 'authorized';
      return true;
    }
    return null;
  }

  Future<void> _refreshToken() async {
    final messaging = _messaging;
    if (messaging == null) return;
    try {
      if (_isApplePlatform) {
        final deadline = DateTime.now().add(_apnsRegistrationTimeout);
        String? apnsToken;
        while (DateTime.now().isBefore(deadline)) {
          apnsToken = await messaging.getAPNSToken();
          if ((apnsToken ?? '').isNotEmpty) break;
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        if ((apnsToken ?? '').isEmpty) {
          throw StateError(
            'APNs token was not available after '
            '${_apnsRegistrationTimeout.inSeconds} seconds.',
          );
        }
      }

      _currentToken = await messaging
          .getToken(
            vapidKey: kIsWeb && EnvConfig.firebaseVapidKey.isNotEmpty
                ? EnvConfig.firebaseVapidKey
                : null,
          )
          .timeout(_firebaseOperationTimeout);
      if ((_currentToken ?? '').isNotEmpty) {
        _lastRegistrationError = null;
      }
    } on Object catch (error) {
      _currentToken = null;
      _lastRegistrationError = error.toString();
      developer.log(
        'Failed to refresh FCM token: $error',
        name: 'PushNotificationService',
      );
    }
  }

  Future<void> _handleForeground(RemoteMessage message) async {
    if (!_localNotificationsReady) return;
    final notification = message.notification;
    final title =
        notification?.title ?? message.data['title'] ?? AppConstants.appName;
    final body = notification?.body ?? message.data['body'] ?? '';
    await _localNotifications.show(
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
        linux: const LinuxNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
    NotificationService.getInstance().then((s) => s.refresh());
  }

  Future<void> _handleRemoteInteraction(RemoteMessage message) async {
    await _routeOrStore(message.data);
  }

  Future<void> _routeOrStore(Map<String, dynamic> data) async {
    if (!BackendApiClient.instance.isAuthenticated) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingPayloadKey, jsonEncode(data));
      _openLogin();
      return;
    }
    await _openPayload(data);
  }

  void _openLogin() {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushNamedAndRemoveUntil(AppRoutes.landingPage, (_) => false);
  }

  Future<void> _openPayload(Map<String, dynamic> data) async {
    try {
      final service = await NotificationService.getInstance();
      await service.refresh();
      final notificationId = (data['notification_id'] ?? data['id'] ?? '')
          .toString()
          .trim();
      if (notificationId.isNotEmpty) {
        await service.markAsRead(notificationId);
      }
    } on Object catch (_) {
      // Navigation should still proceed if notification refresh fails.
    }
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_openPayload(data));
      });
      return;
    }
    final target = NotificationRouteResolver.resolve(
      data: data,
      currentRole: BackendApiClient.instance.currentRoleName,
    );
    navigator.pushNamed(target.route, arguments: target.arguments);
  }

  String get _platformName {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'android',
    };
  }

  bool get _isApplePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<void> dispose() async {
    await _onMessageSub?.cancel();
    await _onOpenedSub?.cancel();
    await _onTokenRefreshSub?.cancel();
  }
}

class PushNotificationRuntimeStatus {
  const PushNotificationRuntimeStatus({
    required this.initialized,
    required this.firebaseAvailable,
    required this.localNotificationsReady,
    required this.hasDeviceToken,
    required this.deviceTokenPreview,
    required this.deviceRegistrationAttempted,
    required this.deviceRegistrationSucceeded,
    required this.permissionStatus,
    required this.lastRegistrationError,
  });

  final bool initialized;
  final bool firebaseAvailable;
  final bool localNotificationsReady;
  final bool hasDeviceToken;
  final String deviceTokenPreview;
  final bool deviceRegistrationAttempted;
  final bool deviceRegistrationSucceeded;
  final String permissionStatus;
  final String lastRegistrationError;

  bool get readyForPush =>
      firebaseAvailable &&
      localNotificationsReady &&
      hasDeviceToken &&
      deviceRegistrationSucceeded;
}
