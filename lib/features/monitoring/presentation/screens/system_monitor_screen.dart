import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';
import 'package:schooldesk1/modules/monitoring/data/api_system_monitor_repository.dart';
import 'package:schooldesk1/modules/monitoring/domain/system_monitor_repository.dart';

class SystemMonitorScreen extends StatefulWidget {
  final String role;
  final SystemMonitorRepository? repository;

  const SystemMonitorScreen({
    super.key,
    this.role = 'principal',
    this.repository,
  });

  @override
  State<SystemMonitorScreen> createState() => _SystemMonitorScreenState();
}

@immutable
class _SystemMonitorSnapshot {
  const _SystemMonitorSnapshot({
    required this.events,
    required this.retention,
  });

  final List<Map<String, dynamic>> events;
  final Map<String, dynamic> retention;
}

class _SystemMonitorScreenState extends State<SystemMonitorScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  String _status = 'open';
  bool _busy = false;
  RepositoryState<_SystemMonitorSnapshot> _state =
      const RepositoryState.loading();

  Map<String, dynamic> get _retention =>
      _state.data?.retention ?? const <String, dynamic>{};

  SystemMonitorRepository get _repository =>
      widget.repository ?? ApiSystemMonitorRepository.legacyDefault;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final previous = _state.data;
    setState(() {
      _state = RepositoryState.loading(
        data: previous,
        source: previous == null
            ? RepositorySource.empty
            : RepositorySource.cache,
        isStale: previous != null,
        isRefreshing: previous != null,
      );
    });
    try {
      final isSuperAdmin = widget.role.trim().toLowerCase() == 'super_admin';
      final results = await Future.wait([
        _repository.loadErrorEvents(
          status: _status == 'all' ? null : _status,
          pageSize: 50,
        ),
        if (isSuperAdmin) _repository.loadRetentionMetrics(),
      ]);
      final response = results.first;
      final data = response['data'];
      if (!mounted) return;
      final events = data is List
          ? data
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
          : const <Map<String, dynamic>>[];
      final retention = isSuperAdmin && results.length > 1
          ? Map<String, dynamic>.from(results[1] as Map)
          : const <String, dynamic>{};
      setState(() {
        _state = RepositoryState(
          data: _SystemMonitorSnapshot(events: events, retention: retention),
          source: RepositorySource.remote,
          phase: RepositoryPhase.ready,
          lastUpdated: DateTime.now().toUtc(),
        );
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _state = previous == null
            ? RepositoryState.error(error: error)
            : RepositoryState(
                data: previous,
                source: RepositorySource.cache,
                isStale: true,
                error: error,
                lastUpdated: _state.lastUpdated,
              );
      });
    }
  }

  Future<void> _editRetention() async {
    final settings = Map<String, dynamic>.from(
      _retention['settings'] as Map? ?? const {},
    );
    final warning = TextEditingController(
      text: '${settings['warning_keep_days'] ?? 14}',
    );
    final resolved = TextEditingController(
      text: '${settings['resolved_keep_days'] ?? 30}',
    );
    final fatal = TextEditingController(
      text: '${settings['resolved_fatal_keep_days'] ?? 90}',
    );
    final maximum = TextEditingController(
      text: '${settings['max_raw_events'] ?? 10000}',
    );
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error retention limits'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _numberField(warning, 'Warnings/info days', '7–30 days'),
              _numberField(resolved, 'Resolved errors days', '14–180 days'),
              _numberField(fatal, 'Resolved fatal errors days', '30–365 days'),
              _numberField(
                maximum,
                'Maximum raw events',
                '1,000–100,000 per school',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save limits'),
          ),
        ],
      ),
    );
    if (save != true) return;
    try {
      await _repository.updateRetentionSettings(
        warningKeepDays: int.tryParse(warning.text) ?? 0,
        resolvedKeepDays: int.tryParse(resolved.text) ?? 0,
        resolvedFatalKeepDays: int.tryParse(fatal.text) ?? 0,
        maxRawEvents: int.tryParse(maximum.text) ?? 0,
      );
      await _load();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to save limits: $error')));
    }
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
    String helper,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Future<void> _clearResolvedEvents() async {
    final before = DateTime.now().toUtc().subtract(const Duration(days: 30));
    try {
      final preview = await _repository.previewResolvedCleanup(before: before);
      if (!mounted) return;
      final count = preview['deleted_count'] ?? 0;
      final confirm = TextEditingController();
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clear resolved error events'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will permanently remove $count resolved event(s) last seen more than 30 days ago. Open and fatal errors are never included.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirm,
                decoration: const InputDecoration(
                  labelText: 'Type CLEAR RESOLVED ERROR EVENTS',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(
                context,
                confirm.text == 'CLEAR RESOLVED ERROR EVENTS',
              ),
              child: const Text('Clear resolved events'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      final result = await _repository.clearResolvedCleanup(before: before);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result['deleted_count'] ?? 0} resolved error event(s) cleared.',
          ),
        ),
      );
      await _load();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to clear resolved events: $error')),
      );
    }
  }

  Future<void> _backupDb() async {
    setState(() => _busy = true);
    try {
      final data = await _repository.backupDatabase();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      await Clipboard.setData(ClipboardData(text: jsonStr));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Database backup copied to clipboard! Save it as a JSON file.',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      // Show backup dialog so they can copy it manually if needed
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Database Backup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('The backup JSON has been copied to your clipboard.'),
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                child: SingleChildScrollView(
                  child: SelectableText(
                    jsonStr,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on Object catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup failed: $err'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreDb() async {
    final controller = TextEditingController();
    final restoreConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Database'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Paste the JSON backup string below:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 8,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '{\n  "students": [...]\n}',
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (restoreConfirmed != true || controller.text.trim().isEmpty) return;

    setState(() => _busy = true);
    try {
      final Map<String, dynamic> parsed = Map<String, dynamic>.from(
        jsonDecode(controller.text.trim()) as Map,
      );
      await _repository.restoreDatabase(parsed);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Database restored successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _load();
    } on Object catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restore failed: $err'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _wipeDb() async {
    final wipeConfirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wipe All School Data'),
        content: const Text(
          'This permanently deletes every school record: people, login accounts, academics, attendance, fees, communications, settings, reports, notifications, documents, audit history, and uploaded files.\n\n'
          'Only the school profile/branding and Principal and Super Admin login accounts are preserved.\n\n'
          'THIS ACTION CANNOT BE UNDONE!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete Everything Except Principal & Super Admin',
            ),
          ),
        ],
      ),
    );

    if (wipeConfirmed != true) return;

    setState(() => _busy = true);
    try {
      final result = await _repository.wipeDatabase();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'School reset: ${result['deleted_rows'] ?? 0} records, '
            '${result['storage_objects_removed'] ?? 0} files, and '
            '${result['auth_accounts_deleted'] ?? 0} login accounts removed. '
            'Principal and Super Admin accounts remain.',
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _load();
    } on Object catch (err) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Wipe failed: $err'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.role.trim().toLowerCase();
    final isSuperAdmin = role == 'super_admin';

    return Scaffold(
      key: _scaffoldKey,
      drawer: isSuperAdmin
          ? SuperAdminDrawer(
              selectedIndex: SuperAdminNav.systemMonitor,
              onDestinationSelected: (_) {},
            )
          : PrincipalDrawer(
              selectedIndex: PrincipalNav.dashboard,
              onDestinationSelected: (_) {},
            ),
      bottomNavigationBar: isSuperAdmin
          ? const SuperAdminShellBottomBar()
          : const PrincipalShellBottomBar(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('System Monitor'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: SchoolDeskRepositoryStateView<_SystemMonitorSnapshot>(
        state: _state,
        onRetry: _load,
        emptyTitle: 'No monitor data',
        emptyMessage: 'Monitoring data is not available for this scope.',
        data: (snapshot) => RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildFilters(),
              const SizedBox(height: 16),
              if (isSuperAdmin) ...[
                _buildRetentionCard(),
                const SizedBox(height: 16),
                Card(
                  color: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.storage_rounded,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Database Administration',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Perform backups, restorations, or clear transaction/student records for this school.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.download_rounded),
                              label: const Text('Backup DB'),
                              onPressed: _busy ? null : _backupDb,
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.upload_rounded),
                              label: const Text('Restore DB'),
                              onPressed: _busy ? null : _restoreDb,
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                              ),
                              icon: const Icon(Icons.delete_forever_rounded),
                              label: const Text('Wipe School Data'),
                              onPressed: _busy ? null : _wipeDb,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (snapshot.events.isEmpty)
                const _MessagePanel(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'No matching error events',
                  message: 'New crashes and backend errors will appear here.',
                )
              else
                for (final event in snapshot.events)
                  _ErrorEventTile(
                    event: event,
                    onOpen: () => _showDetails(event),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRetentionCard() {
    final settings = Map<String, dynamic>.from(
      _retention['settings'] as Map? ?? const {},
    );
    final total = _retention['total_events'] ?? 0;
    final open = _retention['open_events'] ?? 0;
    final eligible = _retention['cleanup_eligible'] ?? 0;
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.monitor_heart_outlined,
                  color: Colors.deepPurple,
                ),
                const SizedBox(width: 8),
                Text(
                  'Error retention',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$total raw events · $open open · ${_formatBytes(_retention['storage_bytes'])} used',
            ),
            const SizedBox(height: 4),
            Text(
              'Warnings ${settings['warning_keep_days'] ?? 14}d · resolved ${settings['resolved_keep_days'] ?? 30}d · fatal ${settings['resolved_fatal_keep_days'] ?? 90}d · max ${settings['max_raw_events'] ?? 10000}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _editRetention,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Configure limits'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy || eligible == 0
                      ? null
                      : _clearResolvedEvents,
                  icon: const Icon(Icons.cleaning_services_outlined),
                  label: Text('Clear eligible ($eligible)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'open',
          icon: Icon(Icons.report_problem_outlined),
          label: Text('Open'),
        ),
        ButtonSegment(
          value: 'resolved',
          icon: Icon(Icons.task_alt_rounded),
          label: Text('Resolved'),
        ),
        ButtonSegment(
          value: 'all',
          icon: Icon(Icons.list_alt_rounded),
          label: Text('All'),
        ),
      ],
      selected: {_status},
      onSelectionChanged: (selection) {
        setState(() => _status = selection.first);
        _load();
      },
    );
  }

  Future<void> _showDetails(Map<String, dynamic> event) async {
    final isSuperAdmin = widget.role.trim().toLowerCase() == 'super_admin';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_text(event['message'], fallback: 'Error event')),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detail('Error ID', event['error_id']),
                _detail('Request ID', event['request_id']),
                _detail('Source', event['source']),
                _detail('Severity', event['severity']),
                _detail('Status', event['status']),
                _detail('Occurrences', event['occurrence_count']),
                _detail('First seen', _localTime(event['first_seen_at'])),
                _detail('Last seen', _localTime(event['last_seen_at'])),
                _detail('Role', event['role']),
                _detail('Path', event['path']),
                _detail('Occurred', _localTime(event['occurred_at'])),
                _detail('HTTP status', event['status_code']),
                _detail('App version', event['app_version']),
                _detail('Device', event['device_info']),
                _detail('Resolved at', _localTime(event['resolved_at'])),
                _detail('Resolution note', event['resolution_note']),
                const SizedBox(height: 12),
                Text(
                  'Stack trace',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  _text(event['stack_trace'], fallback: 'No stack trace'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (isSuperAdmin &&
              _text(event['status'], fallback: 'open') != 'resolved')
            FilledButton.icon(
              icon: const Icon(Icons.task_alt_rounded),
              label: const Text('Resolve'),
              onPressed: () async {
                await _repository.resolveErrorEvent(
                  _text(
                    event['id'],
                    fallback: _text(event['error_id'], fallback: ''),
                  ),
                  resolutionNote: 'Reviewed by Super Admin',
                );
                if (!mounted) return;
                Navigator.pop(context);
                _load();
              },
            ),
          if (isSuperAdmin &&
              _text(event['status'], fallback: 'open') == 'resolved')
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete'),
              onPressed: () => _confirmDeleteResolvedEvent(event),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteResolvedEvent(Map<String, dynamic> event) async {
    final id = _text(event['id'], fallback: '');
    if (id.isEmpty) return;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete resolved error event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently removes this resolved event. Open and fatal events cannot be deleted from this action.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Type DELETE RESOLVED ERROR EVENT',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(
              context,
              controller.text == 'DELETE RESOLVED ERROR EVENT',
            ),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repository.deleteResolvedErrorEvent(id);
      if (!mounted) return;
      Navigator.pop(context);
      await _load();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete error event: $error')),
      );
    }
  }

  Widget _detail(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SelectableText('$label: ${_text(value, fallback: '-')}'),
    );
  }
}

class _ErrorEventTile extends StatelessWidget {
  const _ErrorEventTile({required this.event, required this.onOpen});

  final Map<String, dynamic> event;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final status = _text(event['status'], fallback: 'open');
    final severity = _text(event['severity'], fallback: 'error');
    final occurred = _localTime(event['occurred_at']);
    final location = _text(
      event['screen'],
      fallback: _text(event['path'], fallback: 'Unknown location'),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          status == 'resolved'
              ? Icons.task_alt_rounded
              : Icons.report_problem_outlined,
          color: status == 'resolved'
              ? Colors.green.shade700
              : Theme.of(context).colorScheme.error,
        ),
        title: Text(
          _text(event['message'], fallback: 'Error event'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${severity.toUpperCase()} · ${status.toUpperCase()}\n'
            '${_text(event['source'], fallback: 'unknown')} · $location\n'
            '$occurred · ${_text(event['occurrence_count'], fallback: '1')} occurrence(s)\nError: ${_text(event['error_id'], fallback: '-')} · Request: ${_text(event['request_id'], fallback: '-')}',
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onOpen,
      ),
    );
  }
}

String _localTime(dynamic value) {
  final parsed = DateTime.tryParse('${value ?? ''}');
  if (parsed == null) return _text(value, fallback: '-');
  return DateFormat('d MMM yyyy, h:mm:ss a').format(parsed.toLocal());
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

String _text(dynamic value, {required String fallback}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _formatBytes(dynamic value) {
  final bytes = value is num
      ? value.toDouble()
      : double.tryParse('${value ?? ''}') ?? 0;
  if (bytes < 1024) return '${bytes.round()} B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
