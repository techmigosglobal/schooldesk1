import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';

class ErrorReportingService {
  ErrorReportingService._();

  static final ErrorReportingService instance = ErrorReportingService._();

  bool _initialized = false;
  // Queue-based delivery: errors are never dropped while a send is in-flight.
  // Each payload is enqueued and a single flush loop drains the queue serially.
  final Queue<Map<String, dynamic>> _pendingReports = Queue();
  bool _flushing = false;
  static const String monitoringEndpoint = '/monitoring/error-events';

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    BackendApiClient.apiErrorReporter = (error) {
      unawaited(recordApiError(error));
    };
  }

  Future<void> recordFlutterError(FlutterErrorDetails details) {
    return _submit({
      'source': 'flutter',
      'severity': 'fatal',
      'message': details.exceptionAsString(),
      'error_type': details.exception.runtimeType.toString(),
      'stack_trace': details.stack?.toString() ?? '',
      'metadata': {
        'library': details.library,
        'context': details.context?.toDescription(),
      },
    });
  }

  Future<void> recordPlatformError(Object error, StackTrace stack) {
    return _submit({
      'source': 'flutter',
      'severity': 'fatal',
      'message': error.toString(),
      'error_type': error.runtimeType.toString(),
      'stack_trace': stack.toString(),
    });
  }

  Future<void> recordApiError(DioException error) {
    final path = error.requestOptions.path;
    if (path.contains('/monitoring/error-events')) {
      return Future.value();
    }
    return _submit({
      'source': 'api',
      'severity': error.response?.statusCode == null ? 'warning' : 'error',
      'message': _messageForApiError(error),
      'error_type': error.type.name,
      'status_code': error.response?.statusCode ?? 0,
      'method': error.requestOptions.method,
      'path': path,
      'request_id': _responseHeader(error, 'x-request-id'),
      'metadata': {
        'response_error_id': _responseHeader(error, 'x-error-id'),
        'query_keys': error.requestOptions.queryParameters.keys.toList(),
      },
    });
  }

  Future<void> _submit(Map<String, dynamic> payload) async {
    _pendingReports.add(payload);
    if (!_flushing) {
      unawaited(_flush());
    }
  }

  Future<void> _flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      while (_pendingReports.isNotEmpty) {
        if (!BackendApiClient.instance.isAuthenticated) break;
        final payload = _pendingReports.removeFirst();
        try {
          final enriched = {
            ...payload,
            'route_name': PlatformDispatcher.instance.defaultRouteName,
            'app_version': 'schooldesk-flutter',
            'device_info': defaultTargetPlatform.name,
            'occurred_at': DateTime.now().toUtc().toIso8601String(),
            'metadata': {
              ...Map<String, dynamic>.from(payload['metadata'] as Map? ?? {}),
              'role': BackendApiClient.instance.currentRoleName,
              'debug_mode': kDebugMode,
            },
          };
          await BackendApiClient.instance.submitErrorEvent(enriched);
        } on Object catch (_) {
          // Reporting must never break the user flow or recurse into itself.
        }
      }
    } finally {
      _flushing = false;
    }
  }

  String _messageForApiError(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message']?.toString().trim();
      if (message != null && message.isNotEmpty) return message;
      final nested = data['error'];
      if (nested is String && nested.trim().isNotEmpty) return nested.trim();
    }
    return error.message ?? 'API request failed';
  }

  String _responseHeader(DioException error, String name) {
    final values = error.response?.headers[name];
    if (values == null || values.isEmpty) return '';
    return values.first;
  }
}
