import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';

class PrincipalAuditLogsScreen extends StatefulWidget {
  const PrincipalAuditLogsScreen({super.key});

  @override
  State<PrincipalAuditLogsScreen> createState() =>
      _PrincipalAuditLogsScreenState();
}

class _PrincipalAuditLogsScreenState extends State<PrincipalAuditLogsScreen> {
  final _userController = TextEditingController();
  final _searchController = TextEditingController();
  String _module = '';
  String _actorRole = '';
  String _eventType = '';
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
    _searchController.dispose();
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
            'actor': _userController.text.trim(),
          if (_actorRole.isNotEmpty) 'actor_role': _actorRole,
          if (_eventType.isNotEmpty) 'event_type': _eventType,
          if (_searchController.text.trim().isNotEmpty)
            'search': _searchController.text.trim(),
        },
      );
      if (!mounted) return;
      final isPrincipal =
          BackendApiClient.instance.currentRoleName?.trim().toLowerCase() ==
          'principal';
      setState(
        () => _logs = isPrincipal
            ? logs
                  .where(
                    (log) =>
                        '${log['actor_role'] ?? ''}'.trim().toLowerCase() !=
                        'super_admin',
                  )
                  .toList()
            : logs,
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              DropdownMenuItem(value: 'auth', child: Text('Authentication')),
              DropdownMenuItem(value: 'users', child: Text('Users')),
              DropdownMenuItem(value: 'students', child: Text('Students')),
              DropdownMenuItem(value: 'staff', child: Text('Staff')),
              DropdownMenuItem(value: 'homework', child: Text('Homework')),
              DropdownMenuItem(value: 'fees', child: Text('Fees')),
              DropdownMenuItem(value: 'attendance', child: Text('Attendance')),
              DropdownMenuItem(
                value: 'communications',
                child: Text('Communications'),
              ),
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
              labelText: 'Staff member or username',
              helperText: 'Searches account names and usernames',
              suffixIcon: Icon(Icons.person_search_rounded),
            ),
            onSubmitted: (_) => _loadLogs(),
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            initialValue: _actorRole,
            decoration: const InputDecoration(labelText: 'Actor role'),
            items: const [
              DropdownMenuItem(value: '', child: Text('All roles')),
              DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
              DropdownMenuItem(value: 'kiosk', child: Text('Kiosk')),
              DropdownMenuItem(value: 'principal', child: Text('Principal')),
              DropdownMenuItem(
                value: 'coordinator',
                child: Text('Coordinator'),
              ),
            ],
            onChanged: (value) {
              setState(() => _actorRole = value ?? '');
              _loadLogs();
            },
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            initialValue: _eventType,
            decoration: const InputDecoration(labelText: 'Event'),
            items: const [
              DropdownMenuItem(value: '', child: Text('All events')),
              DropdownMenuItem(value: 'login', child: Text('Login')),
              DropdownMenuItem(value: 'logout', child: Text('Logout')),
              DropdownMenuItem(
                value: 'attendance.check_in',
                child: Text('Check-in'),
              ),
              DropdownMenuItem(
                value: 'attendance.check_out',
                child: Text('Check-out'),
              ),
            ],
            onChanged: (value) {
              setState(() => _eventType = value ?? '');
              _loadLogs();
            },
          ),
        ),
        SizedBox(
          width: 220,
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search activity',
              suffixIcon: Icon(Icons.search_rounded),
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
    final presentation = _AuditLogPresentation.from(log);
    final createdAt = DateTime.tryParse('${log['created_at'] ?? ''}');
    final when = createdAt == null
        ? ''
        : DateFormat('d MMM yyyy, h:mm a').format(createdAt.toLocal());
    return Card(
      child: ListTile(
        isThreeLine: true,
        leading: Icon(presentation.icon),
        title: Text(presentation.title),
        subtitle: Text(
          [
            presentation.actor,
            if (presentation.role.isNotEmpty &&
                presentation.role.toLowerCase() !=
                    presentation.actor.toLowerCase())
              presentation.role,
            presentation.module,
          ].where((value) => value.isNotEmpty).join(' · '),
        ),
        trailing: SizedBox(
          width: 104,
          child: Text(
            when,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
    );
  }
}

class _AuditLogPresentation {
  final String title;
  final String actor;
  final String role;
  final String module;
  final IconData icon;

  const _AuditLogPresentation({
    required this.title,
    required this.actor,
    required this.role,
    required this.module,
    required this.icon,
  });

  factory _AuditLogPresentation.from(Map<String, dynamic> log) {
    final action = '${log['action'] ?? ''}'.trim().toLowerCase();
    final rawSummary = '${log['summary'] ?? ''}'.trim();
    final rawModule = '${log['module'] ?? log['entity_type'] ?? ''}'.trim();
    final module = _moduleLabel(rawModule);
    final role = _titleCase('${log['actor_role'] ?? ''}');
    final actor = '${log['actor_name'] ?? ''}'.trim();
    final displayActor = actor.isNotEmpty
        ? actor
        : (role.isNotEmpty ? role : 'School user');
    final isTechnicalSummary = RegExp(
      r'\bperformed\s+(GET|POST|PATCH|PUT|DELETE)\s+in\b',
      caseSensitive: false,
    ).hasMatch(rawSummary);
    final rawDetails = log['details'];
    final details = rawDetails is Map
        ? '${rawDetails['description'] ?? ''}'.trim()
        : '';
    final title = isTechnicalSummary || rawSummary.isEmpty
        ? details.isNotEmpty
              ? _sentenceCase(details)
              : _friendlyAction(action, rawModule)
        : _sentenceCase(rawSummary);
    return _AuditLogPresentation(
      title: _parentFacingText(title),
      actor: displayActor,
      role: role,
      module: module,
      icon: _moduleIcon(rawModule),
    );
  }

  static String _friendlyAction(String action, String rawModule) {
    if (action.contains('logout') || action.contains('sign_out')) {
      return 'Signed out';
    }
    if (action.contains('login') || action.contains('sign_in')) {
      return 'Signed in';
    }
    if (action.contains('credentials.reset')) {
      return 'Reset account password';
    }
    if (action.contains('check_in')) {
      return 'Checked in for staff attendance';
    }
    if (action.contains('check_out')) {
      return 'Checked out from staff attendance';
    }
    final method = action.split('.').last;
    final verb = switch (method) {
      'post' => 'Added',
      'delete' => 'Deleted',
      'patch' || 'put' => 'Updated',
      'export' => 'Exported',
      _ => 'Updated',
    };
    final target = _moduleLabel(rawModule).toLowerCase();
    return '$verb ${target.isEmpty ? 'school information' : target}';
  }

  static String _moduleLabel(String value) {
    final normalized = value.toLowerCase().trim();
    const labels = <String, String>{
      'auth': 'Authentication',
      'attendance': 'Attendance',
      'branches': 'Branches',
      'communications': 'Communications',
      'event-posts': 'School Feed',
      'events': 'Events',
      'fees': 'Fees',
      'guardians': 'Parents',
      'homework': 'Homework',
      'staff': 'Staff',
      'students': 'Students',
      'users': 'Accounts',
    };
    return labels[normalized] ?? _titleCase(normalized);
  }

  static IconData _moduleIcon(String value) {
    switch (value.toLowerCase().trim()) {
      case 'fees':
        return Icons.currency_rupee_rounded;
      case 'attendance':
        return Icons.how_to_reg_rounded;
      case 'students':
      case 'guardians':
      case 'staff':
      case 'users':
        return Icons.people_outline_rounded;
      case 'event-posts':
      case 'communications':
        return Icons.campaign_outlined;
      case 'auth':
        return Icons.login_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  static String _titleCase(String value) => value
      .split(RegExp(r'[_\s-]+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');

  static String _parentFacingText(String value) => value
      .replaceAll(RegExp(r'\bGuardians\b'), 'Parents')
      .replaceAll(RegExp(r'\bguardians\b'), 'parents')
      .replaceAll(RegExp(r'\bGuardian\b'), 'Parent')
      .replaceAll(RegExp(r'\bguardian\b'), 'parent');

  static String _sentenceCase(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
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
