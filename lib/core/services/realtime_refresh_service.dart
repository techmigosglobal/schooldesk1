import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/token_storage_service.dart';

/// Receives only invalidation rows, then lets the caller reload through its
/// existing authorized API. This intentionally never subscribes to raw
/// attendance, fee, child, or payment tables.
class RealtimeRefreshService {
  RealtimeRefreshService._();

  static final RealtimeRefreshService instance = RealtimeRefreshService._();

  RealtimeRefreshSubscription subscribe({
    required String channelName,
    required Set<String> modules,
    required VoidCallback onRefresh,
    Duration debounce = const Duration(milliseconds: 800),
  }) {
    final schoolId = BackendApiClient.instance.activeBranchId?.trim() ?? '';
    final userId = BackendApiClient.instance.currentUserId?.trim() ?? '';
    if (schoolId.isEmpty && userId.isEmpty) {
      return const RealtimeRefreshSubscription.empty();
    }

    late final SupabaseClient client;
    try {
      client = Supabase.instance.client;
    } on AssertionError {
      // Widgets can be rendered before Supabase initialization (offline mode,
      // tests, or failed startup initialization). Realtime is optional and
      // must not prevent the underlying screen from rendering.
      return const RealtimeRefreshSubscription.empty();
    }
    unawaited(
      TokenStorageService.getAccessToken().then((token) {
        if (token != null && token.isNotEmpty) client.realtime.setAuth(token);
      }),
    );

    DateTime? lastRefresh;
    void maybeRefresh(PostgresChangePayload payload) {
      final row = payload.newRecord.isNotEmpty
          ? payload.newRecord
          : payload.oldRecord;
      final module = '${row['module'] ?? ''}'.trim();
      if (!modules.contains(module)) return;
      final now = DateTime.now();
      if (lastRefresh != null && now.difference(lastRefresh!) < debounce) {
        return;
      }
      lastRefresh = now;
      onRefresh();
    }

    final channels = <RealtimeChannel>[];
    if (schoolId.isNotEmpty) {
      final channel = client.channel('$channelName-school-$schoolId')
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'realtime_invalidation_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'school_id',
            value: schoolId,
          ),
          callback: maybeRefresh,
        )
        ..subscribe();
      channels.add(channel);
    }
    if (userId.isNotEmpty) {
      final channel = client.channel('$channelName-user-$userId')
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'realtime_invalidation_events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_user_id',
            value: userId,
          ),
          callback: maybeRefresh,
        )
        ..subscribe();
      channels.add(channel);
    }
    return RealtimeRefreshSubscription(channels);
  }
}

class RealtimeRefreshSubscription {
  const RealtimeRefreshSubscription(this._channels);
  const RealtimeRefreshSubscription.empty() : _channels = const [];

  final List<RealtimeChannel> _channels;

  void dispose() {
    late final SupabaseClient client;
    try {
      client = Supabase.instance.client;
    } on AssertionError {
      return;
    }
    for (final channel in _channels) {
      unawaited(client.removeChannel(channel));
    }
  }
}
