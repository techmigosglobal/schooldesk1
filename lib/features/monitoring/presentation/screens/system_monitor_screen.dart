import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/desktop/desktop_responsive_breakpoints.dart';
import 'package:schooldesk1/core/widgets/desktop_screen_wrapper.dart';

class SystemMonitorScreen extends StatefulWidget {
  const SystemMonitorScreen({super.key});

  @override
  State<SystemMonitorScreen> createState() => _SystemMonitorScreenState();
}

class _SystemMonitorScreenState extends State<SystemMonitorScreen> {
  final _api = BackendApiClient.instance;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  String _status = 'open';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _events = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _api.getErrorEvents(
        status: _status == 'all' ? null : _status,
        pageSize: 50,
      );
      final data = response['data'];
      setState(() {
        _events = data is List
            ? data
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
            : const [];
      });
    } on Object catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _backupDb() async {
    setState(() => _loading = true);
    try {
      final data = await _api.backupDatabase();
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
      if (mounted) setState(() => _loading = false);
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

    setState(() => _loading = true);
    try {
      final Map<String, dynamic> parsed = Map<String, dynamic>.from(
        jsonDecode(controller.text.trim()) as Map,
      );
      await _api.restoreDatabase(parsed);
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
      if (mounted) setState(() => _loading = false);
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
            child: const Text('Delete Everything Except Principal & Super Admin'),
          ),
        ],
      ),
    );

    if (wipeConfirmed != true) return;

    setState(() => _loading = true);
    try {
      final result = await _api.wipeDatabase();
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
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {


  final isDesktop = DesktopBreakpoints.isDesktopWidth(


        MediaQuery.sizeOf(context).width,


      );


      if (isDesktop) {


        return DesktopScreenWrapper(


          breadcrumbs: ['Monitoring', 'System'],


          title: 'System Monitor',


          actions: const [],


          child: Card(


            elevation: 0,


            child: Padding(


              padding: const EdgeInsets.all(32),


              child: Center(


                child: Column(


                  mainAxisSize: MainAxisSize.min,


                  children: [


                    Icon(Icons.desktop_windows_rounded, size: 48, color: Theme.of(context).colorScheme.primary),


                    const SizedBox(height: 16),


                    Text('System Monitor', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),


                    const SizedBox(height: 8),


                    Text('Desktop view coming soon', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5))),


                  ],


                ),


              ),


            ),


          ),


        );


      }

    final role = _api.currentRoleName?.trim().toLowerCase() ?? '';
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
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildFilters(),
            const SizedBox(height: 16),
            if (isSuperAdmin) ...[
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
                          const Icon(Icons.storage_rounded, color: Colors.blue),
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                            onPressed: _loading ? null : _backupDb,
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.upload_rounded),
                            label: const Text('Restore DB'),
                            onPressed: _loading ? null : _restoreDb,
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                            ),
                            icon: const Icon(Icons.delete_forever_rounded),
                            label: const Text('Wipe School Data'),
                            onPressed: _loading ? null : _wipeDb,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_error != null)
              _MessagePanel(
                icon: Icons.error_outline_rounded,
                title: 'Unable to load events',
                message: _error!,
              )
            else if (_events.isEmpty)
              const _MessagePanel(
                icon: Icons.check_circle_outline_rounded,
                title: 'No matching error events',
                message: 'New crashes and backend errors will appear here.',
              )
            else
              for (final event in _events)
                _ErrorEventTile(
                  event: event,
                  onOpen: () => _showDetails(event),
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
          if (_text(event['status'], fallback: 'open') != 'resolved')
            FilledButton.icon(
              icon: const Icon(Icons.task_alt_rounded),
              label: const Text('Resolve'),
              onPressed: () async {
                await _api.resolveErrorEvent(
                  _text(
                    event['id'],
                    fallback: _text(event['error_id'], fallback: ''),
                  ),
                  resolutionNote: 'Reviewed by Principal',
                );
                if (!mounted) return;
                Navigator.pop(context);
                _load();
              },
            ),
        ],
      ),
    );
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
            '$occurred\nError: ${_text(event['error_id'], fallback: '-')} · Request: ${_text(event['request_id'], fallback: '-')}',
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
