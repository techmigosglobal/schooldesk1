import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/widgets/app_background.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/school_desk_animations.dart';
import 'package:schooldesk1/core/desktop/desktop_platform.dart';
import 'package:schooldesk1/core/widgets/branch_switcher.dart';
import 'package:schooldesk1/core/widgets/loading_skeleton_widget.dart';
import 'package:schooldesk1/core/services/token_storage_service.dart';
import 'package:schooldesk1/core/services/realtime_refresh_service.dart';

class SuperAdminDashboardScreen extends StatefulWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  State<SuperAdminDashboardScreen> createState() =>
      _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  final _api = BackendApiClient.instance;
  bool _loading = false;
  String _adminName = 'Super Admin';
  String _schoolName = 'School System';
  String _systemStatus = 'Online';
  int _errorEventsCount = 0;

  // School stats from dashboard API
  int _totalStudents = 0;
  int _totalStaff = 0;
  int _totalClasses = 0;
  List<Map<String, dynamic>> _branchOverview = const [];
  RealtimeRefreshSubscription? _realtimeSubscription;

  String _firstName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : fullName;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    _realtimeSubscription = RealtimeRefreshService.instance.subscribe(
      channelName: 'super-admin-dashboard',
      modules: const {'announcements', 'event_posts', 'attendance', 'fees'},
      onRefresh: () {
        if (mounted) _loadData();
      },
    );
  }

  @override
  void dispose() {
    _realtimeSubscription?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
    });
    try {
      // Use the dedicated super_admin dashboard endpoint.
      final results = await Future.wait([
        _api.getProfile(),
        _api.getCurrentSchool(),
        _api.getDashboard('super_admin', forceRefresh: true),
        _api.getBranchOverview(),
      ]);

      final profile = results[0] as UserResponse;
      final school = results[1] as Map<String, dynamic>;
      final dashboard = results[2] as Map<String, dynamic>;
      final sysMetrics = dashboard['system_metrics'] as Map? ?? {};

      setState(() {
        _adminName = profile.name.trim().isEmpty
            ? 'Super Admin'
            : profile.name.trim();
        _schoolName = school['name']?.toString() ?? 'School System';
        _errorEventsCount = sysMetrics['open_errors'] as int? ?? 0;
        _totalStudents = sysMetrics['total_students'] as int? ?? 0;
        _totalStaff = sysMetrics['total_staff'] as int? ?? 0;
        _totalClasses = sysMetrics['total_classes'] as int? ?? 0;
        _systemStatus = 'Healthy';
        _branchOverview = results[3] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } on Object catch (_) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _backupDb() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Starting database backup...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
    } on Object catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup failed: $err'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _manageDemo() async {
    try {
      var account = await _api.getDemoAccount();
      if (account == null) {
        final schoolId = await TokenStorageService.getSchoolId();
        if (schoolId == null || schoolId.isEmpty) {
          throw StateError(
            'Select a school before creating the synthetic demo account.',
          );
        }
        account = await _api.createDemoAccount(demoSchoolId: schoolId);
        if (!mounted) return;
        await _showDemoCredential(account, created: true);
        return;
      }
      if (!mounted) return;
      final currentAccount = account;
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Shared mobile demo'),
          content: Text(
            'Username: ${currentAccount['username']}\nStatus: ${currentAccount['is_enabled'] == true ? 'Enabled' : 'Disabled'}\nPasswords rotate every 72 hours and may be revealed once after rotation.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'reveal'),
              child: const Text('Reveal once'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                currentAccount['is_enabled'] == true ? 'disable' : 'enable',
              ),
              child: Text(
                currentAccount['is_enabled'] == true
                    ? 'Disable demo'
                    : 'Enable demo',
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'reset'),
              child: const Text('Reset now'),
            ),
          ],
        ),
      );
      if (action == null) return;
      if (action == 'enable' || action == 'disable') {
        await _api.setDemoAccountEnabled(
          currentAccount['id'].toString(),
          action == 'enable',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Demo access ${action == 'enable' ? 'enabled' : 'disabled'}.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }
      final secret = action == 'reset'
          ? await _api.resetDemoAccount(currentAccount['id'].toString())
          : await _api.revealDemoAccount(currentAccount['id'].toString());
      if (mounted) {
        await _showDemoCredential(secret);
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Demo administration failed: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showDemoCredential(
    Map<String, dynamic> value, {
    bool created = false,
  }) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        created ? 'Demo account created' : 'One-time demo credential',
      ),
      content: SelectableText(
        'Username: ${value['username']}\nPassword: ${value['temporary_password']}\n\nShare this only with approved demo users. This password will not be shown again.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('I have shared it securely'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        drawer: SuperAdminDrawer(
          selectedIndex: 0,
          onDestinationSelected: (index) {},
        ),
        body: AppBackground(
          accent: const Color(0xFF0B2F5B),
          child: SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: _loading
                    ? const SchoolDeskPageSkeleton(cardCount: 4)
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                          children: [
                            StaggeredFadeIn(
                              children: [
                                _buildHeader(context),
                                const SizedBox(height: 12),
                                BranchSwitcher(
                                  canCreate: true,
                                  onChanged: _loadData,
                                ),
                                const SizedBox(height: 18),
                                _buildStatusCard(context),
                                const SizedBox(height: 18),
                                _buildStatsRow(context),
                                if (_branchOverview.isNotEmpty) ...[
                                  const SizedBox(height: 22),
                                  _buildSectionTitle('Branch health'),
                                  const SizedBox(height: 12),
                                  _buildBranchOverview(context),
                                ],
                                const SizedBox(height: 22),
                                _buildSectionTitle('System Management'),
                                const SizedBox(height: 12),
                                _buildGrid([
                                  const _ModuleCard(
                                    label: 'Audit Logs',
                                    route: AppRoutes.superAdminAuditLogs,
                                    icon: Icons.history_rounded,
                                    accent: Color(0xFF0B2F5B),
                                    cardColor: Color(0xFFEEF7FF),
                                  ),
                                  _ModuleCard(
                                    label: 'System Monitor',
                                    route: AppRoutes.superAdminSystemMonitor,
                                    icon: Icons.monitor_heart_rounded,
                                    accent: const Color(0xFF54A9E8),
                                    cardColor: const Color(0xFFEEF7FF),
                                    badge: _errorEventsCount > 0
                                        ? _errorEventsCount
                                        : null,
                                  ),
                                  const _ModuleCard(
                                    label: 'Issue Management',
                                    route: AppRoutes.superAdminIssues,
                                    icon: Icons.support_agent_rounded,
                                    accent: Color(0xFFC88700),
                                    cardColor: Color(0xFFFFF7D6),
                                  ),
                                  _ModuleCard(
                                    label: 'Backup Database',
                                    onTap: _backupDb,
                                    icon: Icons.backup_rounded,
                                    accent: const Color(0xFF10B981),
                                    cardColor: const Color(0xFFECFDF5),
                                  ),
                                  _ModuleCard(
                                    label: 'Mobile Demo',
                                    onTap: _manageDemo,
                                    icon: Icons.play_circle_outline_rounded,
                                    accent: const Color(0xFFC88700),
                                    cardColor: const Color(0xFFFFF7E5),
                                  ),
                                ]),
                                const SizedBox(height: 22),
                                _buildSectionTitle('School Oversight'),
                                const SizedBox(height: 12),
                                _buildGrid([
                                  const _ModuleCard(
                                    label: 'School Profile',
                                    route: AppRoutes.principalSchoolProfile,
                                    icon: Icons.apartment_rounded,
                                    accent: Color(0xFF0E5EA8),
                                    cardColor: Color(0xFFDCEFFF),
                                  ),
                                  const _ModuleCard(
                                    label: 'Access & Permissions',
                                    route: AppRoutes.superAdminAccess,
                                    icon: Icons.manage_accounts_rounded,
                                    accent: Color(0xFFF4C430),
                                    cardColor: Color(0xFFFEF3C7),
                                  ),
                                  const _ModuleCard(
                                    label: 'Staff oversight',
                                    route: AppRoutes.staffManagement,
                                    icon: Icons.people_rounded,
                                    accent: Color(0xFF2563EB),
                                    cardColor: Color(0xFFEAF4FF),
                                  ),
                                  const _ModuleCard(
                                    label: 'Students list',
                                    route: AppRoutes.studentOversight,
                                    icon: Icons.school_rounded,
                                    accent: Color(0xFF54A9E8),
                                    cardColor: Color(0xFFEEF7FF),
                                  ),
                                ]),
                                const SizedBox(height: 22),
                                _buildSectionTitle('Quick Actions'),
                                const SizedBox(height: 12),
                                _buildGrid([
                                  const _ModuleCard(
                                    label: 'Help & Docs',
                                    route: AppRoutes.help,
                                    icon: Icons.help_outline_rounded,
                                    accent: Color(0xFF0E5EA8),
                                    cardColor: Color(0xFFEEF7FF),
                                  ),
                                  const _ModuleCard(
                                    label: 'ID Cards',
                                    route: AppRoutes.idCardGeneration,
                                    icon: Icons.badge_rounded,
                                    accent: Color(0xFF54A9E8),
                                    cardColor: Color(0xFFEEF7FF),
                                  ),
                                ]),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBranchOverview(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: _branchOverview.map((branch) {
        final label = branch['name']?.toString() ?? 'Branch';
        final issues = branch['open_issues'] as int? ?? 0;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.account_tree_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${branch['students'] ?? 0} students · ${branch['staff'] ?? 0} staff · ${branch['classes'] ?? 0} classes',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (issues > 0)
                Chip(
                  avatar: const Icon(Icons.error_outline_rounded, size: 16),
                  label: Text('$issues issues'),
                )
              else
                const Icon(Icons.check_circle_rounded, color: Colors.green),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!DesktopPlatform.isDesktopLayout(context))
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.menu_rounded, color: Colors.white),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
              const Spacer(),
              IconButton(
                tooltip: 'How to use the application',
                icon: const Icon(
                  Icons.help_outline_rounded,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.pushNamed(context, AppRoutes.help),
              ),
              IconButton(
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.notificationCenter,
                  arguments: 'super_admin',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Hello, ${_firstName(_adminName)}',
            style: GoogleFonts.dmSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Super Administrator • $_schoolName',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFECFDF5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF10B981),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Status',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'All core modules functioning normally.',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _systemStatus.toUpperCase(),
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF047857),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatMiniCard(
            icon: Icons.school_rounded,
            label: 'Students',
            value: '$_totalStudents',
            color: const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatMiniCard(
            icon: Icons.co_present_rounded,
            label: 'Staff',
            value: '$_totalStaff',
            color: const Color(0xFF0E5EA8),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatMiniCard(
            icon: Icons.grid_view_rounded,
            label: 'Classes',
            value: '$_totalClasses',
            color: const Color(0xFF059669),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.dmSans(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildGrid(List<Widget> children) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: children,
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatMiniCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final String label;
  final String? route;
  final VoidCallback? onTap;
  final IconData icon;
  final Color accent;
  final Color cardColor;
  final int? badge;

  const _ModuleCard({
    required this.label,
    this.route,
    this.onTap,
    required this.icon,
    required this.accent,
    required this.cardColor,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap:
            onTap ??
            () {
              if (route != null) {
                Navigator.pushNamed(context, route!);
              }
            },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: accent, size: 20),
                  ),
                  Text(
                    label,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              if (badge != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badge',
                      style: GoogleFonts.dmSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
