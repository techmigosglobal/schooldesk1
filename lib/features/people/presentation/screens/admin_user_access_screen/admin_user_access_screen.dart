import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/admin_navigation.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/features/people/presentation/screens/admin_user_access_screen/account_access_form_screen.dart';
import 'package:schooldesk1/features/people/presentation/screens/admin_user_access_screen/account_child_assignment_screen.dart';

class AdminUserAccessScreen extends StatefulWidget {
  final String ownerRole;

  const AdminUserAccessScreen({super.key, this.ownerRole = 'admin'});

  @override
  State<AdminUserAccessScreen> createState() => _AdminUserAccessScreenState();
}

class _AdminUserAccessScreenState extends State<AdminUserAccessScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _filterRole = 'All';
  String _statusFilter = 'Active';
  bool _loading = false;
  String? _error;

  final List<Map<String, dynamic>> _users = [];
  final List<Map<String, dynamic>> _activities = [];

  List<String> get _manageableRoles => widget.ownerRole == 'principal'
      ? ['Admin', 'Teacher', 'Parent']
      : ['Teacher', 'Parent'];

  bool get _isPrincipalOwner => widget.ownerRole == 'principal';

  final Map<String, List<String>> _rolePermissions = {
    'Principal': [
      'Dashboard',
      'Staff',
      'Students',
      'Fees',
      'Exams',
      'Reports',
      'Approvals',
      'Communication',
      'All Access',
    ],
    'Admin': [
      'Dashboard',
      'Students',
      'Teachers',
      'Fees',
      'Attendance',
      'Exams',
      'Notices',
      'Reports',
      'Documents',
    ],
    'Teacher': [
      'Dashboard',
      'Attendance',
      'Syllabus',
      'Exams',
      'Communication',
    ],
    'Parent': ['Child Profile', 'Attendance View', 'Fee View', 'Notices'],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered => _filterRole == 'All'
      ? _users
      : _users.where((u) => u['role'] == _filterRole).toList();

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = BackendApiClient.instance;
      final roleFilter = null;
      final statusFilter = _statusFilter == 'All'
          ? null
          : _statusFilter.toLowerCase();
      final res = await api.getUsers(
        role: roleFilter,
        status: statusFilter,
        page: 1,
        pageSize: 200,
      );
      final now = DateTime.now();
      final rows = res.data
          .map((u) {
            final role = _titleCase(u.roleName);
            final status = u.isActive ? 'Active' : 'Inactive';
            final lastLogin = u.lastLogin == null
                ? 'Never'
                : DateFormat('d MMM h:mm a').format(u.lastLogin!.toLocal());
            final cleanName = u.name
                .trim()
                .replaceAll(RegExp(r'\s+\.$'), '')
                .trim();
            final displayName = cleanName.isNotEmpty
                ? cleanName
                : (u.email.isNotEmpty ? u.email : '$role User');
            return {
              'id': u.id,
              'name': displayName,
              'username': u.username,
              'role': role,
              'email': u.email,
              'status': status,
              'lastLogin': lastLogin,
              'isVerified': u.isVerified,
              'createdAt': u.createdAt ?? now,
              'linkedType': u.linkedType,
              'linkedId': u.linkedId,
              'staffId': u.linkedId,
            };
          })
          .where((u) => _manageableRoles.contains(u['role']))
          .toList();
      final activityRows = await api.getRawList('/audit-logs');
      final activities = activityRows.take(30).map((a) {
        final createdAt = DateTime.tryParse('${a['created_at'] ?? ''}');
        final when = createdAt == null
            ? ''
            : DateFormat('d MMM h:mm a').format(createdAt.toLocal());
        return {
          'user': '${a['role'] ?? 'User'}',
          'action':
              '${a['action'] ?? 'updated'} ${a['module'] ?? a['table_name'] ?? 'record'}',
          'time': when,
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _users
          ..clear()
          ..addAll(rows);
        _activities
          ..clear()
          ..addAll(activities);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _titleCase(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return clean;
    return clean[0].toUpperCase() + clean.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isPrincipalOwner ? 'Access & Permissions' : 'Access';
    final drawer = widget.ownerRole == 'principal'
        ? PrincipalDrawer(selectedIndex: 1, onDestinationSelected: (_) {})
        : AdminDrawer(selectedIndex: 10, onDestinationSelected: (_) {});
    return SchoolDeskModuleScaffold(
      title: title,
      subtitle: _isPrincipalOwner
          ? 'Create school operators and review permission boundaries'
          : 'Provision teacher and parent accounts from backend users',
      drawer: drawer,
      floatingActionButton: DashboardFabWidget(
        role: _isPrincipalOwner ? DashboardRole.principal : DashboardRole.admin,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      actions: [
        if (_isPrincipalOwner)
          IconButton(
            tooltip: 'Create role login',
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: () => _openUserForm(),
          ),
        if (_isPrincipalOwner)
          IconButton(
            tooltip: 'Open Staff',
            icon: const Icon(Icons.people_alt_outlined),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.staffManagement),
          )
        else
          IconButton(
            tooltip: 'Create teacher or parent account',
            icon: const Icon(Icons.person_add_rounded),
            onPressed: () => _openUserForm(),
          ),
      ],
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Users'),
          Tab(text: 'Permissions'),
          Tab(text: 'Activity'),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildUsers(), _buildPermissions(), _buildActivity()],
      ),
    );
  }

  Widget _buildUsers() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Failed to load users',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadUsers, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        if (_isPrincipalOwner) _buildPrincipalAccessNotice(),
        _buildUserFilters(),
        Expanded(
          child: _filtered.isEmpty
              ? _buildEmptyUsers()
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _buildUserCard(_filtered[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildUserFilters() {
    return Container(
      width: double.infinity,
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChipRow(
            options: const ['Active', 'Inactive', 'All'],
            selected: _statusFilter,
            onSelected: (value) {
              setState(() => _statusFilter = value);
              _loadUsers();
            },
          ),
          const SizedBox(height: 8),
          _buildChipRow(
            options: ['All', ..._manageableRoles],
            selected: _filterRole,
            onSelected: (value) => setState(() => _filterRole = value),
          ),
        ],
      ),
    );
  }

  Widget _buildChipRow({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            ChoiceChip(
              label: Text(options[i]),
              selected: selected == options[i],
              showCheckmark: false,
              labelStyle: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected == options[i]
                    ? Colors.white
                    : AppTheme.onSurface,
              ),
              selectedColor: AppTheme.primary,
              backgroundColor: AppTheme.surfaceVariant,
              side: BorderSide(
                color: selected == options[i]
                    ? AppTheme.primary
                    : AppTheme.outlineVariant,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onSelected: (_) => onSelected(options[i]),
            ),
            if (i != options.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyUsers() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _statusFilter == 'Inactive'
                  ? Icons.inventory_2_outlined
                  : Icons.people_outline_rounded,
              size: 34,
              color: AppTheme.muted,
            ),
            const SizedBox(height: 10),
            Text(
              _statusFilter == 'Inactive'
                  ? 'No inactive accounts'
                  : 'No accounts found',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _statusFilter == 'Active'
                  ? 'Deactivated accounts move to the Inactive filter.'
                  : 'Change the filters to review another account set.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrincipalAccessNotice() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.infoContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.info.withAlpha(90)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppTheme.info,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Create Admin, Teacher, and Parent login accounts here, or open Staff to create a full staff profile with login credentials.',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                height: 1.35,
                color: AppTheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> u) {
    final statusColors = {
      'Active': AppTheme.success,
      'Inactive': AppTheme.muted,
      'Locked': AppTheme.error,
    };
    final roleColors = {
      'Principal': Color(0xFF6C3483),
      'Admin': AppTheme.primary,
      'Teacher': AppTheme.success,
      'Parent': AppTheme.warning,
    };
    final sc = statusColors[u['status']] ?? AppTheme.muted;
    final rc = roleColors[u['role']] ?? AppTheme.muted;
    final username = (u['username'] as String?)?.trim() ?? '';
    final email = (u['email'] as String?)?.trim() ?? '';
    final hasLinkedStaff =
        (u['linkedType'] ?? '') == 'staff' &&
        (u['linkedId'] ?? '').toString().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: u['status'] == 'Locked'
              ? AppTheme.errorContainer
              : AppTheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: rc.withAlpha(25),
            child: Text(
              _initialFor(u['name']),
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: rc,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        u['name'] as String,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildRoleBadge(u['role'] as String, rc),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (username.isNotEmpty)
                      _buildInfoPill(
                        icon: Icons.alternate_email_rounded,
                        label: username,
                      ),
                    if (email.isNotEmpty)
                      _buildInfoPill(
                        icon: Icons.mail_outline_rounded,
                        label: email,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStatusBadge(u['status'] as String, sc),
                    if (hasLinkedStaff)
                      _buildInfoPill(
                        icon: Icons.badge_outlined,
                        label: 'Staff profile',
                        color: AppTheme.primary,
                        backgroundColor: AppTheme.primaryContainer,
                      ),
                    _buildInfoPill(
                      icon: Icons.schedule_rounded,
                      label: 'Last: ${u['lastLogin']}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              size: 16,
              color: AppTheme.muted,
            ),
            onSelected: (v) => _handleUserAction(context, v, u),
            itemBuilder: (_) => [
              if (u['role'] == 'Parent')
                const PopupMenuItem(
                  value: 'assign_children',
                  child: Text('Assign Children'),
                ),
              const PopupMenuItem(
                value: 'edit',
                child: Text('Edit Access / Reset Password'),
              ),
              PopupMenuItem(
                value: u['status'] == 'Inactive' ? 'activate' : 'deactivate',
                child: Text(
                  u['status'] == 'Inactive'
                      ? 'Activate Account'
                      : 'Deactivate Account',
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  u['status'] == 'Inactive'
                      ? 'Delete Permanently'
                      : 'Move to Inactive',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _initialFor(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '?' : text.substring(0, 1).toUpperCase();
  }

  Widget _buildRoleBadge(String role, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        role,
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String label,
    Color? color,
    Color? backgroundColor,
  }) {
    final foreground = color ?? AppTheme.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: foreground),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissions() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _rolePermissions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final role = _rolePermissions.keys.elementAt(i);
        final perms = _rolePermissions[role]!;
        final roleColors = {
          'Principal': Color(0xFF6C3483),
          'Admin': AppTheme.primary,
          'Teacher': AppTheme.success,
          'Parent': AppTheme.warning,
        };
        final c = roleColors[role] ?? AppTheme.muted;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: c.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      role,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: c,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${perms.length} permissions',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: perms
                    .map(
                      (p) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_rounded,
                              size: 10,
                              color: AppTheme.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              p,
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivity() {
    final activities = _activities;
    if (activities.isEmpty) {
      return Center(
        child: Text(
          'No user activity yet',
          style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.muted),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: activities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final a = activities[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  size: 14,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a['action']!,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    Text(
                      '${a['user']} • ${a['time']}',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleUserAction(
    BuildContext context,
    String action,
    Map<String, dynamic> u,
  ) {
    switch (action) {
      case 'edit':
        _openUserForm(existing: u);
        break;
      case 'activate':
        _setUserActive(u, true);
        break;
      case 'deactivate':
        _setUserActive(u, false);
        break;
      case 'delete':
        _deleteUser(u);
        break;
      case 'assign_children':
        _openChildAssignment(u);
        break;
    }
  }

  Future<void> _openUserForm({Map<String, dynamic>? existing}) async {
    final route = _isPrincipalOwner
        ? (existing == null
              ? AppRoutes.principalAccountCreate
              : AppRoutes.principalAccountEdit)
        : (existing == null
              ? AppRoutes.adminAccountCreate
              : AppRoutes.adminAccountEdit);
    final result = await Navigator.pushNamed(
      context,
      route,
      arguments: AccountAccessFormArgs(
        ownerRole: widget.ownerRole,
        existing: existing,
      ),
    );

    if (!mounted || result == null) return;
    final isCreated = result is AccountAccessFormResult && result.created;
    if (isCreated && !_isPrincipalOwner) {
      setState(() {
        _statusFilter = 'All';
      });
    }
    await _loadUsers();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            isCreated
                ? (_isPrincipalOwner
                      ? 'Account created'
                      : 'Account created and sent for Principal approval')
                : 'Account updated',
          ),
          backgroundColor: AppTheme.success,
        ),
      );
  }

  Future<void> _openChildAssignment(Map<String, dynamic> u) async {
    final route = _isPrincipalOwner
        ? AppRoutes.principalParentChildAssignment
        : AppRoutes.adminParentChildAssignment;
    final result = await Navigator.pushNamed(
      context,
      route,
      arguments: AccountChildAssignmentArgs(
        ownerRole: widget.ownerRole,
        parentUserId: (u['id'] ?? '').toString(),
        parentName: (u['name'] ?? 'Parent').toString(),
        parentEmail: (u['email'] ?? '').toString(),
      ),
    );
    if (!mounted || result != true) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Children assigned to parent account'),
          backgroundColor: AppTheme.success,
        ),
      );
  }

  Future<void> _setUserActive(Map<String, dynamic> u, bool active) async {
    try {
      await BackendApiClient.instance.updateUser(
        u['id'].toString(),
        isActive: active,
      );
      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(active ? 'Account activated' : 'Account deactivated'),
          backgroundColor: active ? AppTheme.success : AppTheme.warning,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Update failed: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> u) async {
    final isInactive = u['status'] == 'Inactive';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          isInactive
              ? 'Delete Inactive Account Permanently'
              : 'Move Account to Inactive',
        ),
        content: Text(
          isInactive
              ? 'Permanently delete ${u['name']} from inactive users? This cannot be restored.'
              : 'Move ${u['name']} to the inactive archive? The login will be disabled and can be restored from the Inactive filter.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isInactive ? 'Delete' : 'Move'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final staffId = '${u['staffId'] ?? ''}';
      if (isInactive) {
        await BackendApiClient.instance.deleteUser(
          u['id'].toString(),
          permanent: true,
        );
      } else if ((u['linkedType'] ?? '') == 'staff' && staffId.isNotEmpty) {
        await BackendApiClient.instance.deleteStaff(staffId);
      } else {
        await BackendApiClient.instance.deleteUser(u['id'].toString());
      }
      await _loadUsers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isInactive
                ? 'Inactive account permanently deleted'
                : staffId.isEmpty
                ? 'Account moved to inactive'
                : 'Linked staff profile removed and login deactivated',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}
