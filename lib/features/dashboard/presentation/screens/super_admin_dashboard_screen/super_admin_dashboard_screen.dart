import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
    });
    try {
      final results = await Future.wait([
        _api.getProfile(),
        _api.getCurrentSchool(),
        _api.getErrorEvents(status: 'open', pageSize: 1),
      ]);

      final profile = results[0] as UserResponse;
      final school = results[1] as Map<String, dynamic>;
      final errorEvents = results[2] as Map<String, dynamic>;

      setState(() {
        _adminName = profile.name.trim().isEmpty
            ? 'Super Admin'
            : profile.name.trim();
        _schoolName = school['name']?.toString() ?? 'School System';
        _errorEventsCount = errorEvents['total'] as int? ?? 0;
        _systemStatus = 'Healthy';
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
        backgroundColor: const Color(0xFFF3F7FC),
        drawer: SuperAdminDrawer(
          selectedIndex: 0,
          onDestinationSelected: (index) {},
        ),
        body: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                        children: [
                          _buildHeader(context),
                          const SizedBox(height: 18),
                          _buildStatusCard(context),
                          const SizedBox(height: 22),
                          _buildSectionTitle('System Management'),
                          const SizedBox(height: 12),
                          _buildGrid([
                            const _ModuleCard(
                              label: 'Audit Logs',
                              route: AppRoutes.superAdminAuditLogs,
                              icon: Icons.history_rounded,
                              accent: Color(0xFF5B35F5),
                              cardColor: Color(0xFFF0EDFF),
                            ),
                            _ModuleCard(
                              label: 'System Monitor',
                              route: AppRoutes.superAdminSystemMonitor,
                              icon: Icons.monitor_heart_rounded,
                              accent: const Color(0xFF0EA5E9),
                              cardColor: const Color(0xFFE8F7FF),
                              badge: _errorEventsCount > 0
                                  ? _errorEventsCount
                                  : null,
                            ),
                            const _ModuleCard(
                              label: 'Error Logs',
                              route: AppRoutes.superAdminErrorReporting,
                              icon: Icons.error_rounded,
                              accent: Color(0xFFEF4444),
                              cardColor: Color(0xFFFEE2E2),
                            ),
                            _ModuleCard(
                              label: 'Backup Database',
                              onTap: _backupDb,
                              icon: Icons.backup_rounded,
                              accent: const Color(0xFF10B981),
                              cardColor: const Color(0xFFECFDF5),
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
                              accent: Color(0xFF7C3AED),
                              cardColor: Color(0xFFF3ECFF),
                            ),
                            const _ModuleCard(
                              label: 'Permissions',
                              route: AppRoutes.principalUserManagement,
                              icon: Icons.manage_accounts_rounded,
                              accent: Color(0xFFF59E0B),
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
                              accent: Color(0xFF0E9384),
                              cardColor: Color(0xFFE7FAF6),
                            ),
                          ]),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
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
            'Hello, $_adminName',
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
