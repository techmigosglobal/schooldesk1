import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:schooldesk1/core/offline/offline_sync_engine.dart';

/// Small, global status surface so screens can remain data-source agnostic.
class OfflineStatusBanner extends StatelessWidget {
  const OfflineStatusBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineSyncEngine>(
      builder: (context, sync, _) {
        if (!sync.api.isAuthenticated ||
            (sync.state == OfflineConnectionState.unknown &&
                sync.pendingMutationCount == 0) ||
            (sync.state == OfflineConnectionState.online &&
                sync.pendingMutationCount == 0)) {
          return child;
        }

        final isSyncing = sync.state == OfflineConnectionState.syncing;
        final hasError = sync.lastError != null && !isSyncing;
        final color = hasError
            ? Colors.deepOrange.shade700
            : isSyncing
            ? Colors.indigo.shade700
            : Colors.blueGrey.shade800;
        final message = hasError
            ? 'Sync paused — ${sync.pendingMutationCount} change(s) need attention'
            : isSyncing
            ? 'Syncing ${sync.pendingMutationCount} pending change(s)…'
            : sync.state == OfflineConnectionState.offline
            ? 'Offline — showing cached data${sync.pendingMutationCount == 0 ? '' : ' · ${sync.pendingMutationCount} queued'}'
            : '${sync.pendingMutationCount} change(s) waiting to sync';

        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Material(
                  color: color,
                  elevation: 3,
                  child: Semantics(
                    liveRegion: true,
                    label: message,
                    child: SizedBox(
                      height: 32,
                      child: Row(
                        children: [
                          Expanded(
                            child: Center(
                              child: Text(
                                message,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          if (!isSyncing)
                            Semantics(
                              button: true,
                              label: 'Retry sync',
                              child: IconButton(
                                onPressed: () => unawaited(sync.syncNow()),
                                icon: const Icon(
                                  Icons.refresh,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                tooltip: 'Retry sync',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 32,
                                  height: 32,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
