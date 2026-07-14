import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/desktop/desktop_responsive_breakpoints.dart';
import 'package:schooldesk1/core/widgets/desktop_screen_wrapper.dart';

class PrincipalAuditLogsScreen extends StatefulWidget {
  const PrincipalAuditLogsScreen({super.key});

  @override
  State<PrincipalAuditLogsScreen> createState() =>
      _PrincipalAuditLogsScreenState();
}

class _PrincipalAuditLogsScreenState extends State<PrincipalAuditLogsScreen> {
  final _userController = TextEditingController();
  String _module = '';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _logs = const [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _userController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final logs = await BackendApiClient.instance.getRawList(
        '/audit-logs',
        queryParameters: {
          'page_size': 50,
          if (_module.isNotEmpty) 'module': _module,
          if (_userController.text.trim().isNotEmpty)
            'user_id': _userController.text.trim(),
        },
      );
      if (!mounted) return;
      setState(() => _logs = logs);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
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


          breadcrumbs: ['Monitoring', 'Audit Logs'],


          title: 'Audit Logs',


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


                    Text('Audit Logs', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),


                    const SizedBox(height: 8),


                    Text('Desktop view coming soon', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5))),


                  ],


                ),


              ),


            ),


          ),


        );


      }

    return SchoolDeskModuleScaffold(
      title: 'Audit Logs',
      subtitle: 'Recent principal-visible system activity',
      drawer: PrincipalDrawer(
        selectedIndex: PrincipalNav.dashboard,
        onDestinationSelected: (_) {},
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadLogs,
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _loadLogs,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildFilters(),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              _StateCard(
                icon: Icons.error_outline_rounded,
                title: 'Unable to load audit logs',
                message: _error!,
              )
            else if (_logs.isEmpty)
              const _StateCard(
                icon: Icons.history_rounded,
                title: 'No audit logs found',
                message: 'Try another module or user filter.',
              )
            else
              ..._logs.map(_AuditLogTile.new),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Wrap(
      runSpacing: 12,
      spacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String>(
            initialValue: _module,
            decoration: const InputDecoration(labelText: 'Module'),
            items: const [
              DropdownMenuItem(value: '', child: Text('All modules')),
              DropdownMenuItem(value: 'auth', child: Text('Auth')),
              DropdownMenuItem(value: 'users', child: Text('Users')),
              DropdownMenuItem(value: 'students', child: Text('Students')),
              DropdownMenuItem(value: 'staff', child: Text('Staff')),
              DropdownMenuItem(value: 'homework', child: Text('Homework')),
              DropdownMenuItem(value: 'fees', child: Text('Fees')),
            ],
            onChanged: (value) {
              setState(() => _module = value ?? '');
              _loadLogs();
            },
          ),
        ),
        SizedBox(
          width: 260,
          child: TextField(
            controller: _userController,
            decoration: const InputDecoration(
              labelText: 'User ID',
              suffixIcon: Icon(Icons.person_search_rounded),
            ),
            onSubmitted: (_) => _loadLogs(),
          ),
        ),
        FilledButton.icon(
          onPressed: _loadLogs,
          icon: const Icon(Icons.filter_alt_rounded),
          label: const Text('Apply'),
        ),
      ],
    );
  }
}

class _AuditLogTile extends StatelessWidget {
  final Map<String, dynamic> log;

  const _AuditLogTile(this.log);

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.tryParse('${log['created_at'] ?? ''}');
    final when = createdAt == null
        ? ''
        : DateFormat('d MMM yyyy, h:mm a').format(createdAt.toLocal());
    return Card(
      child: ListTile(
        leading: const Icon(Icons.history_rounded),
        title: Text('${log['action'] ?? 'activity'} ${log['module'] ?? ''}'),
        subtitle: Text(
          [
            if ('${log['role'] ?? ''}'.isNotEmpty) 'Role: ${log['role']}',
            if ('${log['entity_type'] ?? ''}'.isNotEmpty)
              'Entity: ${log['entity_type']}',
            if ('${log['ip_address'] ?? ''}'.isNotEmpty)
              'IP: ${log['ip_address']}',
          ].join(' - '),
        ),
        trailing: Text(when, textAlign: TextAlign.end),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 42),
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
