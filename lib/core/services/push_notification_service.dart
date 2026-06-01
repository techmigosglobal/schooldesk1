import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/firebase_runtime_options.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/notification_route_resolver.dart';

@pragma('vm:entry-point')
Future<void> schoolDeskFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await PushNotificationService.ensureFirebaseInitialized();
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const _pendingPayloadKey = 'schooldesk.pending_notification_payload';
  static const _firebaseOperationTimeout = Duration(seconds: 4);
  static const _deviceRegistrationTimeout = Duration(seconds: 5);
  static const _androidChannel = AndroidNotificationChannel(
    'schooldesk_updates',
    'SchoolDesk updates',
    description: 'Important SchoolDesk alerts, messages, and reminders.',
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
  String? _currentToken;

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
    } catch (_) {
      return false;
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    FirebaseMessaging.onBackgroundMessage(
      schoolDeskFirebaseMessagingBackgroundHandler,
    );
    _firebaseAvailable = await ensureFirebaseInitialized();
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
    if (!_firebaseAvailable || !BackendApiClient.instance.isAuthenticated) {
      return;
    }
    if (_currentToken == null || _currentToken!.isEmpty) {
      await _refreshToken();
    }
    final token = _currentToken;
    if (token == null || token.isEmpty) return;

    try {
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
    } catch (_) {
      // Push registration is best-effort and should never block app startup/login.
    }
  }

  Future<void> revokeCurrentToken() async {
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
      _openPayload(payload);
    }
  }

  Future<void> _requestPermissionAtStartup() async {
    final messaging = _messaging;
    if (messaging == null) return;
    try {
      await messaging
          .requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          )
          .timeout(_firebaseOperationTimeout);
      if (!kIsWeb) {
        await messaging
            .setForegroundNotificationPresentationOptions(
              alert: true,
              badge: true,
              sound: true,
            )
            .timeout(_firebaseOperationTimeout);
      }
    } catch (_) {
      // Keep the app usable if the platform cannot show a permission prompt.
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
      _localNotificationsReady = true;
    } catch (_) {
      _localNotificationsReady = false;
    }
  }

  Future<void> _refreshToken() async {
    final messaging = _messaging;
    if (messaging == null) return;
    try {
      _currentToken = await messaging
          .getToken(
            vapidKey: kIsWeb && EnvConfig.firebaseVapidKey.isNotEmpty
                ? EnvConfig.firebaseVapidKey
                : null,
          )
          .timeout(_firebaseOperationTimeout);
    } catch (_) {
      _currentToken = null;
    }
  }

  Future<void> _handleForeground(RemoteMessage message) async {
    if (!_localNotificationsReady) return;
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'SchoolDesk';
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
    _openPayload(data);
  }

  void _openLogin() {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushNamedAndRemoveUntil(AppRoutes.landingPage, (_) => false);
  }

  void _openPayload(Map<String, dynamic> data) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPayload(data));
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

  Future<void> dispose() async {
    await _onMessageSub?.cancel();
    await _onOpenedSub?.cancel();
    await _onTokenRefreshSub?.cancel();
  }
}
