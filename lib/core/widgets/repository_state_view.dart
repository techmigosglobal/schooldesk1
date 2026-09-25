import 'package:flutter/material.dart';

import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';

/// Shared state renderer for repository-backed screens.
///
/// It keeps cached data visible during stale refreshes and provides explicit
/// loading, empty, error, offline, stale, and retry affordances.
class SchoolDeskRepositoryStateView<T> extends StatelessWidget {
  const SchoolDeskRepositoryStateView({
    required this.state,
    required this.data,
    required this.onRetry,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage = 'No records are available for this scope.',
    this.errorTitle = 'Unable to load data',
    this.loadingMessage = 'Loading…',
    super.key,
  });

  final RepositoryState<T> state;
  final Widget Function(T value) data;
  final VoidCallback onRetry;
  final String emptyTitle;
  final String emptyMessage;
  final String errorTitle;
  final String loadingMessage;

  @override
  Widget build(BuildContext context) {
    final value = state.data;
    if (value == null && state.isLoading) {
      return SchoolDeskStatusPanel.loading(message: loadingMessage);
    }
    if (value == null && state.isError) {
      return SchoolDeskStatusPanel.error(
        title: errorTitle,
        message: '${state.error}',
        onAction: onRetry,
      );
    }
    if (value == null || state.isEmpty) {
      return SchoolDeskStatusPanel.empty(
        title: emptyTitle,
        message: emptyMessage,
        actionLabel: 'Retry',
        onAction: onRetry,
      );
    }

    final content = data(value);
    if (!state.isOffline && !state.isRefreshing) return content;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.isOffline)
          SchoolDeskStatusPanel.stale(
            title: 'Showing saved data',
            message: state.error == null
                ? 'Backend is unavailable. Cached data remains visible.'
                : 'Refresh failed. Cached data remains visible.',
            onAction: onRetry,
          ),
        content,
      ],
    );
  }
}
