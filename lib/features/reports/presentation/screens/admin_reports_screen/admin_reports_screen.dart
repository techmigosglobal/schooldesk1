import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/admin_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _reportCategories = [
    {
      'category': 'Admission Reports',
      'icon': Icons.person_add_rounded,
      'color': AppTheme.primary,
      'reports': [
        {
          'name': 'New Admissions This Term',
          'desc': 'List of all new admissions in Term 3 (2025–26)',
        },
        {
          'name': 'Class-wise Enrollment',
          'desc': 'Student count per class and section',
        },
        {
          'name': 'Annual Admission Summary',
          'desc': 'Year-wise admission trends',
        },
      ],
    },
    {
      'category': 'Fee Reports',
      'icon': Icons.account_balance_wallet_rounded,
      'color': AppTheme.success,
      'reports': [
        {
          'name': 'Term 3 Collection Report',
          'desc': 'Total fees collected for Term 3 (Jan–Apr 2026)',
        },
        {
          'name': 'Pending Dues Report',
          'desc': 'Students with outstanding fee dues',
        },
        {'name': 'Concession Report', 'desc': 'All fee concessions granted'},
        {
          'name': 'Annual Finance Summary',
          'desc': 'Full year financial overview 2025–26',
        },
      ],
    },
    {
      'category': 'Attendance Reports',
      'icon': Icons.how_to_reg_rounded,
      'color': AppTheme.warning,
      'reports': [
        {
          'name': 'Daily Attendance Summary',
          'desc': 'Today\'s attendance across all classes',
        },
        {
          'name': 'Monthly Attendance Report',
          'desc': 'Attendance trends for current month',
        },
        {
          'name': 'Chronic Absentee Report',
          'desc': 'Students with <75% attendance',
        },
        {
          'name': 'Teacher Attendance Report',
          'desc': 'Staff attendance and leave records',
        },
      ],
    },
    {
      'category': 'Government Compliance',
      'icon': Icons.account_balance_rounded,
      'color': Color(0xFF6C3483),
      'reports': [
        {
          'name': 'DISE Data Export',
          'desc': 'District Information System for Education',
        },
        {
          'name': 'RTE Compliance Report',
          'desc': 'Right to Education compliance data',
        },
        {
          'name': 'SC/ST/OBC Student Report',
          'desc': 'Category-wise student data',
        },
        {
          'name': 'Annual School Return 2025–26',
          'desc': 'Government annual return data',
        },
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Reports',
      subtitle:
          'Generate operational, finance, attendance, and compliance outputs',
      drawer: AdminDrawer(selectedIndex: 11, onDestinationSelected: (_) {}),
      floatingActionButton: const DashboardFabWidget(role: DashboardRole.admin),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'All Reports'),
          Tab(text: 'Compliance'),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildAllReports(), _buildCompliance()],
      ),
    );
  }

  Widget _buildAllReports() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _reportCategories.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        // First item: Report Card Generator banner
        if (i == 0) {
          return GestureDetector(
            onTap: () =>
                Navigator.pushNamed(context, AppRoutes.reportCardGenerator),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primary.withAlpha(200)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Student Report Card Generator',
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Generate printable report cards with exam results & attendance',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ),
            ),
          );
        }
        final cat = _reportCategories[i - 1];
        final reports = cat['reports'] as List<Map<String, dynamic>>;
        final c = cat['color'] as Color;
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.withAlpha(15),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(cat['icon'] as IconData, size: 20, color: c),
                    const SizedBox(width: 10),
                    Text(
                      cat['category'] as String,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${reports.length} reports',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              ...reports.asMap().entries.map((entry) {
                final r = entry.value;
                final isLast = entry.key == reports.length - 1;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r['name'] as String,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  r['desc'] as String,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    color: AppTheme.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            children: [
                              _buildExportBtn('PDF', c, () {
                                _exportReport(
                                  context,
                                  r['name'] as String,
                                  'PDF',
                                );
                              }),
                              const SizedBox(width: 6),
                              _buildExportBtn('CSV', c, () {
                                _exportReport(
                                  context,
                                  r['name'] as String,
                                  'CSV',
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      const Divider(height: 1, indent: 14, endIndent: 14),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExportBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: label == 'PDF'
              ? color.withAlpha(20)
              : AppTheme.successContainer,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: label == 'PDF'
                ? color.withAlpha(60)
                : AppTheme.success.withAlpha(60),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: label == 'PDF' ? color : AppTheme.success,
          ),
        ),
      ),
    );
  }

  Widget _buildCompliance() {
    final complianceItems = [
      {
        'title': 'DISE Annual Return',
        'deadline': '30 Jun 2025',
        'status': 'Pending',
        'progress': 0.3,
      },
      {
        'title': 'RTE Compliance Report',
        'deadline': '31 May 2025',
        'status': 'In Progress',
        'progress': 0.6,
      },
      {
        'title': 'SC/ST/OBC Data Submission',
        'deadline': '15 May 2025',
        'status': 'Completed',
        'progress': 1.0,
      },
      {
        'title': 'Mid-Day Meal Report',
        'deadline': '30 Apr 2025',
        'status': 'Pending',
        'progress': 0.1,
      },
      {
        'title': 'Infrastructure Report',
        'deadline': '31 Jul 2025',
        'status': 'Not Started',
        'progress': 0.0,
      },
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: complianceItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final c = complianceItems[i];
        final statusColors = {
          'Pending': AppTheme.warning,
          'In Progress': AppTheme.info,
          'Completed': AppTheme.success,
          'Not Started': AppTheme.muted,
        };
        final sc = statusColors[c['status']] ?? AppTheme.muted;
        final progress = c['progress'] as double;
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
                  Expanded(
                    child: Text(
                      c['title'] as String,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: sc.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      c['status'] as String,
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: sc,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Deadline: ${c['deadline']}',
                style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: AppTheme.outlineVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(sc),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: sc,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _exportReport(context, c['title'] as String, 'PDF');
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                      child: Text(
                        'Export PDF',
                        style: GoogleFonts.dmSans(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${c['title']} shared with Principal',
                              ),
                              backgroundColor: AppTheme.success,
                            ),
                          ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                      child: Text(
                        'Share with Principal',
                        style: GoogleFonts.dmSans(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportReport(
    BuildContext context,
    String name,
    String format,
  ) async {
    try {
      final export = await BackendApiClient.instance.createReportExport(
        '/reports/exports',
        reportTitle: name,
        format: format,
        scope: 'admin',
        parameters: {
          'source_screen': 'admin_reports',
          'requested_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
      if (!context.mounted) return;
      final status = export['status'] ?? 'requested';
      final download = export['download_url'] ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$name export $status${download.toString().isEmpty ? '' : ' · $download'}',
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report export failed: $error'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
