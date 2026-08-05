import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:schooldesk1/core/constants/app_constants.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/backend_data_service.dart';
import 'package:schooldesk1/core/services/pdf_service.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';

class ReportsAnalyticsScreen extends StatefulWidget {
  const ReportsAnalyticsScreen({super.key});

  @override
  State<ReportsAnalyticsScreen> createState() => _ReportsAnalyticsScreenState();
}

class _ReportsAnalyticsScreenState extends State<ReportsAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  int _selectedDrawerIndex = PrincipalNav.reports;
  late TabController _tabController;

  double _totalBilled = 0;
  double _totalCollected = 0;
  int _totalStudents = 0;
  int _totalStaff = 0;
  int _onLeaveCount = 0;
  String _schoolName = AppConstants.schoolName;
  String _schoolAddress = AppConstants.schoolAddress;
  String _academicYearLabel = AppConstants.academicYear;
  Uint8List? _schoolLogo;
  List<Map<String, dynamic>> _feeInvoices = [];
  List<Map<String, dynamic>> _attendanceRows = [];
  List<Map<String, dynamic>> _staffRows = [];
  List<Map<String, dynamic>> _complaintRows = [];
  List<StaffAttendanceModel> _staffAttendance = [];
  Set<String> _staffOnLeaveIds = const {};
  bool _isLoading = true;
  String? _loadError;
  String? _exportingReport;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final storage = await BackendDataService.getInstance();
      final invoices = await _safeList(
        storage.getList(BackendDataService.kStudentFees),
      );
      final students = await _safeList(
        storage.getList(BackendDataService.kStudents),
      );
      final staffRows = await _safeList(
        storage.getList(BackendDataService.kAdminTeachers),
      );
      final attendanceRows = await _safeList(
        storage.getList(BackendDataService.kAdminAttendanceRecords),
      );
      final complaintRows = await _safeList(
        storage.getList(BackendDataService.kComplaints),
      );
      final years = await _safeList(
        storage.getList(BackendDataService.kAcademicYears),
      );
      final school = await _safeSchool();
      final staffAttendance = await _safeStaffAttendance();
      final staffSummary = await _safeStaffSummary();
      final staffOnLeaveIds = await _safeStaffOnLeaveIds();

      var billed = 0.0;
      var collected = 0.0;
      for (final invoice in invoices) {
        billed += _invoiceTotal(invoice);
        collected += _invoicePaid(invoice);
      }

      final currentYear = years.where((year) {
        final status = _text(year['status']).toLowerCase();
        return year['is_current'] == true || status == 'active';
      }).toList();
      final schoolName = _text(
        school['name'],
        fallback: AppConstants.schoolName,
      );
      final address = _buildSchoolAddress(school);
      final logo = await _networkImageBytes(_text(school['logo_url']));

      if (!mounted) return;
      setState(() {
        _totalBilled = billed;
        _totalCollected = collected;
        _totalStudents = students.length;
        _totalStaff = staffRows.length;
        _feeInvoices = invoices;
        _staffRows = staffRows;
        _attendanceRows = attendanceRows;
        _complaintRows = complaintRows;
        _staffAttendance = staffAttendance;
        _staffOnLeaveIds = staffOnLeaveIds;
        _schoolName = schoolName;
        _schoolAddress = address.isEmpty ? AppConstants.schoolAddress : address;
        _schoolLogo = logo;
        _academicYearLabel = currentYear.isEmpty
            ? AppConstants.academicYear
            : _text(
                currentYear.first['year_label'] ?? currentYear.first['name'],
                fallback: AppConstants.academicYear,
              );
        _onLeaveCount = staffOnLeaveIds.isEmpty
            ? _staffLeaveCount(staffSummary)
            : staffOnLeaveIds
                  .where(
                    (staffId) => !staffAttendance.any(
                      (row) => row.staffId == staffId && row.checkedIn,
                    ),
                  )
                  .length;
        _loadError = null;
        _isLoading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Unable to load reports: $error';
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _safeList(
    Future<List<Map<String, dynamic>>> request,
  ) async {
    try {
      return await request;
    } on Object {
      return const [];
    }
  }

  Future<Map<String, dynamic>> _safeSchool() async {
    try {
      return await BackendApiClient.instance.getCurrentSchool();
    } on Object {
      return const {};
    }
  }

  Future<List<StaffAttendanceModel>> _safeStaffAttendance() async {
    try {
      return await BackendApiClient.instance.getStaffAttendanceForDate(
        date: _dateKey(DateTime.now()),
      );
    } on Object {
      return const [];
    }
  }

  Future<Map<String, dynamic>> _safeStaffSummary() async {
    try {
      return await BackendApiClient.instance.getStaffDailyAttendanceSummary(
        date: _dateKey(DateTime.now()),
      );
    } on Object {
      return const {};
    }
  }

  Future<Set<String>> _safeStaffOnLeaveIds() async {
    try {
      final today = DateUtils.dateOnly(DateTime.now());
      final applications = await BackendApiClient.instance.getLeaveApplications(
        status: 'approved',
      );
      return applications
          .where((application) {
            final from = DateTime.tryParse(application.fromDate);
            final to = DateTime.tryParse(application.toDate);
            if (from == null || to == null) return false;
            final firstDay = DateUtils.dateOnly(from.toLocal());
            final lastDay = DateUtils.dateOnly(to.toLocal());
            return !today.isBefore(firstDay) && !today.isAfter(lastDay);
          })
          .map((application) => application.staffId)
          .toSet();
    } on Object {
      return const {};
    }
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
        onDestinationSelected: (index) =>
            setState(() => _selectedDrawerIndex = index),
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.principal,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Attendance'),
          Tab(text: 'Fee'),
          Tab(text: 'Staff'),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (_isLoading) {
            return Center(
              child: Semantics(
                label: 'Loading reports',
                child: const CircularProgressIndicator(),
              ),
            );
          }
          if (_loadError != null) return _buildLoadError();
          final content = TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              _buildAttendanceTab(),
              _buildFeeTab(),
              _buildStaffTab(),
            ],
          );
          if (constraints.maxWidth < 840) return content;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: content,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: context.appTheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              _loadError ?? 'Reports are unavailable.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry loading reports'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPageHeading(
          'School Overview - ${DateFormat('MMMM yyyy').format(DateTime.now())}',
          '$_schoolName - Academic Year $_academicYearLabel',
          exportTitle: 'School Overview',
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 560;
            final cards = [
              _buildKpiCard(
                'Total Students',
                '$_totalStudents',
                Icons.school_rounded,
                context.appTheme.primary,
                context.appTheme.primaryContainer,
              ),
              _buildKpiCard(
                'Total Staff',
                '$_totalStaff',
                Icons.people_rounded,
                context.appTheme.secondary,
                context.appTheme.secondaryContainer,
              ),
              _buildKpiCard(
                'Average Attendance',
                _attendanceAverageLabel(),
                Icons.how_to_reg_rounded,
                context.appTheme.success,
                context.appTheme.successContainer,
              ),
              _buildKpiCard(
                'Fee Collection',
                _collectionRateLabel(),
                Icons.account_balance_wallet_rounded,
                context.appTheme.info,
                context.appTheme.infoContainer,
              ),
            ];
            if (wide) {
              return GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 3.2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: cards,
              );
            }
            return Column(
              children: [
                for (var index = 0; index < cards.length; index++) ...[
                  cards[index],
                  if (index < cards.length - 1) const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        Text(
          'Quick Reports',
          style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _buildReportButton(
          'Monthly Attendance Report',
          DateFormat('MMMM yyyy').format(DateTime.now()),
          Icons.calendar_month_rounded,
          context.appTheme.primary,
        ),
        _buildReportButton(
          'Fee Collection Summary',
          _academicYearLabel,
          Icons.receipt_long_rounded,
          context.appTheme.secondary,
        ),
        _buildReportButton(
          'Staff Attendance Report',
          DateFormat('dd MMM yyyy').format(DateTime.now()),
          Icons.badge_rounded,
          context.appTheme.success,
        ),
        _buildReportButton(
          'Complaint Summary',
          DateFormat('MMMM yyyy').format(DateTime.now()),
          Icons.support_agent_rounded,
          context.appTheme.warning,
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _exportingReport == null
              ? () => _showExportDialog(reportTitle: 'School Overview')
              : null,
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: Text(
            _exportingReport == 'School Overview'
                ? 'Preparing school overview...'
                : 'Export school overview PDF',
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceTab() {
    final rows = _attendanceClassRows;
    final lowAttendance = _attendanceRows.where((row) {
      final total = _number(row['total']);
      final present = _number(row['present']);
      final percent = total > 0 ? present / total * 100 : 0;
      return total > 0 && percent < 75;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPageHeading(
          'Class-wise Attendance - ${DateFormat('MMMM yyyy').format(DateTime.now())}',
          'Grouped from student attendance summaries',
          exportTitle: 'Monthly Attendance Report',
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          _buildEmptyState(
            Icons.fact_check_outlined,
            'No attendance data',
            'Attendance summaries will appear here after records are available.',
          )
        else
          ...rows.map(_buildAttendanceRow),
        const SizedBox(height: 12),
        _buildSummaryCard(
          label: 'School average',
          value: _attendanceAverageLabel(),
          color: context.appTheme.primary,
        ),
        const SizedBox(height: 20),
        Text(
          'Students Below 75% Attendance',
          style: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.appTheme.error,
          ),
        ),
        const SizedBox(height: 8),
        if (lowAttendance.isEmpty)
          Text(
            'No students are below 75% in the loaded attendance data.',
            style: GoogleFonts.dmSans(color: context.appTheme.muted),
          )
        else
          ...lowAttendance.map(
            (row) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.warning_amber_rounded,
                color: context.appTheme.error,
              ),
              title: Text(_text(row['student_name'], fallback: 'Student')),
              subtitle: Text(
                '${_text(row['class'], fallback: 'Unassigned')} - ${_number(row['present']).toInt()}/${_number(row['total']).toInt()} days',
              ),
              trailing: Text(
                '${(_number(row['total']) > 0 ? _number(row['present']) / _number(row['total']) * 100 : 0).toStringAsFixed(1)}%',
                style: TextStyle(
                  color: context.appTheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAttendanceRow(Map<String, dynamic> row) {
    final total = _number(row['total']);
    final present = _number(row['present']);
    final percent = total > 0 ? (present / total * 100).clamp(0, 100) : 0.0;
    final color = percent >= 90
        ? context.appTheme.success
        : percent >= 75
        ? context.appTheme.warning
        : context.appTheme.error;
    final label = _text(row['class'], fallback: 'Unassigned');

    return Semantics(
      container: true,
      label:
          '$label attendance ${percent.toStringAsFixed(1)} percent, ${present.toInt()} present out of ${total.toInt()}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.appTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appTheme.outlineVariant),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: percent / 100,
                  minHeight: 9,
                  backgroundColor: context.appTheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${present.toInt()}/${total.toInt()}',
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
      ),
    );
  }

  Widget _buildFeeTab() {
    final periods = _feePeriodRows;
    final outstanding = (_totalBilled - _totalCollected)
        .clamp(0, double.infinity)
        .toDouble();
    final collectionRate = _collectionRateLabel();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPageHeading(
          'Fee Collection Report - $_academicYearLabel',
          'Invoice totals grouped by the period stored on each invoice',
          exportTitle: 'Fee Collection Summary',
        ),
        const SizedBox(height: 12),
        if (periods.isEmpty)
          _buildEmptyState(
            Icons.receipt_long_outlined,
            'No fee data',
            'Fee invoices will appear here after they are generated.',
          )
        else
          ...periods.map(
            (period) => _buildFeePeriodCard(
              _text(period['label'], fallback: 'Academic year'),
              _number(period['billed']),
              _number(period['collected']),
            ),
          ),
        const SizedBox(height: 12),
        _buildSummaryCard(
          label: 'Annual total billed',
          value: _formatInr(_totalBilled),
          color: context.appTheme.primary,
          secondaryRows: [
            (
              'Total collected',
              _formatInr(_totalCollected),
              context.appTheme.success,
            ),
            ('Outstanding', _formatInr(outstanding), context.appTheme.error),
            ('Collection rate', collectionRate, context.appTheme.info),
          ],
        ),
      ],
    );
  }

  Widget _buildFeePeriodCard(String label, double billed, double collected) {
    final percent = billed > 0 ? (collected / billed * 100).clamp(0, 100) : 0.0;
    final color = percent >= 90
        ? context.appTheme.success
        : percent >= 75
        ? context.appTheme.warning
        : context.appTheme.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${percent.toStringAsFixed(1)}%',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            label:
                '$label fee collection ${percent.toStringAsFixed(1)} percent',
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 9,
              backgroundColor: context.appTheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              Text('Billed: ${_formatInr(billed)}'),
              Text(
                'Collected: ${_formatInr(collected)}',
                style: TextStyle(color: context.appTheme.success),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStaffTab() {
    final present = _staffPresentCount;
    final absent = (_totalStaff - present - _onLeaveCount).clamp(
      0,
      _totalStaff,
    );
    final attendanceByStaff = {
      for (final row in _staffAttendance) row.staffId: row,
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPageHeading(
          'Staff Report - ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
          'Based on today\'s staff attendance records',
          exportTitle: 'Staff Attendance Report',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              _buildKpiCard(
                'Total Staff',
                '$_totalStaff',
                Icons.people_rounded,
                context.appTheme.primary,
                context.appTheme.primaryContainer,
              ),
              _buildKpiCard(
                'Present Today',
                '$present',
                Icons.how_to_reg_rounded,
                context.appTheme.success,
                context.appTheme.successContainer,
              ),
              _buildKpiCard(
                'On Leave',
                '$_onLeaveCount',
                Icons.event_busy_rounded,
                context.appTheme.warning,
                context.appTheme.warningContainer,
              ),
              _buildKpiCard(
                'Absent / Not Recorded',
                '$absent',
                Icons.person_off_rounded,
                context.appTheme.error,
                context.appTheme.errorContainer,
              ),
            ];
            return GridView.count(
              crossAxisCount: constraints.maxWidth >= 560 ? 2 : 1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 10,
              childAspectRatio: constraints.maxWidth >= 560 ? 3.2 : 4.2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: cards,
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          'Staff Records',
          style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (_staffRows.isEmpty)
          _buildEmptyState(
            Icons.badge_outlined,
            'No staff records',
            'Staff records will appear here when available.',
          )
        else
          ..._staffRows.map(
            (staff) => _buildStaffRecordRow(
              staff,
              attendanceByStaff[_text(staff['id'])],
            ),
          ),
        const SizedBox(height: 20),
        Text(
          'Leave Summary',
          style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          _onLeaveCount == 0
              ? 'No staff leave records were reported for today.'
              : '$_onLeaveCount staff member${_onLeaveCount == 1 ? '' : 's'} are on leave today.',
          style: GoogleFonts.dmSans(color: context.appTheme.muted),
        ),
      ],
    );
  }

  Widget _buildStaffRecordRow(
    Map<String, dynamic> staff,
    StaffAttendanceModel? attendance,
  ) {
    final name = _text(
      staff['name'],
      fallback: _text(staff['full_name'], fallback: 'Staff member'),
    );
    final designation = _text(staff['designation'], fallback: 'Staff');
    final present = attendance?.checkedIn == true;
    final onLeave = !present && _staffOnLeaveIds.contains(_text(staff['id']));
    final status = present
        ? 'Present'
        : onLeave
        ? 'On leave'
        : 'Absent / not recorded';
    final color = present
        ? context.appTheme.success
        : onLeave
        ? context.appTheme.warning
        : context.appTheme.muted;
    return Semantics(
      container: true,
      label: '$name, $designation, $status',
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(24),
          child: Icon(Icons.badge_outlined, color: color),
        ),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '$designation · ${attendance?.checkInTimeLabel ?? 'No check-in'}',
        ),
        trailing: Text(
          status,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildPageHeading(
    String title,
    String subtitle, {
    required String exportTitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: context.appTheme.muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: 'Export $exportTitle as PDF',
          child: TextButton.icon(
            onPressed: _exportingReport == null
                ? () => _showExportDialog(reportTitle: exportTitle)
                : null,
            icon: _exportingReport == exportTitle
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded, size: 17),
            label: Text(
              _exportingReport == exportTitle ? 'Preparing' : 'Export',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required Color color,
    List<(String, String, Color)> secondaryRows = const [],
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appTheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _summaryRow(label, value, color, strong: true),
          for (final row in secondaryRows) ...[
            const SizedBox(height: 8),
            _summaryRow(row.$1, row.$2, row.$3),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value,
    Color color, {
    bool strong = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: strong ? 14 : 13,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: strong ? 16 : 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: context.appTheme.muted),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.appTheme.muted),
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
    Color background,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: context.appTheme.muted,
                  ),
                ),
              ],
            ),
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
    final busy = _exportingReport == title;
    return Semantics(
      button: true,
      label: 'Generate $title for $subtitle',
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: context.appTheme.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _exportingReport == null
                ? () => _showExportDialog(reportTitle: title)
                : null,
            child: Container(
              constraints: const BoxConstraints(minHeight: 72),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.appTheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 21, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
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
                  if (busy)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      Icons.download_rounded,
                      size: 20,
                      color: context.appTheme.muted,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showExportDialog({required String reportTitle}) async {
    if (_exportingReport != null) return;
    setState(() => _exportingReport = reportTitle);
    try {
      await _generateAndPreviewReport(reportTitle: reportTitle);
      await _recordSupportedBackendExport(reportTitle);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$reportTitle PDF is ready.')));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to generate $reportTitle: $error'),
          backgroundColor: context.appTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _exportingReport = null);
    }
  }

  Future<void> _recordSupportedBackendExport(String reportTitle) async {
    final lower = reportTitle.toLowerCase();
    if (lower.contains('staff')) return;
    if (lower.contains('attendance')) {
      await BackendApiClient.instance.createReportExport(
        '/attendance/reports/exports',
        reportTitle: reportTitle,
        reportType: 'attendance',
        format: 'pdf',
        scope: 'principal_reports',
        parameters: {'month': _dateKey(DateTime.now())},
      );
    } else if (lower.contains('fee')) {
      await BackendApiClient.instance.createReportExport(
        '/fees/reports/exports',
        reportTitle: reportTitle,
        reportType: 'complete_fees_report',
        format: 'pdf',
        scope: 'principal_reports',
        parameters: {'academic_year': _academicYearLabel},
      );
    }
  }

  Future<void> _generateAndPreviewReport({required String reportTitle}) async {
    final lower = reportTitle.toLowerCase();
    final isStaffReport = lower.contains('staff');
    final isAttendanceReport = lower.contains('attendance') && !isStaffReport;
    final pdfService = PdfService.getInstance();
    final tables = <Map<String, dynamic>>[];
    List<Map<String, dynamic>> metrics;

    if (isAttendanceReport) {
      final rows = _attendanceClassRows;
      metrics = [
        {'label': 'Classes', 'value': '${rows.length}'},
        {'label': 'Students', 'value': '$_totalStudents'},
        {'label': 'Average', 'value': _attendanceAverageLabel()},
      ];
      tables.add({
        'title': 'Attendance by class / section',
        'headers': [
          'Class / section',
          'Students',
          'Present',
          'Absent',
          'Attendance',
        ],
        'rows': rows
            .map(
              (row) => [
                _text(row['class'], fallback: 'Unassigned'),
                '${_number(row['students']).toInt()}',
                '${_number(row['present']).toInt()}',
                '${(_number(row['total']) - _number(row['present'])).clamp(0, double.infinity).toInt()}',
                '${_number(row['percent']).toStringAsFixed(1)}%',
              ],
            )
            .toList(),
        'weights': [2.3, 1, 1, 1, 1.2],
      });
    } else if (lower.contains('fee')) {
      final rows = _feePeriodRows;
      metrics = [
        {'label': 'Invoices', 'value': '${_feeInvoices.length}'},
        {'label': 'Billed', 'value': _formatInr(_totalBilled)},
        {'label': 'Collected', 'value': _formatInr(_totalCollected)},
        {
          'label': 'Outstanding',
          'value': _formatInr(_totalBilled - _totalCollected),
        },
      ];
      tables.add({
        'title': 'Fee collection by period',
        'headers': ['Period', 'Billed', 'Collected', 'Outstanding', 'Rate'],
        'rows': rows
            .map(
              (row) => [
                _text(row['label'], fallback: 'Academic year'),
                _formatInr(_number(row['billed'])),
                _formatInr(_number(row['collected'])),
                _formatInr(_number(row['billed']) - _number(row['collected'])),
                '${_number(row['percent']).toStringAsFixed(1)}%',
              ],
            )
            .toList(),
        'weights': [2.2, 1.3, 1.3, 1.3, 1],
      });
      tables.add(_feeInvoiceTable());
    } else if (lower.contains('staff')) {
      final rows = _staffReportRows;
      metrics = [
        {'label': 'Total staff', 'value': '$_totalStaff'},
        {'label': 'Present', 'value': '$_staffPresentCount'},
        {'label': 'On leave', 'value': '$_onLeaveCount'},
        {
          'label': 'Absent / unrecorded',
          'value':
              '${(_totalStaff - _staffPresentCount - _onLeaveCount).clamp(0, _totalStaff)}',
        },
      ];
      tables.add({
        'title': 'Staff attendance records',
        'headers': [
          'Staff member',
          'Designation',
          'Status',
          'Check-in',
          'Check-out',
        ],
        'rows': rows
            .map(
              (row) => [
                _text(row['name'], fallback: 'Staff member'),
                _text(row['designation'], fallback: 'Staff'),
                _text(row['status'], fallback: 'Not recorded'),
                _text(row['check_in'], fallback: '--:--'),
                _text(row['check_out'], fallback: '--:--'),
              ],
            )
            .toList(),
        'weights': [2.2, 1.5, 1.4, 1, 1],
      });
    } else if (lower.contains('complaint')) {
      metrics = [
        {'label': 'Total complaints', 'value': '${_complaintRows.length}'},
        {
          'label': 'Open',
          'value':
              '${_complaintRows.where((row) => _complaintStatus(row) == 'open').length}',
        },
        {
          'label': 'Resolved',
          'value':
              '${_complaintRows.where((row) => _complaintStatus(row) == 'resolved').length}',
        },
      ];
      tables.add({
        'title': 'Complaint records',
        'headers': ['Submitted', 'Subject', 'Category', 'Status', 'Raised by'],
        'rows': _complaintRows
            .map(
              (row) => [
                _dateLabel(row['created_at'] ?? row['submitted_at']),
                _text(row['subject'] ?? row['title'], fallback: 'Complaint'),
                _text(row['category'], fallback: 'General'),
                _text(row['status'], fallback: 'Open'),
                _text(row['raised_by'] ?? row['created_by'], fallback: '—'),
              ],
            )
            .toList(),
        'weights': [1.1, 2.3, 1.3, 1.1, 1.5],
      });
    } else {
      metrics = [
        {'label': 'Students', 'value': '$_totalStudents'},
        {'label': 'Staff', 'value': '$_totalStaff'},
        {'label': 'Attendance', 'value': _attendanceAverageLabel()},
        {'label': 'Fee collection', 'value': _collectionRateLabel()},
      ];
      tables.add(_attendanceTable());
      tables.add(_feePeriodTable());
    }

    final period = lower.contains('fee')
        ? _academicYearLabel
        : DateFormat('MMMM yyyy').format(DateTime.now());
    final bytes = await pdfService.generateStructuredReport(
      reportTitle: reportTitle,
      period: period,
      scope: '$_schoolName · branch-scoped report',
      schoolName: _schoolName,
      schoolAddress: _schoolAddress,
      schoolLogo: _schoolLogo,
      metrics: metrics,
      tables: tables,
    );
    if (!mounted) return;
    await pdfService.previewDocument(
      context,
      bytes,
      '${reportTitle.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}_${_dateKey(DateTime.now())}.pdf',
    );
  }

  Map<String, dynamic> _attendanceTable() => {
    'title': 'Attendance by class / section',
    'headers': [
      'Class / section',
      'Students',
      'Present',
      'Absent',
      'Attendance',
    ],
    'rows': _attendanceClassRows
        .map(
          (row) => [
            _text(row['class'], fallback: 'Unassigned'),
            '${_number(row['students']).toInt()}',
            '${_number(row['present']).toInt()}',
            '${(_number(row['total']) - _number(row['present'])).clamp(0, double.infinity).toInt()}',
            '${_number(row['percent']).toStringAsFixed(1)}%',
          ],
        )
        .toList(),
    'weights': [2.3, 1, 1, 1, 1.2],
  };

  Map<String, dynamic> _feePeriodTable() => {
    'title': 'Fee collection by period',
    'headers': ['Period', 'Billed', 'Collected', 'Outstanding', 'Rate'],
    'rows': _feePeriodRows
        .map(
          (row) => [
            _text(row['label'], fallback: 'Academic year'),
            _formatInr(_number(row['billed'])),
            _formatInr(_number(row['collected'])),
            _formatInr(_number(row['billed']) - _number(row['collected'])),
            '${_number(row['percent']).toStringAsFixed(1)}%',
          ],
        )
        .toList(),
    'weights': [2.2, 1.3, 1.3, 1.3, 1],
  };

  Map<String, dynamic> _feeInvoiceTable() => {
    'title': 'Student fee invoices',
    'headers': [
      'Invoice',
      'Student',
      'Billed',
      'Collected',
      'Balance',
      'Status',
    ],
    'rows': _feeInvoices
        .map(
          (invoice) => [
            _text(invoice['invoice_number'], fallback: '—'),
            _text(
              invoice['student_name'] ?? invoice['name'],
              fallback: 'Student',
            ),
            _formatInr(_invoiceTotal(invoice)),
            _formatInr(_invoicePaid(invoice)),
            _formatInr(_invoiceBalance(invoice)),
            _text(invoice['status'], fallback: 'Pending'),
          ],
        )
        .toList(),
    'weights': [1.3, 2, 1.2, 1.2, 1.2, 1.1],
  };

  List<Map<String, dynamic>> get _attendanceClassRows {
    final grouped = <String, Map<String, dynamic>>{};
    for (final row in _attendanceRows) {
      final label = _text(row['class'], fallback: 'Unassigned');
      final entry = grouped.putIfAbsent(
        label,
        () => {'class': label, 'students': 0, 'present': 0.0, 'total': 0.0},
      );
      entry['students'] = (entry['students'] as int) + 1;
      entry['present'] = (entry['present'] as double) + _number(row['present']);
      entry['total'] = (entry['total'] as double) + _number(row['total']);
    }
    return grouped.values.map((row) {
      final total = row['total'] as double;
      final present = row['present'] as double;
      return {...row, 'percent': total > 0 ? present / total * 100 : 0.0};
    }).toList()..sort((a, b) => _text(a['class']).compareTo(_text(b['class'])));
  }

  List<Map<String, dynamic>> get _feePeriodRows {
    final grouped = <String, Map<String, dynamic>>{};
    for (final invoice in _feeInvoices) {
      final period = _text(
        invoice['term_name'] ??
            invoice['term'] ??
            invoice['installment_name'] ??
            invoice['installment'] ??
            invoice['billing_period'],
        fallback: 'Academic year total',
      );
      final entry = grouped.putIfAbsent(
        period,
        () => {'label': period, 'billed': 0.0, 'collected': 0.0},
      );
      entry['billed'] = (entry['billed'] as double) + _invoiceTotal(invoice);
      entry['collected'] =
          (entry['collected'] as double) + _invoicePaid(invoice);
    }
    return grouped.values.map((row) {
      final billed = row['billed'] as double;
      final collected = row['collected'] as double;
      return {...row, 'percent': billed > 0 ? collected / billed * 100 : 0.0};
    }).toList()..sort((a, b) => _text(a['label']).compareTo(_text(b['label'])));
  }

  List<Map<String, dynamic>> get _staffReportRows {
    final attendanceByStaff = {
      for (final row in _staffAttendance) row.staffId: row,
    };
    return _staffRows.map((staff) {
      final attendance = attendanceByStaff[_text(staff['id'])];
      final present = attendance?.checkedIn == true;
      final onLeave = !present && _staffOnLeaveIds.contains(_text(staff['id']));
      return {
        'name': _text(staff['name'], fallback: 'Staff member'),
        'designation': _text(staff['designation'], fallback: 'Staff'),
        'status': present
            ? 'Present'
            : onLeave
            ? 'On leave'
            : 'Absent / not recorded',
        'check_in': attendance?.checkInTimeLabel,
        'check_out': attendance?.checkOutTimeLabel,
      };
    }).toList();
  }

  int get _staffPresentCount =>
      _staffAttendance.where((row) => row.checkedIn).length;

  int _staffLeaveCount(Map<String, dynamic> summary) {
    for (final key in ['on_leave', 'onLeave', 'leave_count', 'leave']) {
      final value = int.tryParse('${summary[key] ?? ''}');
      if (value != null) return value;
    }
    return 0;
  }

  String _complaintStatus(Map<String, dynamic> row) =>
      _text(row['status'], fallback: 'open').toLowerCase().replaceAll(' ', '_');

  String _attendanceAverageLabel() {
    final rows = _attendanceClassRows;
    final total = rows.fold<double>(
      0,
      (sum, row) => sum + _number(row['total']),
    );
    final present = rows.fold<double>(
      0,
      (sum, row) => sum + _number(row['present']),
    );
    return total == 0 ? '0%' : '${(present / total * 100).toStringAsFixed(1)}%';
  }

  String _collectionRateLabel() {
    if (_totalBilled <= 0) return '0%';
    return '${(_totalCollected / _totalBilled * 100).toStringAsFixed(1)}%';
  }

  double _invoiceTotal(Map<String, dynamic> invoice) =>
      _number(invoice['net_amount'] ?? invoice['total_amount']);

  double _invoicePaid(Map<String, dynamic> invoice) {
    final reported = _number(invoice['paid_amount']);
    final payments = invoice['payments'];
    if (payments is! List) return reported;
    final finalized = payments.whereType<Map>().fold<double>(0, (sum, row) {
      final status = _text(row['status']).toLowerCase();
      if (const {
        'pending',
        'rejected',
        'failed',
        'cancelled',
        'canceled',
        'void',
        'voided',
        'refunded',
      }.contains(status)) {
        return sum;
      }
      return sum + _number(row['amount_paid'] ?? row['amount']);
    });
    return reported > finalized ? reported : finalized;
  }

  double _invoiceBalance(Map<String, dynamic> invoice) {
    final reported = _number(invoice['balance']);
    final calculated = (_invoiceTotal(invoice) - _invoicePaid(invoice))
        .clamp(0, double.infinity)
        .toDouble();
    return reported > 0 ? reported : calculated;
  }

  String _formatInr(double value) =>
      '₹${NumberFormat.decimalPattern('en_IN').format(value.round())}';

  double _number(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }

  String _text(Object? value, {String fallback = ''}) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' || text == 'undefined'
        ? fallback
        : text;
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _dateLabel(Object? value) {
    final parsed = DateTime.tryParse('${value ?? ''}');
    return parsed == null ? _text(value, fallback: '—') : _dateKey(parsed);
  }

  String _buildSchoolAddress(Map<String, dynamic> school) => [
    school['address'],
    school['address_line1'],
    school['address_line2'],
    school['city'],
    school['state'],
    school['postal_code'],
  ].map(_text).where((value) => value.isNotEmpty).toSet().join(', ');

  Future<Uint8List?> _networkImageBytes(String url) async {
    if (url.trim().isEmpty) return null;
    try {
      return (await NetworkAssetBundle(
        Uri.parse(url),
      ).load(url)).buffer.asUint8List();
    } on Object {
      return null;
    }
  }
}
