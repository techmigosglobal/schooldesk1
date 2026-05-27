import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../widgets/parent_navigation.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_module_scaffold.dart';
import '../../services/backend_api_client.dart';

class ParentAttendanceScreen extends StatefulWidget {
  const ParentAttendanceScreen({super.key});

  @override
  State<ParentAttendanceScreen> createState() => _ParentAttendanceScreenState();
}

class _ParentAttendanceScreenState extends State<ParentAttendanceScreen>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = 2;
  int _activeChildIndex = 0;
  static const _headerColor = Color(0xFF1A6B4A);

  // Scoped to only this parent's children
  List<String> _children = [];
  List<String> _childIds = [];

  List<Map<String, dynamic>> _attendanceHistory = [];
  Map<int, String> _attendanceDayStatus = {};
  List<Map<String, dynamic>> _leaveRequests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      final childrenResponse = await BackendApiClient.instance.getMyStudents();

      setState(() {
        _children = childrenResponse.map((c) {
          final first = (c['first_name'] ?? '').toString();
          final last = (c['last_name'] ?? '').toString();
          final name = [
            first,
            last,
          ].where((e) => e.isNotEmpty).join(' ').trim();
          final grade = (c['grade_name'] ?? '').toString();
          final section = (c['section_name'] ?? '').toString();
          final classLabel = [
            grade,
            section,
          ].where((e) => e.isNotEmpty).join('-');
          return classLabel.isEmpty ? name : '$name ($classLabel)';
        }).toList();
        _childIds = childrenResponse
            .map((c) => (c['id'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toList();

        // Load attendance for first child
        if (_children.isNotEmpty && _childIds.isNotEmpty) {
          _loadChildAttendance(0);
        } else {
          _loading = false;
        }
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load data: $e')));
      }
    }
  }

  Future<void> _loadChildAttendance(int childIndex) async {
    if (childIndex >= _children.length || childIndex >= _childIds.length) {
      return;
    }

    try {
      final studentId = _childIds[childIndex];
      // Fetch attendance summary
      final attendanceSummary = await BackendApiClient.instance
          .getStudentAttendanceSummary(studentId: studentId);
      final leaveRequests = await BackendApiClient.instance
          .getStudentLeaveApplications(studentId: studentId);
      // Backend integration: populate _attendanceDayStatus from day-wise
      // attendance rows when the API exposes them. Until then, calendar dates
      // stay empty instead of showing hard-coded present/absent values.
      final attendanceDayStatus = _dayStatusFromSummary(attendanceSummary);

      setState(() {
        _attendanceHistory = [
          {
            'month': 'Current Month',
            'present': attendanceSummary['present_days'],
            'absent': attendanceSummary['absent_days'],
            'total': attendanceSummary['total_days'],
            'percentage': attendanceSummary['attendance_pct'],
            'date': 'Current Month',
            'time': '—',
            'status': 'Summary',
          },
        ];
        _attendanceDayStatus = attendanceDayStatus;
        _leaveRequests = leaveRequests.map(_leaveRequestFromApi).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load attendance: $e')),
        );
      }
    }
  }

  Map<String, dynamic> _leaveRequestFromApi(Map<String, dynamic> request) {
    final fromDate = DateTime.tryParse('${request['from_date'] ?? ''}');
    final toDate = DateTime.tryParse('${request['to_date'] ?? ''}');
    final dateLabel = fromDate == null
        ? '${request['from_date'] ?? ''}'.split('T').first
        : DateFormat('d MMM yyyy').format(fromDate);
    final toLabel = toDate == null
        ? ''
        : DateFormat('d MMM yyyy').format(toDate);
    return {
      'date': toLabel.isEmpty || toLabel == dateLabel
          ? dateLabel
          : '$dateLabel - $toLabel',
      'reason': request['reason'] ?? 'Not specified',
      'type': request['leave_type'] ?? 'Leave',
      'status': request['status'] ?? 'Pending',
      'approvedBy': request['decided_by'] ?? request['approved_by'] ?? '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Attendance',
      subtitle: 'Track daily attendance, history, and leave requests',
      drawer: ParentDrawer(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      actions: [
        TextButton.icon(
          onPressed: () => _showLeaveRequestDialog(context),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text('Leave Request', style: GoogleFonts.dmSans(fontSize: 12)),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildChildSelector(),
                  const SizedBox(height: 16),
                  _buildAttendanceSummary(),
                  const SizedBox(height: 16),
                  _buildMonthlyCalendar(),
                  const SizedBox(height: 16),
                  _buildHistoryList(),
                  const SizedBox(height: 16),
                  _buildLeaveRequestsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildChildSelector() {
    return Row(
      children: List.generate(_children.length, (i) {
        final isActive = i == _activeChildIndex;
        return GestureDetector(
          onTap: () {
            setState(() => _activeChildIndex = i);
            _loadChildAttendance(i);
          },
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isActive ? _headerColor : AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive ? _headerColor : AppTheme.outlineVariant,
              ),
            ),
            child: Text(
              _children[i].split(' ').first,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : AppTheme.onSurface,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildAttendanceSummary() {
    final current = _attendanceHistory.isEmpty
        ? <String, dynamic>{}
        : _attendanceHistory.first;
    final present = _numberLabel(current['present']);
    final absent = _numberLabel(current['absent']);
    final late = _numberLabel(current['late']);
    final pct = (current['percentage'] as num?)?.toDouble();
    final rate = pct == null ? '—' : '${pct.toStringAsFixed(0)}%';
    return Row(
      children: [
        Expanded(
          child: _statCard(
            'Present',
            present,
            Icons.check_circle_rounded,
            AppTheme.success,
            AppTheme.successContainer,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            'Absent',
            absent,
            Icons.cancel_rounded,
            AppTheme.error,
            AppTheme.errorContainer,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            'Late',
            late,
            Icons.schedule_rounded,
            AppTheme.warning,
            AppTheme.warningContainer,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            'Rate',
            rate,
            Icons.bar_chart_rounded,
            AppTheme.primary,
            AppTheme.primaryContainer,
          ),
        ),
      ],
    );
  }

  Widget _statCard(
    String label,
    String value,
    IconData icon,
    Color color,
    Color bg,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.dmSans(fontSize: 10, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyCalendar() {
    final now = DateTime.now();
    final monthLabel = DateFormat('MMMM yyyy').format(now);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            monthLabel,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['M', 'T', 'W', 'T', 'F', 'S']
                .map(
                  (d) => Text(
                    d,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.muted,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          _buildCalendarGrid(),
          if (_attendanceDayStatus.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Day-wise attendance will appear after the school publishes it.',
              style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        childAspectRatio: 1.2,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: 30,
      itemBuilder: (_, i) {
        final day = i + 1;
        final status = _attendanceDayStatus[day];
        Color bg = Colors.transparent;
        Color textColor = AppTheme.onSurface;
        if (status == 'P') {
          bg = AppTheme.successContainer;
          textColor = AppTheme.success;
        } else if (status == 'A') {
          bg = AppTheme.errorContainer;
          textColor = AppTheme.error;
        } else if (status == 'L') {
          bg = AppTheme.warningContainer;
          textColor = AppTheme.warning;
        } else if (status == 'H') {
          bg = AppTheme.infoContainer;
          textColor = AppTheme.info;
        }
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              '$day',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Attendance',
          style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Column(
            children: _attendanceHistory.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Attendance history will appear after the school publishes it.',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppTheme.muted,
                        ),
                      ),
                    ),
                  ]
                : _attendanceHistory.asMap().entries.map((e) {
                    final i = e.key;
                    final rec = e.value;
                    return Column(
                      children: [
                        if (i > 0) const Divider(height: 1),
                        _attendanceRow(rec),
                      ],
                    );
                  }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _attendanceRow(Map<String, dynamic> rec) {
    Color statusColor;
    IconData statusIcon;
    switch (rec['status']) {
      case 'Present':
        statusColor = AppTheme.success;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'Absent':
        statusColor = AppTheme.error;
        statusIcon = Icons.cancel_rounded;
        break;
      case 'Late':
        statusColor = AppTheme.warning;
        statusIcon = Icons.schedule_rounded;
        break;
      default:
        statusColor = AppTheme.info;
        statusIcon = Icons.timelapse_rounded;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              rec['date'],
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            rec['time'],
            style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              rec['status'],
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Leave Requests',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _showLeaveRequestDialog(context),
              icon: const Icon(Icons.add_rounded, size: 14),
              label: Text('New', style: GoogleFonts.dmSans(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._leaveRequests.map((lr) => _leaveRequestCard(lr)),
      ],
    );
  }

  Widget _leaveRequestCard(Map<String, dynamic> lr) {
    final isApproved = lr['status'] == 'Approved';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isApproved
                  ? AppTheme.successContainer
                  : AppTheme.warningContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isApproved ? Icons.check_circle_rounded : Icons.pending_rounded,
              color: isApproved ? AppTheme.success : AppTheme.warning,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lr['type'],
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${lr['date']} — ${lr['reason']}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.muted,
                  ),
                ),
                if (isApproved)
                  Text(
                    'Approved by ${lr['approvedBy']}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppTheme.success,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isApproved
                  ? AppTheme.successContainer
                  : AppTheme.warningContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              lr['status'],
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isApproved ? AppTheme.success : AppTheme.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLeaveRequestDialog(BuildContext context) async {
    if (_activeChildIndex >= _childIds.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select a backend-linked student before requesting leave.',
          ),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    final request = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => _StudentLeaveRequestPage(
          studentId: _childIds[_activeChildIndex],
          headerColor: _headerColor,
        ),
      ),
    );
    if (!mounted || request == null) return;
    setState(() {
      _leaveRequests.insert(0, {
        'date': '${request['from_date'] ?? ''}'.split('T').first,
        'reason': request['reason'] ?? 'Not specified',
        'type': request['leave_type'] ?? 'Leave',
        'status': request['status'] ?? 'Pending',
        'approvedBy': request['approved_by'] ?? '',
      });
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Leave request submitted successfully!')),
    );
  }
}

Map<int, String> _dayStatusFromSummary(Map<String, dynamic> summary) {
  final source =
      summary['daily_statuses'] ??
      summary['daily_attendance'] ??
      summary['days'];
  if (source is! List) return const {};
  final now = DateTime.now();
  final statuses = <int, String>{};
  for (final item in source.whereType<Map>()) {
    final row = Map<String, dynamic>.from(item);
    final parsed = DateTime.tryParse('${row['date'] ?? ''}');
    if (parsed == null ||
        parsed.month != now.month ||
        parsed.year != now.year) {
      continue;
    }
    final status = _statusCode(row['status'] ?? row['attendance_status']);
    if (status.isNotEmpty) statuses[parsed.day] = status;
  }
  return statuses;
}

String _statusCode(dynamic raw) {
  switch ('${raw ?? ''}'.trim().toLowerCase()) {
    case 'present':
    case 'p':
      return 'P';
    case 'absent':
    case 'a':
      return 'A';
    case 'late':
    case 'l':
      return 'L';
    case 'holiday':
    case 'h':
      return 'H';
  }
  return '';
}

String _numberLabel(dynamic value) {
  if (value is num) return value.toInt().toString();
  return '—';
}

class _StudentLeaveRequestPage extends StatefulWidget {
  final String studentId;
  final Color headerColor;

  const _StudentLeaveRequestPage({
    required this.studentId,
    required this.headerColor,
  });

  @override
  State<_StudentLeaveRequestPage> createState() =>
      _StudentLeaveRequestPageState();
}

class _StudentLeaveRequestPageState extends State<_StudentLeaveRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  late final TextEditingController _fromDateCtrl;
  late final TextEditingController _toDateCtrl;
  String _selectedType = 'Sick Leave';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _fromDateCtrl = TextEditingController(text: today);
    _toDateCtrl = TextEditingController(text: today);
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _fromDateCtrl.dispose();
    _toDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final fromDate = DateTime.parse(_fromDateCtrl.text.trim());
    final toDate = DateTime.parse(_toDateCtrl.text.trim());
    if (toDate.isBefore(fromDate)) {
      setState(() => _error = 'To date cannot be before from date.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final reason = _reasonCtrl.text.trim().isEmpty
          ? 'Not specified'
          : _reasonCtrl.text.trim();
      final response = await BackendApiClient.instance
          .submitStudentLeaveApplication(
            studentId: widget.studentId,
            leaveType: _selectedType,
            fromDate: _fromDateCtrl.text.trim(),
            toDate: _toDateCtrl.text.trim(),
            reason: reason,
          );
      if (!mounted) return;
      Navigator.pop(context, {
        ...response,
        'leave_type': response['leave_type'] ?? _selectedType,
        'from_date': response['from_date'] ?? _fromDateCtrl.text.trim(),
        'reason': response['reason'] ?? reason,
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Leave request failed: $e';
      });
    }
  }

  String? _dateValidator(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Enter a date.';
    final parsed = DateTime.tryParse(text);
    if (parsed == null || DateFormat('yyyy-MM-dd').format(parsed) != text) {
      return 'Use YYYY-MM-DD.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Leave Request')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_error != null) ...[
                _InputErrorBanner(message: _error!),
                const SizedBox(height: 16),
              ],
              DropdownButtonFormField<String>(
                initialValue: _selectedType,
                decoration: const InputDecoration(labelText: 'Leave Type'),
                items:
                    [
                          'Sick Leave',
                          'Personal Leave',
                          'Early Pickup',
                          'Special Permission',
                        ]
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(
                              t,
                              style: GoogleFonts.dmSans(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _selectedType = v ?? _selectedType),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fromDateCtrl,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'From date',
                  hintText: 'YYYY-MM-DD',
                ),
                validator: _dateValidator,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _toDateCtrl,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'To date',
                  hintText: 'YYYY-MM-DD',
                ),
                validator: _dateValidator,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonCtrl,
                enabled: !_saving,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Describe the reason...',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: widget.headerColor,
                ),
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputErrorBanner extends StatelessWidget {
  final String message;

  const _InputErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.error),
      ),
    );
  }
}
