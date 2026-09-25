import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/roles/principal/data/api_admin_reports_repository.dart';
import 'package:schooldesk1/roles/principal/domain/admin_reports_repository.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key, this.repository});

  final AdminReportsRepository? repository;

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen>
    with SingleTickerProviderStateMixin {
  late final AdminReportsRepository _repository =
      widget.repository ?? ApiAdminReportsRepository.legacyDefault;
  late TabController _tabController;
  RepositoryState<Object> _state = const RepositoryState<Object>(
    data: Object(),
    source: RepositorySource.remote,
  );

  List<Map<String, dynamic>> get _reportCategories => [
    {
      'category': 'Admission Reports',
      'icon': Icons.person_add_rounded,
      'color': context.appTheme.primary,
      'reports': [
        {
          'name': 'New Admissions This Term',
          'desc': 'Admissions in selected reporting period',
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
      'category': 'Attendance Reports',
      'icon': Icons.how_to_reg_rounded,
      'color': context.appTheme.warning,
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
      'color': const Color(0xFF6C3483),
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
          'name': 'Annual School Return',
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
      drawer: PrincipalDrawer(
        selectedIndex: PrincipalNav.reports,
        onDestinationSelected: (_) {},
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.principal,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'All Reports'),
          Tab(text: 'Compliance'),
        ],
      ),
      body: SchoolDeskRepositoryStateView<Object>(
        state: _state,
        onRetry: () => setState(() {
          _state = const RepositoryState<Object>(
            data: Object(),
            source: RepositorySource.remote,
          );
        }),
        data: (_) => TabBarView(
          controller: _tabController,
          children: [_buildAllReports(), _buildCompliance()],
        ),
      ),
    );
  }

  Widget _buildAllReports() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _reportCategories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final cat = _reportCategories[i];
        final reports = cat['reports'] as List<Map<String, dynamic>>;
        final c = cat['color'] as Color;
        return Container(
          decoration: BoxDecoration(
            color: context.appTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.appTheme.outlineVariant),
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
                        color: context.appTheme.muted,
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
                                    color: context.appTheme.muted,
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
              : context.appTheme.successContainer,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: label == 'PDF'
                ? color.withAlpha(60)
                : context.appTheme.success.withAlpha(60),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: label == 'PDF' ? color : context.appTheme.success,
          ),
        ),
      ),
    );
  }

  Widget _buildCompliance() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: SchoolDeskStatusPanel.empty(
        title: 'Compliance status unavailable',
        message:
            'Live compliance status is not provided by reporting API yet. No placeholder status is shown.',
      ),
    );
  }

  Future<void> _exportReport(
    BuildContext context,
    String name,
    String format,
  ) async {
    try {
      final export = await _repository.requestExport(
        reportTitle: name,
        format: format,
      );
      if (!context.mounted) return;
      final status = export['status'] ?? 'requested';
      final download = export['download_url'] ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$name export $status${download.toString().isEmpty ? '' : ' · $download'}',
          ),
          backgroundColor: context.appTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report export failed: $error'),
          backgroundColor: context.appTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
