import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_module_scaffold.dart';
import '../../services/backend_data_service.dart';

class PrincipalAnalyticsScreen extends StatefulWidget {
  const PrincipalAnalyticsScreen({super.key});

  @override
  State<PrincipalAnalyticsScreen> createState() =>
      _PrincipalAnalyticsScreenState();
}

class _PrincipalAnalyticsScreenState extends State<PrincipalAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _attendancePeriod = 'This Week';

  double _totalBilled = 0;
  double _totalCollected = 0;
  bool _isLoading = true;
  String? _loadError;
  List<Map<String, dynamic>> _feeInvoices = [];
  List<Map<String, dynamic>> _runtimeAlerts = [];
  List<Map<String, dynamic>> _staffRows = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final storage = await BackendDataService.getInstance();
      final invoices = await storage.getList(BackendDataService.kStudentFees);

      double billed = 0;
      double collected = 0;
      for (final inv in invoices) {
        billed += _invoiceTotal(inv);
        collected += _numValue(inv['paid_amount']);
      }
      final notifications = await storage.getList(
        BackendDataService.kRuntimeNotifications,
      );
      final staffRows = await storage.getList(
        BackendDataService.kAdminTeachers,
      );

      if (mounted) {
        setState(() {
          _totalBilled = billed;
          _totalCollected = collected;
          _feeInvoices = invoices;
          _runtimeAlerts = notifications;
          _staffRows = staffRows;
          _loadError = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '$e';
        _isLoading = false;
      });
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
      title: 'Analytics',
      subtitle: 'Monitor attendance, fee collection, staff signals, and alerts',
      drawer: PrincipalDrawer(selectedIndex: 11, onDestinationSelected: (_) {}),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.principal,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: const [
          Tab(text: 'Attendance'),
          Tab(text: 'Fee Collection'),
          Tab(text: 'Staff Performance'),
          Tab(text: 'Alerts'),
        ],
      ),
      body: MediaQuery.of(context).size.width >= 840
          ? _buildTabletLayout()
          : _buildPhoneLayout(),
    );
  }

  Widget _buildPhoneLayout() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildAttendanceTab(),
        _buildFeeTab(),
        _buildStaffTab(),
        _buildAlertsTab(),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return _buildPhoneLayout();
  }

  // ─── ATTENDANCE TAB ───────────────────────────────────────────────────────

  Widget _buildAttendanceTab() {
    final trendRows = _runtimeAlerts
        .where((row) => '${row['category'] ?? ''}' == 'attendance')
        .toList();
    final attendanceAverage = _attendanceAverageFromBackend();
    final staffPresent = _staffRows.isEmpty ? 0 : _staffRows.length;
    final absentToday = _runtimeAlerts
        .where((row) => '${row['type'] ?? ''}' == 'attendance_absence')
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary KPIs
          Row(
            children: [
              Expanded(
                child: _kpiCard(
                  'Avg Attendance',
                  '${attendanceAverage.toStringAsFixed(1)}%',
                  Icons.people_rounded,
                  AppTheme.primary,
                  null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _kpiCard(
                  'Staff Present',
                  '$staffPresent',
                  Icons.person_rounded,
                  const Color(0xFF1A6B4A),
                  null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _kpiCard(
                  'Absent Today',
                  '$absentToday',
                  Icons.person_off_rounded,
                  const Color(0xFFD4850A),
                  null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Period selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Attendance Trends',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _periodSelector(['This Week', 'This Month'], _attendancePeriod, (
                v,
              ) {
                setState(() => _attendancePeriod = v);
              }),
            ],
          ),
          const SizedBox(height: 12),

          // Bar chart
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Column(
              children: [
                Row(
                  children: [
                    _legendDot(AppTheme.primary, 'Students'),
                    const SizedBox(width: 16),
                    _legendDot(const Color(0xFF1A6B4A), 'Staff'),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 140,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: trendRows.map((d) {
                      final studentPct =
                          (d['students'] as num?)?.toDouble() ?? 0;
                      final staffPct = (d['staff'] as num?)?.toDouble() ?? 0;
                      final label = '${d['day'] ?? d['label'] ?? ''}';
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _bar(studentPct, 100, AppTheme.primary, 14),
                                  const SizedBox(width: 3),
                                  _bar(
                                    staffPct,
                                    100,
                                    const Color(0xFF1A6B4A),
                                    14,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                label,
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  color: AppTheme.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Class-wise breakdown
          Text(
            'Class-wise Attendance',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: _cardDecoration(),
            child: trendRows.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Backend class attendance records will appear here.',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppTheme.muted,
                      ),
                    ),
                  )
                : Column(
                    children: trendRows.asMap().entries.map((e) {
                      final d = e.value;
                      final isLast = e.key == trendRows.length - 1;
                      final pct =
                          (d['pct'] as num?)?.toDouble() ??
                          (d['students'] as num?)?.toDouble() ??
                          0;
                      final color = pct >= 90
                          ? AppTheme.success
                          : pct >= 85
                          ? AppTheme.warning
                          : AppTheme.error;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: isLast
                              ? null
                              : Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade100,
                                  ),
                                ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(
                                '${d['class'] ?? d['label'] ?? 'Class'}',
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: pct / 100,
                                      minHeight: 8,
                                      backgroundColor: color.withAlpha(30),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${d['present'] ?? 0}/${d['total'] ?? 0}',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 46,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${pct.toStringAsFixed(1)}%',
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  double _attendanceAverageFromBackend() {
    final rows = _runtimeAlerts
        .where((row) => '${row['category'] ?? ''}' == 'attendance')
        .toList();
    if (rows.isEmpty) return 0;
    final total = rows.fold<double>(
      0,
      (sum, row) => sum + ((row['students'] as num?)?.toDouble() ?? 0),
    );
    return total / rows.length;
  }

  Map<String, dynamic> _mapValue(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  double _numValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  double _invoiceTotal(Map<String, dynamic> invoice) {
    final net = _numValue(invoice['net_amount']);
    if (net > 0) return net;
    final total = _numValue(invoice['total_amount']);
    if (total > 0) return total;
    return _numValue(invoice['paid_amount']) + _numValue(invoice['balance']);
  }

  String _invoicePeriodLabel(Map<String, dynamic> invoice) {
    final academicYear = _mapValue(invoice['academic_year']);
    final academicYearLabel =
        '${academicYear['year_label'] ?? invoice['year_label'] ?? ''}'.trim();
    if (academicYearLabel.isNotEmpty) return academicYearLabel;

    final rawDate = '${invoice['invoice_date'] ?? invoice['due_date'] ?? ''}';
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return 'Unassigned';
    return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}';
  }

  String _invoiceClassLabel(Map<String, dynamic> invoice) {
    final student = _mapValue(invoice['student']);
    final section = _mapValue(student['current_section']);
    final grade = _mapValue(section['grade']);
    final gradeName =
        '${grade['grade_name'] ?? invoice['grade_name'] ?? invoice['class'] ?? ''}'
            .trim();
    final sectionName =
        '${section['section_name'] ?? invoice['section_name'] ?? ''}'.trim();
    if (gradeName.isNotEmpty && sectionName.isNotEmpty) {
      return '$gradeName $sectionName';
    }
    if (gradeName.isNotEmpty) return gradeName;
    final sectionId =
        '${student['current_section_id'] ?? invoice['section_id'] ?? ''}'
            .trim();
    return sectionId.isNotEmpty ? sectionId : 'Unassigned';
  }

  List<Map<String, dynamic>> _groupInvoicesBy(
    String Function(Map<String, dynamic>) labelFor,
  ) {
    final buckets = <String, Map<String, dynamic>>{};
    for (final invoice in _feeInvoices) {
      final label = labelFor(invoice);
      final bucket = buckets.putIfAbsent(
        label,
        () => {
          'label': label,
          'class': label,
          'collected': 0.0,
          'pending': 0.0,
          'total': 0.0,
          'pct': 0.0,
        },
      );
      final collected = _numValue(invoice['paid_amount']);
      final pending = _numValue(invoice['balance']);
      final total = _invoiceTotal(invoice);
      bucket['collected'] = (bucket['collected'] as double) + collected;
      bucket['pending'] = (bucket['pending'] as double) + pending;
      bucket['total'] = (bucket['total'] as double) + total;
    }

    final rows = buckets.values.map((bucket) {
      final total = bucket['total'] as double;
      final collected = bucket['collected'] as double;
      return {...bucket, 'pct': total > 0 ? (collected / total) * 100 : 0.0};
    }).toList();
    rows.sort((a, b) => '${a['label']}'.compareTo('${b['label']}'));
    return rows;
  }

  // ─── FEE COLLECTION TAB ───────────────────────────────────────────────────

  Widget _buildFeeTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(child: Text('Unable to load fee analytics: $_loadError'));
    }

    final double pending = _totalBilled - _totalCollected;
    final double collectionRate = _totalBilled > 0
        ? (_totalCollected / _totalBilled) * 100
        : 0.0;
    final periodRows = _groupInvoicesBy(_invoicePeriodLabel);
    final feeRows = _groupInvoicesBy(_invoiceClassLabel);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary KPIs
          Row(
            children: [
              Expanded(
                child: _kpiCard(
                  'Total Collected',
                  '₹${(_totalCollected / 100000).toStringAsFixed(1)}L',
                  Icons.account_balance_wallet_rounded,
                  const Color(0xFF1A6B4A),
                  null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _kpiCard(
                  'Pending',
                  '₹${(pending / 100000).toStringAsFixed(1)}L',
                  Icons.pending_rounded,
                  const Color(0xFFD4850A),
                  null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _kpiCard(
                  'Collection Rate',
                  '${collectionRate.toStringAsFixed(1)}%',
                  Icons.trending_up_rounded,
                  AppTheme.primary,
                  null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Text(
            'Invoice Period Collection',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: _cardDecoration(),
            child: periodRows.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: Text('No fee invoices available')),
                  )
                : Column(
                    children: periodRows.asMap().entries.map((e) {
                      final d = e.value;
                      final isLast = e.key == periodRows.length - 1;
                      final pct = d['pct'] as double;
                      final color = pct >= 90
                          ? AppTheme.success
                          : pct >= 70
                          ? AppTheme.warning
                          : AppTheme.error;
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: isLast
                              ? null
                              : Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade100,
                                  ),
                                ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  d['label'] as String,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${pct.toStringAsFixed(1)}%',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: (pct / 100).clamp(0.0, 1.0),
                                minHeight: 10,
                                backgroundColor: color.withAlpha(25),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  color,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Collected: ₹${_formatLakh(d['collected'] as double)}',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  'Total: ₹${_formatLakh(d['total'] as double)}',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 20),

          Text(
            'Class-wise Fee Status',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: _cardDecoration(),
            child: feeRows.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: Text('No class fee records available'),
                    ),
                  )
                : Column(
                    children: feeRows.asMap().entries.map((e) {
                      final d = e.value;
                      final isLast = e.key == feeRows.length - 1;
                      final total =
                          (d['collected'] as double) + (d['pending'] as double);
                      final pct = total > 0
                          ? (d['collected'] as double) / total
                          : 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: isLast
                              ? null
                              : Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade100,
                                  ),
                                ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 70,
                              child: Text(
                                d['class'] as String,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Stack(
                                children: [
                                  Container(
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: AppTheme.error.withAlpha(30),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: pct.toDouble(),
                                    child: Container(
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: AppTheme.success,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${_formatLakh(d['collected'] as double)}',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.success,
                                  ),
                                ),
                                Text(
                                  '₹${_formatLakh(d['pending'] as double)} due',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 10,
                                    color: AppTheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── STAFF PERFORMANCE TAB ────────────────────────────────────────────────

  Widget _buildStaffTab() {
    final staffData = _staffRows
        .map(
          (t) => {
            'name': (t['name'] ?? 'Staff').toString(),
            'subject': (t['subject'] ?? t['designation'] ?? 'General')
                .toString(),
            'attendance': _optionalMetric(t, [
              'attendance',
              'attendance_percent',
            ]),
            'homeworkCompletion': _optionalMetric(t, [
              'homeworkCompletion',
              'homework_completion',
            ]),
            'parentFeedback': _optionalMetric(t, [
              'parentFeedback',
              'parent_feedback',
              'rating',
            ]),
            'lessonsCovered': _optionalMetric(t, [
              'lessonsCovered',
              'lessons_covered',
            ]),
            'status': (t['status'] ?? 'Active').toString(),
          },
        )
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary
          Row(
            children: [
              Expanded(
                child: _kpiCard(
                  'Total Staff',
                  '${staffData.length}',
                  Icons.people_rounded,
                  AppTheme.primary,
                  null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _kpiCard(
                  'Avg Rating',
                  'N/A',
                  Icons.star_rounded,
                  const Color(0xFFD4850A),
                  null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _kpiCard(
                  'Need Review',
                  '0',
                  Icons.warning_rounded,
                  AppTheme.error,
                  null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Text(
            'Staff Performance Overview',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),

          if (staffData.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No staff data available')),
            )
          else
            ...staffData.map((staff) => _buildStaffCard(staff)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStaffCard(Map<String, dynamic> staff) {
    final name = (staff['name'] as String).trim().isEmpty
        ? 'Staff'
        : staff['name'] as String;
    final status = (staff['status'] as String).trim();
    final statusColor = status.toLowerCase() == 'excellent'
        ? AppTheme.success
        : status.toLowerCase() == 'good'
        ? AppTheme.primary
        : status.toLowerCase() == 'active'
        ? AppTheme.success
        : AppTheme.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: statusColor.withAlpha(20),
                child: Text(
                  name.split(' ').last.substring(0, 1),
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      staff['subject'] as String,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _metricBar(
                  'Attendance',
                  staff['attendance'] as double?,
                  AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricBar(
                  'HW Completion',
                  staff['homeworkCompletion'] as double?,
                  const Color(0xFF1A6B4A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _metricBar(
                  'Lessons Covered',
                  staff['lessonsCovered'] as double?,
                  const Color(0xFF6C3483),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Parent Feedback',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        ...List.generate(5, (i) {
                          final rating = staff['parentFeedback'] as double?;
                          return Icon(
                            rating != null && i < rating.floor()
                                ? Icons.star_rounded
                                : (rating != null && i < rating
                                      ? Icons.star_half_rounded
                                      : Icons.star_outline_rounded),
                            size: 14,
                            color: const Color(0xFFD4850A),
                          );
                        }),
                        const SizedBox(width: 4),
                        Text(
                          staff['parentFeedback'] == null
                              ? 'N/A'
                              : '${staff['parentFeedback']}',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFD4850A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double? _optionalMetric(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final raw = row[key];
      if (raw == null || '$raw'.trim().isEmpty) continue;
      final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
      if (value != null) return value;
    }
    return null;
  }

  Widget _metricBar(String label, double? value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                color: Colors.grey.shade500,
              ),
            ),
            Text(
              value == null ? 'N/A' : '${value.toStringAsFixed(0)}%',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value == null ? 0 : (value / 100).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: color.withAlpha(25),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ─── ALERTS TAB ───────────────────────────────────────────────────────────

  Widget _buildAlertsTab() {
    final alerts = _runtimeAlerts
        .map(
          (n) => {
            'type':
                ((n['priority'] ?? 'info').toString().toLowerCase() == 'high')
                ? 'critical'
                : ((n['priority'] ?? 'info').toString().toLowerCase()),
            'icon': Icons.notifications_active_rounded,
            'title': (n['title'] ?? 'Notification').toString(),
            'desc': (n['body'] ?? n['message'] ?? '').toString(),
            'time': (n['created_at'] ?? '').toString(),
            'action': 'View',
          },
        )
        .toList();

    final criticalAlerts = alerts
        .where((a) => a['type'] == 'critical')
        .toList();
    final warningAlerts = alerts.where((a) => a['type'] == 'warning').toList();
    final infoAlerts = alerts.where((a) => a['type'] == 'info').toList();
    final successAlerts = alerts.where((a) => a['type'] == 'success').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary row
          Row(
            children: [
              Expanded(
                child: _alertSummaryChip(
                  'Critical',
                  criticalAlerts.length,
                  AppTheme.error,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _alertSummaryChip(
                  'Warnings',
                  warningAlerts.length,
                  AppTheme.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _alertSummaryChip(
                  'Info',
                  infoAlerts.length,
                  AppTheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _alertSummaryChip(
                  'Resolved',
                  successAlerts.length,
                  AppTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (criticalAlerts.isNotEmpty) ...[
            _alertSectionHeader('🚨 Critical Alerts', AppTheme.error),
            const SizedBox(height: 8),
            ...criticalAlerts.map((a) => _alertCard(a)),
            const SizedBox(height: 16),
          ],

          if (warningAlerts.isNotEmpty) ...[
            _alertSectionHeader('⚠️ Warnings', AppTheme.warning),
            const SizedBox(height: 8),
            ...warningAlerts.map((a) => _alertCard(a)),
            const SizedBox(height: 16),
          ],

          if (infoAlerts.isNotEmpty) ...[
            _alertSectionHeader('ℹ️ Information', AppTheme.primary),
            const SizedBox(height: 8),
            ...infoAlerts.map((a) => _alertCard(a)),
            const SizedBox(height: 16),
          ],

          if (successAlerts.isNotEmpty) ...[
            _alertSectionHeader('✅ Achievements', AppTheme.success),
            const SizedBox(height: 8),
            ...successAlerts.map((a) => _alertCard(a)),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _alertSectionHeader(String title, Color color) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _alertCard(Map<String, dynamic> alert) {
    final type = alert['type'] as String;
    final color = type == 'critical'
        ? AppTheme.error
        : type == 'warning'
        ? AppTheme.warning
        : type == 'success'
        ? AppTheme.success
        : AppTheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(alert['icon'] as IconData, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        alert['title'] as String,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                    Text(
                      alert['time'] as String,
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  alert['desc'] as String,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      foregroundColor: color,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      alert['action'] as String,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────

  Widget _kpiCard(
    String label,
    String value,
    IconData icon,
    Color color,
    String? change,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1A2E),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              color: Colors.grey.shade500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (change != null) ...[
            const SizedBox(height: 2),
            Text(
              change,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: change.startsWith('+')
                    ? AppTheme.success
                    : AppTheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _alertSummaryChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodSelector(
    List<String> options,
    String selected,
    Function(String) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final isSelected = opt == selected;
          return GestureDetector(
            onTap: () => onChanged(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withAlpha(15),
                          blurRadius: 4,
                        ),
                      ]
                    : null,
              ),
              child: Text(
                opt,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected
                      ? const Color(0xFF1A1A2E)
                      : Colors.grey.shade500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _bar(double value, double maxValue, Color color, double maxHeight) {
    final h = (value / maxValue) * maxHeight * 8;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '${value.toStringAsFixed(0)}%',
          style: GoogleFonts.dmSans(
            fontSize: 8,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 14,
          height: h.clamp(4.0, maxHeight * 8),
          decoration: BoxDecoration(
            color: color.withAlpha(200),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(5),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  String _formatLakh(double amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(2)}Cr';
    }
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(0)}K';
    return amount.toStringAsFixed(0);
  }
}
