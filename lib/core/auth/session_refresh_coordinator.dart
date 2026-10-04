import 'dart:async';

import 'package:dio/dio.dart';

import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/services/token_storage_service.dart';

/// Owns refresh-token rotation for every HTTP transport in the app.
///
/// The generated Retrofit client and the typed backend client share this
/// coordinator so two simultaneous 401 responses cannot rotate the same
/// refresh token independently.
class SessionRefreshCoordinator {
  SessionRefreshCoordinator._();

  static final SessionRefreshCoordinator instance =
      SessionRefreshCoordinator._();

  Completer<bool>? _inFlight;

  Future<bool> refresh(String baseUrl) async {
    final active = _inFlight;
    if (active != null) return active.future;

    final refreshToken = await TokenStorageService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    final completer = Completer<bool>();
    _inFlight = completer;
    try {
      final response = await Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Accept': 'application/json',
            ...EnvConfig.supabaseGatewayHeaders,
          },
        ),
      ).post('/auth/refresh', data: {'refresh_token': refreshToken});
      final envelope = response.data;
      final payload = envelope is Map && envelope['data'] is Map
          ? Map<String, dynamic>.from(envelope['data'] as Map)
          : null;
      final accessToken = payload?['token']?.toString().trim() ?? '';
      final nextRefresh =
          payload?['refresh_token']?.toString().trim() ?? refreshToken;
      final ok =
          envelope is Map &&
          envelope['success'] == true &&
          accessToken.isNotEmpty &&
          nextRefresh.isNotEmpty;
      if (ok) {
        await TokenStorageService.saveTokens(
          accessToken: accessToken,
          refreshToken: nextRefresh,
        );
      }
      if (!completer.isCompleted) completer.complete(ok);
      return ok;
    } on Object {
      if (!completer.isCompleted) completer.complete(false);
      return false;
    } finally {
      _inFlight = null;
    }
  }
}
