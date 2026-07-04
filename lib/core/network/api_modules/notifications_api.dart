part of '../backend_api_client.dart';

extension NotificationsApi on BackendApiClient {
  /// Register device FCM push token with backend
  Future<void> registerPushToken(String token) async {
    try {
      await _dio.post(
        '/notifications/register-token',
        data: {
          'fcm_token': token,
          'device_type': _getDeviceType(),
        },
      );
      if (EnvConfig.enableLogging) {
        developer.log(
          'Push token registered successfully',
          name: 'NotificationsApi',
        );
      }
    } on DioException catch (e) {
      if (EnvConfig.enableLogging) {
        developer.log(
          'Failed to register push token: $e',
          name: 'NotificationsApi',
          error: e,
        );
      }
      throw _handleError(e);
    }
  }

  /// Get notification preferences for current user
  Future<Map<String, dynamic>> getNotificationPreferences() async {
    try {
      final response = await _dio.get('/notifications/preferences');
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data'] ?? {});
      }
      return {};
    } on DioException catch (e) {
      if (EnvConfig.enableLogging) {
        developer.log(
          'Failed to get notification preferences: $e',
          name: 'NotificationsApi',
          error: e,
        );
      }
      throw _handleError(e);
    }
  }

  /// Update notification preferences
  Future<void> updateNotificationPreferences(
    Map<String, dynamic> preferences,
  ) async {
    try {
      await _dio.put(
        '/notifications/preferences',
        data: preferences,
      );
      if (EnvConfig.enableLogging) {
        developer.log(
          'Notification preferences updated',
          name: 'NotificationsApi',
        );
      }
    } on DioException catch (e) {
      if (EnvConfig.enableLogging) {
        developer.log(
          'Failed to update notification preferences: $e',
          name: 'NotificationsApi',
          error: e,
        );
      }
      throw _handleError(e);
    }
  }

  /// Subscribe to specific notification topic/channel
  Future<void> subscribeToChannel(String channelId) async {
    try {
      await _dio.post(
        '/notifications/subscribe',
        data: {'channel_id': channelId},
      );
      if (EnvConfig.enableLogging) {
        developer.log(
          'Subscribed to channel: $channelId',
          name: 'NotificationsApi',
        );
      }
    } on DioException catch (e) {
      if (EnvConfig.enableLogging) {
        developer.log(
          'Failed to subscribe to channel: $e',
          name: 'NotificationsApi',
          error: e,
        );
      }
      throw _handleError(e);
    }
  }

  /// Unsubscribe from notification channel
  Future<void> unsubscribeFromChannel(String channelId) async {
    try {
      await _dio.post(
        '/notifications/unsubscribe',
        data: {'channel_id': channelId},
      );
      if (EnvConfig.enableLogging) {
        developer.log(
          'Unsubscribed from channel: $channelId',
          name: 'NotificationsApi',
        );
      }
    } on DioException catch (e) {
      if (EnvConfig.enableLogging) {
        developer.log(
          'Failed to unsubscribe from channel: $e',
          name: 'NotificationsApi',
          error: e,
        );
      }
      throw _handleError(e);
    }
  }

  String _getDeviceType() {
    if (_dio.httpClientAdapter.toString().contains('SocketHttpClientAdapter')) {
      return 'android';
    }
    return 'ios';
  }
}
