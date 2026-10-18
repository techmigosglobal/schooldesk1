import 'package:dio/dio.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/modules/communication/domain/notification_broadcast_repository.dart';

/// A recipient selection belongs to one account, school and role. Recreate this
/// adapter after a scope change instead of dispatching that selection elsewhere.
class ApiNotificationBroadcastRepository
    implements NotificationBroadcastRepository {
  ApiNotificationBroadcastRepository(this.api)
    : _boundScope = api.offlineAccountKey;
  final BackendApiClient api;
  final String _boundScope;

  void _checkScope() {
    if (_boundScope == 'anonymous' ||
        api.offlineAccountKey != _boundScope ||
        api.currentRoleName != 'principal' ||
        !api.isAuthenticated) {
      throw StateError('Your school or account changed. Reload recipients.');
    }
  }

  Map<String, dynamic> _data(Object? value) {
    _checkScope();
    final envelope = Map<String, dynamic>.from(value as Map);
    if (envelope['success'] != true) {
      throw StateError('The notification request could not be completed.');
    }
    return Map<String, dynamic>.from(envelope['data'] as Map? ?? {});
  }

  Options _options({String? key}) => Options(
    headers: {
      'Cache-Control': 'no-store',
      if (key != null) 'Idempotency-Key': key,
    },
    extra: {'schooldeskExpectedScope': _boundScope},
  );

  @override
  Future<Map<String, dynamic>> recipients({
    required Set<String> roles,
    String search = '',
    int page = 1,
  }) async {
    _checkScope();
    final response = await api.dio.get<dynamic>(
      '/notifications/recipients',
      queryParameters: {
        'roles': (roles.toList()..sort()).join(','),
        'search': search,
        'page': page,
        'refresh_nonce': DateTime.now().microsecondsSinceEpoch,
      },
      options: _options(),
    );
    return _data(response.data);
  }

  @override
  Future<Map<String, dynamic>> history({int page = 1}) async {
    _checkScope();
    final response = await api.dio.get<dynamic>(
      '/notifications/broadcasts',
      queryParameters: {
        'page': page,
        'refresh_nonce': DateTime.now().microsecondsSinceEpoch,
      },
      options: _options(),
    );
    return _data(response.data);
  }

  @override
  Future<Map<String, dynamic>> send({
    required String key,
    required String title,
    required String message,
    required Set<String> roles,
    required bool all,
    required Set<String> userIds,
  }) async {
    _checkScope();
    final response = await api.dio.post<dynamic>(
      '/notifications/broadcasts',
      data: {
        'title': title,
        'message': message,
        'roles': roles.toList(),
        'mode': all ? 'all' : 'selected',
        'user_ids': all ? <String>[] : userIds.toList(),
      },
      options: _options(key: key),
    );
    return _data(response.data);
  }
}
