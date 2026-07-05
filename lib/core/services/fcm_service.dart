import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';

/// Handles Firebase Cloud Messaging (FCM) for push notifications
class FcmService {
  static final FcmService _instance = FcmService._internal();

  factory FcmService() {
    return _instance;
  }

  FcmService._internal();

  late FirebaseMessaging _firebaseMessaging;
  late FlutterLocalNotificationsPlugin _localNotifications;
  final StreamController<Map<String, dynamic>> _notificationStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationStreamController.stream;

  bool _initialized = false;

  /// Initialize FCM service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _firebaseMessaging = FirebaseMessaging.instance;
      _localNotifications = FlutterLocalNotificationsPlugin();

      // Request notification permissions
      await _requestPermissions();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Set up message handlers
      _setupMessageHandlers();

      // Get and register device token
      await _registerDeviceToken();

      // Subscribe to school topics
      await _subscribeToSchoolTopics();

      _initialized = true;

      if (EnvConfig.enableLogging) {
        developer.log(
          'FcmService initialized successfully',
          name: 'FcmService',
        );
      }
    } catch (error) {
      if (EnvConfig.enableLogging) {
        developer.log(
          'Failed to initialize FcmService: $error',
          name: 'FcmService',
          error: error,
        );
      }
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        provisional: false,
        sound: true,
      );

      if (EnvConfig.enableLogging) {
        developer.log(
          'Notification permission: ${settings.authorizationStatus}',
          name: 'FcmService',
        );
      }
    } catch (error) {
      if (EnvConfig.enableLogging) {
        developer.log(
          'Permission request error: $error',
          name: 'FcmService',
          error: error,
        );
      }
    }
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    try {
      const androidSettings = AndroidInitializationSettings('ic_launcher');

      final iosSettings = DarwinInitializationSettings(
        defaultPresentAlert: true,
        defaultPresentBadge: true,
        defaultPresentSound: true,
      );

      final settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _handleNotificationTap,
      );

      // Create notification channel for Android
      if (Platform.isAndroid) {
        await _createAndroidNotificationChannel();
      }
    } catch (error) {
      if (EnvConfig.enableLogging) {
        developer.log(
          'Local notifications init error: $error',
          name: 'FcmService',
          error: error,
        );
      }
    }
  }

  /// Create Android notification channel
  Future<void> _createAndroidNotificationChannel() async {
    try {
      const channel = AndroidNotificationChannel(
        'schooldesk_high_priority',
        'High Priority Notifications',
        description: 'Urgent notifications from SchoolDesk',
        importance: Importance.high,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    } catch (error) {
      if (EnvConfig.enableLogging) {
        developer.log(
          'Notification channel creation error: $error',
          name: 'FcmService',
          error: error,
        );
      }
    }
  }

  /// Set up message handlers
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleForegroundMessage(message);
    });

    // Handle message taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessageOpened(message);
    });

    // Listen to token refresh
    _firebaseMessaging.onTokenRefresh.listen(_handleTokenRefresh);
  }

  /// Handle messages received in foreground
  void _handleForegroundMessage(RemoteMessage message) {
    if (EnvConfig.enableLogging) {
      developer.log(
        'Foreground message: ${message.notification?.title}',
        name: 'FcmService',
      );
    }

    // Emit to stream
    _notificationStreamController.add({
      'title': message.notification?.title ?? 'SchoolDesk',
      'body': message.notification?.body ?? '',
      'data': message.data,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Show local notification
    _showLocalNotification(message);
  }

  /// Handle message opened from background/terminated
  void _handleMessageOpened(RemoteMessage message) {
    if (EnvConfig.enableLogging) {
      developer.log(
        'Message opened: ${message.notification?.title}',
        name: 'FcmService',
      );
    }

    // Emit to stream
    _notificationStreamController.add({
      'title': message.notification?.title ?? 'SchoolDesk',
      'body': message.notification?.body ?? '',
      'data': message.data,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Handle token refresh
  void _handleTokenRefresh(String token) {
    if (EnvConfig.enableLogging) {
      developer.log(
        'FCM token refreshed: ${token.substring(0, 20)}...',
        name: 'FcmService',
      );
    }

    // Register new token with backend
    _registerTokenWithBackend(token);
  }

  /// Handle notification tap
  void _handleNotificationTap(NotificationResponse response) {
    if (EnvConfig.enableLogging) {
      developer.log('Notification tapped: ${response.id}', name: 'FcmService');
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'schooldesk_high_priority',
        'High Priority Notifications',
        channelDescription: 'Urgent notifications from SchoolDesk',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch.toUnsigned(31),
        title: message.notification?.title ?? 'SchoolDesk',
        body: message.notification?.body ?? '',
        notificationDetails: details,
        payload: message.messageId,
      );
    } catch (error) {
      if (EnvConfig.enableLogging) {
        developer.log(
          'Error showing notification: $error',
          name: 'FcmService',
          error: error,
        );
      }
    }
  }

  /// Get device FCM token
  Future<String?> getDeviceToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (EnvConfig.enableLogging) {
        developer.log('Device FCM token obtained', name: 'FcmService');
      }
      return token;
    } catch (error) {
      if (EnvConfig.enableLogging) {
        developer.log(
          'Error getting FCM token: $error',
          name: 'FcmService',
          error: error,
        );
      }
      return null;
    }
  }

  /// Register device token with backend
  Future<void> _registerDeviceToken() async {
    try {
      final token = await getDeviceToken();
      if (token != null) {
        await _registerTokenWithBackend(token);
      }
    } catch (error) {
      if (EnvConfig.enableLogging) {
        developer.log(
          'Error registering device token: $error',
          name: 'FcmService',
          error: error,
        );
      }
    }
  }

  /// Register token with backend
  Future<void> _registerTokenWithBackend(String token) async {
    try {
      await BackendApiClient.instance.registerPushToken(token);
      if (EnvConfig.enableLogging) {
        developer.log('Push token registered with backend', name: 'FcmService');
      }
    } catch (error) {
      if (EnvConfig.enableLogging) {
        developer.log(
          'Error registering token with backend: $error',
          name: 'FcmService',
          error: error,
        );
      }
    }
  }

  /// Subscribe to school-level topics
  Future<void> _subscribeToSchoolTopics() async {
    try {
      // Subscribe to general school topic
      await _firebaseMessaging.subscribeToTopic('school_announcements');

      // Subscribe to user role topic
      final userRole = await _getUserRole();
      if (userRole != null) {
        await _firebaseMessaging.subscribeToTopic('role_$userRole');
      }

      if (EnvConfig.enableLogging) {
        developer.log('Subscribed to school topics', name: 'FcmService');
      }
    } catch (error) {
      if (EnvConfig.enableLogging) {
        developer.log(
          'Error subscribing to topics: $error',
          name: 'FcmService',
          error: error,
        );
      }
    }
  }

  /// Get current user role
  Future<String?> _getUserRole() async {
    try {
      // This would get the current user's role from your auth/state management
      // For now, return null - implement based on your app structure
      return null;
    } catch (error) {
      return null;
    }
  }

  /// Subscribe to specific topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      final messaging = _initialized
          ? _firebaseMessaging
          : FirebaseMessaging.instance;
      await messaging.subscribeToTopic(topic);
      if (EnvConfig.enableLogging) {
        developer.log('Subscribed to topic: $topic', name: 'FcmService');
      }
    } catch (error) {
      if (EnvConfig.enableLogging) {
        developer.log(
          'Error subscribing to $topic: $error',
          name: 'FcmService',
          error: error,
        );
      }
    }
  }

  /// Unsubscribe from specific topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      final messaging = _initialized
          ? _firebaseMessaging
          : FirebaseMessaging.instance;
      await messaging.unsubscribeFromTopic(topic);
      if (EnvConfig.enableLogging) {
        developer.log('Unsubscribed from topic: $topic', name: 'FcmService');
      }
    } catch (error) {
      if (EnvConfig.enableLogging) {
        developer.log(
          'Error unsubscribing from $topic: $error',
          name: 'FcmService',
          error: error,
        );
      }
    }
  }

  /// Cleanup resources
  void dispose() {
    _notificationStreamController.close();
  }
}
