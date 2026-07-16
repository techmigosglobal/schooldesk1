import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/constants/app_constants.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/backend_data_service.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/services/pdf_service.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

class ReportsAnalyticsScreen extends StatefulWidget {
  const ReportsAnalyticsScreen({super.key});

  @override
  State<ReportsAnalyticsScreen> createState() => _ReportsAnalyticsScreenState();
}

class _ReportsAnalyticsScreenState extends State<ReportsAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  int _selectedDrawerIndex = 11;
  late TabController _tabController;

  double _totalBilled = 0;
  double _totalCollected = 0;
  int _totalStudents = 0;
  int _totalStaff = 0;
  List<Map<String, dynamic>> _attendanceRows = [];
  List<Map<String, dynamic>> _staffRows = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final storage = await BackendDataService.getInstance();
    final invoices = await storage.getList(BackendDataService.kStudentFees);
    final students = await storage.getList(BackendDataService.kStudents);
    final staffRows = await storage.getList(BackendDataService.kAdminTeachers);
    final attendanceRows = await storage.getList(
      BackendDataService.kAdminAttendanceRecords,
    );

    double billed = 0;
    double collected = 0;
    for (final inv in invoices) {
      billed += (inv['total_amount'] as num?)?.toDouble() ?? 0;
      collected += (inv['paid_amount'] as num?)?.toDouble() ?? 0;
    }

    setState(() {
      _totalBilled = billed;
      _totalCollected = collected;
      _totalStudents = students.length;
      _totalStaff = staffRows.length;
      _staffRows = staffRows;
      _attendanceRows = attendanceRows;
      _isLoading = false;
    });
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
          'Review school-wide operational reports and export-ready insights',
      drawer: PrincipalDrawer(
        selectedIndex: _selectedDrawerIndex,
        onDestinationSelected: (i) => setState(() => _selectedDrawerIndex = i),
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.principal,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Attendance'),
          Tab(text: 'Fee'),
          Tab(text: 'Staff'),
        ],
      ),
      body: MediaQuery.of(context).size.width >= 840
          ? _buildTabletLayout(context)
          : _buildPhoneLayout(context),
    );
  }

  Widget _buildPhoneLayout(BuildContext context) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildAttendanceTab(),
        _buildFeeTab(),
        _buildStaffTab(),
      ],
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return _buildPhoneLayout(context);
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'School Overview — ${DateFormat('MMMM yyyy').format(DateTime.now())}',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Public School · Academic Year 2025–26',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: context.appTheme.muted,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  'Total Students',
                  '$_totalStudents',
                  Icons.school_rounded,
                  context.appTheme.primary,
                  context.appTheme.primaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiCard(
                  'Total Staff',
                  '$_totalStaff',
                  Icons.people_rounded,
                  context.appTheme.secondary,
                  context.appTheme.secondaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  'Avg Attendance',
                  _attendanceAverageLabel(),
                  Icons.how_to_reg_rounded,
                  context.appTheme.success,
                  context.appTheme.successContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiCard(
                  'Fee Collection',
                  _totalBilled > 0
                      ? '${((_totalCollected / _totalBilled) * 100).toStringAsFixed(1)}%'
                      : '0%',
                  Icons.account_balance_wallet_rounded,
                  context.appTheme.info,
                  context.appTheme.infoContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Quick Reports',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildReportButton(
            'Monthly Attendance Report',
            DateFormat('MMMM yyyy').format(DateTime.now()),
            Icons.calendar_month_rounded,
            context.appTheme.primary,
          ),
          const SizedBox(height: 8),
          _buildReportButton(
            'Fee Collection Summary',
            DateFormat('MMMM yyyy').format(DateTime.now()),
            Icons.receipt_long_rounded,
            context.appTheme.secondary,
          ),
          const SizedBox(height: 8),
          _buildReportButton(
            'Staff Attendance Report',
            DateFormat('MMMM yyyy').format(DateTime.now()),
            Icons.badge_rounded,
            context.appTheme.success,
          ),
          const SizedBox(height: 8),
          _buildReportButton(
            'Complaint Summary',
            DateFormat('MMMM yyyy').format(DateTime.now()),
            Icons.support_agent_rounded,
            context.appTheme.warning,
          ),
          const SizedBox(height: 20),
          Text(
            'Export Options',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showExportDialog('PDF'),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                  label: const Text('Export PDF'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showExportDialog('CSV'),
                  icon: const Icon(Icons.table_chart_rounded, size: 16),
                  label: const Text('Export CSV'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab() {
    final rows = _attendanceRows;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Class-wise Attendance — ${DateFormat('MMMM yyyy').format(DateTime.now())}',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            TextButton.icon(
              onPressed: () => _showExportDialog('PDF'),
              icon: const Icon(Icons.download_rounded, size: 14),
              label: const Text('Export'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          Text(
            'Backend attendance rows will appear here.',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: context.appTheme.muted,
            ),
          )
        else
          ...rows.map((c) => _buildAttendanceRow(c)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.appTheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'School Average',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.appTheme.primary,
                ),
              ),
              Text(
                _attendanceAverageLabel(),
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.appTheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Students Below 75% Attendance',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.appTheme.error,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Backend low-attendance records will appear here.',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: context.appTheme.muted,
          ),
        ),
      ],
    );
  }

  String _attendanceAverageLabel() {
    if (_attendanceRows.isEmpty) return '0%';
    var totalPercent = 0.0;
    var count = 0;
    for (final row in _attendanceRows) {
      final total = (row['total'] as num?)?.toDouble() ?? 0;
      final present = (row['present'] as num?)?.toDouble() ?? 0;
      final percent =
          (row['percent'] as num?)?.toDouble() ??
          (total > 0 ? (present / total) * 100 : 0);
      totalPercent += percent;
      count++;
    }
    return count == 0 ? '0%' : '${(totalPercent / count).toStringAsFixed(1)}%';
  }

  Widget _buildAttendanceRow(Map<String, dynamic> c) {
    final total = (c['total'] as num?)?.toDouble() ?? 0;
    final present = (c['present'] as num?)?.toDouble() ?? 0;
    final percent =
        (c['percent'] as num?)?.toDouble() ??
        (total > 0 ? (present / total) * 100 : 0);
    final Color color = percent >= 90
        ? context.appTheme.success
        : percent >= 80
        ? context.appTheme.warning
        : context.appTheme.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              'Class ${c['class']}',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent / 100,
                minHeight: 8,
                backgroundColor: context.appTheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${c['present']}/${c['total']}',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: context.appTheme.muted,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${percent.toStringAsFixed(1)}%',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final double outstanding = _totalBilled - _totalCollected;
    final double collectionRate = _totalBilled > 0
        ? (_totalCollected / _totalBilled) * 100
        : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Fee Collection Report — ${AppConstants.academicYear}',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton.icon(
              onPressed: () => _showExportDialog('CSV'),
              icon: const Icon(Icons.download_rounded, size: 14),
              label: const Text('Export'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildFeeQuarterCard(
          'Term 1',
          _totalBilled / 3,
          _totalCollected / 3,
          collectionRate,
        ),
        const SizedBox(height: 8),
        _buildFeeQuarterCard(
          'Term 2',
          _totalBilled / 3,
          _totalCollected / 3,
          collectionRate,
        ),
        const SizedBox(height: 8),
        _buildFeeQuarterCard(
          'Term 3',
          _totalBilled / 3,
          _totalCollected / 3,
          collectionRate,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.appTheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Annual Total Billed',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.appTheme.primary,
                    ),
                  ),
                  Text(
                    '₹${(_totalBilled).toStringAsFixed(0)}',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.appTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Collected',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: context.appTheme.success,
                    ),
                  ),
                  Text(
                    '₹${(_totalCollected).toStringAsFixed(0)}',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.appTheme.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Outstanding',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: context.appTheme.error,
                    ),
                  ),
                  Text(
                    '₹${(outstanding).toStringAsFixed(0)}',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.appTheme.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Annual Collection Rate',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.appTheme.info,
                    ),
                  ),
                  Text(
                    '${collectionRate.toStringAsFixed(1)}%',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.appTheme.info,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeeQuarterCard(
    String quarter,
    double billed,
    double collected,
    double percent,
  ) {
    final Color color = percent >= 90
        ? context.appTheme.success
        : percent >= 75
        ? context.appTheme.warning
        : context.appTheme.error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                quarter,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${percent.toStringAsFixed(1)}%',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 8,
              backgroundColor: context.appTheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Billed: ₹${(billed / 1000).toStringAsFixed(0)}K',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: context.appTheme.muted,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Collected: ₹${(collected / 1000).toStringAsFixed(0)}K',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: context.appTheme.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStaffTab() {
    final activeStaff = _staffRows
        .where((s) => '${s['status'] ?? ''}'.toLowerCase() == 'active')
        .length;
    final inactiveStaff = _staffRows.length - activeStaff;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Staff Report — ${DateFormat('MMMM yyyy').format(DateTime.now())}',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton.icon(
              onPressed: () => _showExportDialog('CSV'),
              icon: const Icon(Icons.download_rounded, size: 14),
              label: const Text('Export'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                'Total Staff',
                '$_totalStaff',
                Icons.people_rounded,
                context.appTheme.primary,
                context.appTheme.primaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                'Present Today',
                '$activeStaff',
                Icons.how_to_reg_rounded,
                context.appTheme.success,
                context.appTheme.successContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                'On Leave',
                '0',
                Icons.event_busy_rounded,
                context.appTheme.warning,
                context.appTheme.warningContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildKpiCard(
                'Absent',
                '$inactiveStaff',
                Icons.person_off_rounded,
                context.appTheme.error,
                context.appTheme.errorContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Staff Records',
          style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        if (_staffRows.isEmpty)
          Text(
            'Backend staff records will appear here.',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: context.appTheme.muted,
            ),
          )
        else
          ..._staffRows.map(
            (staff) => _buildDeptRow(
              '${staff['designation'] ?? staff['name'] ?? 'Staff'}',
              1,
              context.appTheme.primary,
            ),
          ),
        const SizedBox(height: 16),
        Text(
          'Leave Summary — ${DateFormat('MMMM yyyy').format(DateTime.now())}',
          style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Text(
          'Backend leave summary rows will appear here.',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: context.appTheme.muted,
          ),
        ),
      ],
    );
  }

  Widget _buildDeptRow(String dept, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(dept, style: GoogleFonts.dmSans(fontSize: 12)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: count / 10,
                minHeight: 8,
                backgroundColor: context.appTheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(
    String title,
    String value,
    IconData icon,
    Color color,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                title,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: context.appTheme.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportButton(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return GestureDetector(
      onTap: () => _showExportDialog('PDF', reportTitle: title),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appTheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: context.appTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.download_rounded,
              size: 18,
              color: context.appTheme.muted,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExportDialog(String format, {String? reportTitle}) async {
    if (format == 'PDF') {
      final recorded = await _requestReportExport(
        format,
        reportTitle: reportTitle,
      );
      if (recorded) {
        await _generateAndPrintReport(reportTitle: reportTitle);
      }
      return;
    }
    await _requestReportExport(format, reportTitle: reportTitle);
  }

  Future<bool> _requestReportExport(
    String format, {
    String? reportTitle,
  }) async {
    try {
      final export = await BackendApiClient.instance.createReportExport(
        '/reports/exports',
        reportTitle: reportTitle ?? 'Principal reports and analytics',
        format: format,
        scope: 'principal',
        parameters: {
          'month': DateFormat('yyyy-MM').format(DateTime.now()),
          'total_students': _totalStudents,
          'total_staff': _totalStaff,
          'total_billed': _totalBilled,
          'total_collected': _totalCollected,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Report export ${export['status'] ?? 'requested'} · ${export['download_url'] ?? ''}',
            ),
          ),
        );
      }
      return true;
    } on Object catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report export request failed: $e'),
          backgroundColor: context.appTheme.error,
        ),
      );
      return false;
    }
  }

  Future<void> _generateAndPrintReport({String? reportTitle}) async {
    try {
      final pdfService = PdfService.getInstance();
      final period = DateFormat('MMMM yyyy').format(DateTime.now());
      final title = reportTitle ?? 'Principal reports and analytics';
      final pdfBytes = await pdfService.generatePrincipalSummaryReport(
        reportTitle: title,
        period: period,
        totalStudents: _totalStudents,
        totalStaff: _totalStaff,
        attendanceAverage: _attendanceAverageLabel(),
        totalBilled: _totalBilled,
        totalCollected: _totalCollected,
        staffRows: _staffRows,
      );
      await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: '${title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}_$period',
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to generate PDF. Please try again.'),
          ),
        );
      }
    }
  }
}
