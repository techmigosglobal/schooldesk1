import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/services/parent_child_selection_service.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

class ParentAttendanceScreen extends StatefulWidget {
  const ParentAttendanceScreen({super.key});

  @override
  State<ParentAttendanceScreen> createState() => _ParentAttendanceScreenState();
}

class _ParentAttendanceScreenState extends State<ParentAttendanceScreen>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = ParentNav.attendance;
  int _activeChildIndex = 0;
  static const _headerColor = Color(0xFF1A6B4A);

  // Scoped to only this parent's children
  List<Map<String, dynamic>> _childRows = [];

  List<Map<String, dynamic>> _attendanceHistory = [];
  Map<String, dynamic> _attendanceSummary = {};
  Map<int, String> _attendanceDayStatus = {};
  Map<int, List<Map<String, dynamic>>> _periodRowsByDay = {};
  List<Map<String, dynamic>> _leaveRequests = [];
  bool _loading = true;
  int _attendanceRequestToken = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      final childrenResponse = await BackendApiClient.instance.getMyStudents();
      final childRows = childrenResponse
          .map((child) => Map<String, dynamic>.from(child))
          .where((child) => _childId(child).isNotEmpty)
          .toList();
      final selectedIndex = await ParentChildSelectionService.indexFor(
        childRows,
        fallback: _activeChildIndex,
      );

      if (!mounted) return;
      setState(() {
        _childRows = childRows;
        _activeChildIndex = selectedIndex;
      });
      if (_childRows.isNotEmpty) {
        await _loadChildAttendance(selectedIndex);
      } else {
        setState(() {
          _attendanceHistory = [];
          _attendanceSummary = {};
          _attendanceDayStatus = {};
          _periodRowsByDay = {};
          _leaveRequests = [];
          _loading = false;
        });
      }
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
    if (childIndex < 0 || childIndex >= _childRows.length) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }
    final requestToken = ++_attendanceRequestToken;
    final studentId = _childId(_childRows[childIndex]);
    if (studentId.isEmpty) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    try {
      final attendanceSummary = await _safeAttendanceSummary(studentId);
      final attendanceRecords = await _safeAttendanceRecords(studentId);
      final leaveRequests = await _safeLeaveRequests(studentId);
      final periodRows = _periodRowsFromSources(
        summary: attendanceSummary,
        records: attendanceRecords,
        leaveRequests: leaveRequests,
      );
      final attendanceDayStatus = _dayStatusFromPeriodRows(periodRows);

      if (!mounted ||
          requestToken != _attendanceRequestToken ||
          childIndex != _activeChildIndex ||
          studentId != _activeChildId) {
        return;
      }
      setState(() {
        _attendanceHistory = periodRows.take(20).toList();
        _attendanceSummary = attendanceSummary;
        _attendanceDayStatus = attendanceDayStatus;
        _periodRowsByDay = _groupPeriodRowsByDay(periodRows);
        _leaveRequests = leaveRequests.map(_leaveRequestFromApi).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted &&
          requestToken == _attendanceRequestToken &&
          childIndex == _activeChildIndex) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load attendance: $e')),
        );
      }
    }
  }

  Future<Map<String, dynamic>> _safeAttendanceSummary(String studentId) async {
    try {
      return await BackendApiClient.instance.getStudentAttendanceSummary(
        studentId: studentId,
      );
    } catch (_) {
      return <String, dynamic>{
        'student_id': studentId,
        'present_days': 0,
        'absent_days': 0,
        'late_count': 0,
        'leave_days': 0,
        'half_day_count': 0,
        'attendance_pct': 0,
      };
    }
  }

  Future<List<Map<String, dynamic>>> _safeAttendanceRecords(
    String studentId,
  ) async {
    try {
      return await BackendApiClient.instance.getStudentAttendanceRecords(
        studentId,
        month: DateTime.now().month,
        year: DateTime.now().year,
      );
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> _safeLeaveRequests(
    String studentId,
  ) async {
    try {
      return await BackendApiClient.instance.getStudentLeaveApplications(
        studentId: studentId,
      );
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Map<String, dynamic> _leaveRequestFromApi(Map<String, dynamic> request) {
    final fromRaw = _leaveStartDate(request);
    final toRaw = _leaveEndDate(request);
    final fromDate = DateTime.tryParse(fromRaw);
    final toDate = DateTime.tryParse(toRaw);
    final dateLabel = fromDate == null
        ? fromRaw.split('T').first
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

  String get _activeChildId {
    if (_activeChildIndex < 0 || _activeChildIndex >= _childRows.length) {
      return '';
    }
    return _childId(_childRows[_activeChildIndex]);
  }

  String _childId(Map<String, dynamic> child) =>
      '${child['id'] ?? child['student_id'] ?? ''}'.trim();

  String _childShortLabel(Map<String, dynamic> child) {
    final first = (child['first_name'] ?? '').toString().trim();
    final fallback = (child['name'] ?? child['full_name'] ?? 'Student')
        .toString()
        .trim();
    return first.isNotEmpty ? first : fallback.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'My Child Attendance',
      subtitle: 'Today status, month summary, calendar, and leave',
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
    if (_childRows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.appTheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.family_restroom_rounded, color: context.appTheme.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No linked students found for this parent account.',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: context.appTheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_childRows.length, (i) {
          final isActive = i == _activeChildIndex;
          return GestureDetector(
            onTap: () {
              if (i == _activeChildIndex && !_loading) return;
              setState(() {
                _activeChildIndex = i;
                _loading = true;
              });
              ParentChildSelectionService.saveIndex(_childRows, i);
              _loadChildAttendance(i);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isActive ? _headerColor : context.appTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive
                      ? _headerColor
                      : context.appTheme.outlineVariant,
                ),
              ),
              child: Text(
                _childShortLabel(_childRows[i]),
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : context.appTheme.onSurface,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAttendanceSummary() {
    final current = _attendanceSummary;
    final present = _numberLabel(current['present_days']);
    final absent = _numberLabel(current['absent_days']);
    final late = _numberLabel(current['late_count']);
    final leave = _numberLabel(current['leave_days']);
    final halfDay = _numberLabel(current['half_day_count']);
    final pct = _numberValue(
      current['attendance_pct'] ??
          current['attendance_percent'] ??
          current['percent'] ??
          current['percentage'],
    );
    final rate = pct == null ? '—' : '${pct.toStringAsFixed(0)}%';
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.3,
      children: [
        _statCard(
          'Present',
          present,
          Icons.check_circle_rounded,
          context.appTheme.success,
          context.appTheme.successContainer,
        ),
        _statCard(
          'Absent',
          absent,
          Icons.cancel_rounded,
          context.appTheme.error,
          context.appTheme.errorContainer,
        ),
        _statCard(
          'Late',
          late,
          Icons.schedule_rounded,
          context.appTheme.warning,
          context.appTheme.warningContainer,
        ),
        _statCard(
          'Leave',
          leave,
          Icons.event_available_rounded,
          context.appTheme.info,
          context.appTheme.infoContainer,
        ),
        _statCard(
          'Half Day',
          halfDay,
          Icons.timelapse_rounded,
          Colors.purple,
          context.appTheme.primaryContainer,
        ),
        _statCard(
          'Rate',
          rate,
          Icons.bar_chart_rounded,
          context.appTheme.primary,
          context.appTheme.primaryContainer,
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
            style: GoogleFonts.dmSans(
              fontSize: 10,
              color: context.appTheme.muted,
            ),
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
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appTheme.outlineVariant),
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
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map(
                  (d) => Text(
                    d,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.appTheme.muted,
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
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: context.appTheme.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final leadingBlanks = DateTime(now.year, now.month, 1).weekday % 7;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.2,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: leadingBlanks + daysInMonth,
      itemBuilder: (_, i) {
        if (i < leadingBlanks) {
          return const SizedBox.shrink();
        }
        final day = i - leadingBlanks + 1;
        final status = _attendanceDayStatus[day];
        Color bg = Colors.transparent;
        Color textColor = context.appTheme.onSurface;
        if (status == 'P') {
          bg = context.appTheme.successContainer;
          textColor = context.appTheme.success;
        } else if (status == 'A') {
          bg = context.appTheme.errorContainer;
          textColor = context.appTheme.error;
        } else if (status == 'L') {
          bg = context.appTheme.warningContainer;
          textColor = context.appTheme.warning;
        } else if (status == 'H') {
          bg = context.appTheme.infoContainer;
          textColor = context.appTheme.info;
        } else if (status == 'V') {
          bg = context.appTheme.infoContainer;
          textColor = context.appTheme.info;
        } else if (status == 'HD') {
          bg = context.appTheme.primaryContainer;
          textColor = Colors.purple;
        }
        return InkWell(
          onTap: () => _showDayAttendanceDetail(day),
          borderRadius: BorderRadius.circular(6),
          child: Container(
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
          ),
        );
      },
    );
  }

  Future<void> _showDayAttendanceDetail(int day) async {
    final rows = _periodRowsByDay[day] ?? const <Map<String, dynamic>>[];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Period-wise attendance',
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              if (rows.isEmpty)
                Text(
                  'No attendance rows for this day.',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: context.appTheme.muted,
                  ),
                )
              else
                for (final row in rows)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.fact_check_rounded,
                      color: _statusColor('${row['status'] ?? ''}'),
                    ),
                    title: Text(
                      'Period ${row['period_number'] ?? '—'} • ${row['status'] ?? '—'}',
                    ),
                    subtitle: Text(
                      'Marked by teacher: ${row['marked_by'] ?? '—'}\nReason: ${row['reason'] ?? '—'}',
                    ),
                  ),
            ],
          ),
        ),
      ),
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
            color: context.appTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.appTheme.outlineVariant),
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
                          color: context.appTheme.muted,
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
        statusColor = context.appTheme.success;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'Absent':
        statusColor = context.appTheme.error;
        statusIcon = Icons.cancel_rounded;
        break;
      case 'Late':
        statusColor = context.appTheme.warning;
        statusIcon = Icons.schedule_rounded;
        break;
      default:
        statusColor = context.appTheme.info;
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
              rec['date'] ?? '',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            rec['time'] ??
                (rec['period_number'] != null
                    ? 'Period ${rec['period_number']}'
                    : '—'),
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: context.appTheme.muted,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              rec['status'] ?? 'Unknown',
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
        if (_leaveRequests.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.appTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.appTheme.outlineVariant),
            ),
            child: Text(
              'No leave requests found for this student.',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: context.appTheme.muted,
              ),
            ),
          )
        else
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
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isApproved
                  ? context.appTheme.successContainer
                  : context.appTheme.warningContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isApproved ? Icons.check_circle_rounded : Icons.pending_rounded,
              color: isApproved
                  ? context.appTheme.success
                  : context.appTheme.warning,
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
                    color: context.appTheme.muted,
                  ),
                ),
                if (isApproved)
                  Text(
                    'Approved by ${lr['approvedBy']}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: context.appTheme.success,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isApproved
                  ? context.appTheme.successContainer
                  : context.appTheme.warningContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              lr['status'],
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isApproved
                    ? context.appTheme.success
                    : context.appTheme.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLeaveRequestDialog(BuildContext context) async {
    if (_activeChildIndex >= _childRows.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Select a backend-linked student before requesting leave.',
          ),
          backgroundColor: context.appTheme.error,
        ),
      );
      return;
    }
    final request = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => _StudentLeaveRequestPage(
          studentId: _childId(_childRows[_activeChildIndex]),
          headerColor: _headerColor,
        ),
      ),
    );
    if (!mounted || request == null) return;
    setState(() {
      _leaveRequests.insert(0, {
        'date': _leaveStartDate(request).split('T').first,
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

List<Map<String, dynamic>> _periodRowsFromSources({
  required Map<String, dynamic> summary,
  required List<Map<String, dynamic>> records,
  required List<Map<String, dynamic>> leaveRequests,
}) {
  final rows = <Map<String, dynamic>>[];
  final summaryRows = summary['period_rows'];
  if (summaryRows is List) {
    rows.addAll(
      summaryRows.whereType<Map>().map((row) {
        final item = Map<String, dynamic>.from(row);
        item['status'] = _statusLabel(item['status']);
        return item;
      }),
    );
  }
  rows.addAll(records.map(_periodRowFromAttendanceRecord));
  rows.addAll(_approvedLeavePeriodRows(leaveRequests));
  final uniqueRows = _deduplicatePeriodRows(rows);
  uniqueRows.sort((a, b) {
    final left = '${b['date'] ?? ''}${b['period_number'] ?? ''}';
    final right = '${a['date'] ?? ''}${a['period_number'] ?? ''}';
    return left.compareTo(right);
  });
  return uniqueRows;
}

List<Map<String, dynamic>> buildParentAttendancePeriodRowsForTest({
  required Map<String, dynamic> summary,
  required List<Map<String, dynamic>> records,
  required List<Map<String, dynamic>> leaveRequests,
}) {
  return _periodRowsFromSources(
    summary: summary,
    records: records,
    leaveRequests: leaveRequests,
  );
}

List<Map<String, dynamic>> _deduplicatePeriodRows(
  List<Map<String, dynamic>> rows,
) {
  final byKey = <String, Map<String, dynamic>>{};
  for (final row in rows) {
    final key = _periodRowIdentity(row);
    final existing = byKey[key];
    if (existing == null) {
      byKey[key] = Map<String, dynamic>.from(row);
      continue;
    }
    byKey[key] = _mergePeriodRow(existing, row);
  }
  return byKey.values.toList();
}

Map<String, dynamic> _mergePeriodRow(
  Map<String, dynamic> existing,
  Map<String, dynamic> incoming,
) {
  final merged = Map<String, dynamic>.from(existing);
  for (final entry in incoming.entries) {
    final current = merged[entry.key];
    if (_isBlankPeriodValue(current)) {
      merged[entry.key] = entry.value;
    }
  }
  return merged;
}

bool _isBlankPeriodValue(dynamic value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty || text == '—';
}

String _periodRowIdentity(Map<String, dynamic> row) {
  final date = _normalDateKey(row['date']);
  if (date.isNotEmpty) {
    final period = _normalPeriodKey(row['period_number']);
    return 'day:$date:$period';
  }
  final id = '${row['id'] ?? ''}'.trim();
  if (id.isNotEmpty) return 'attendance:$id';
  final sessionId = '${row['session_id'] ?? ''}'.trim();
  if (sessionId.isNotEmpty) return 'session:$sessionId';
  final status = _statusLabel(row['status']).toLowerCase();
  return 'status:$status';
}

String _normalDateKey(dynamic value) {
  final text = '${value ?? ''}'.trim();
  if (text.isEmpty) return '';
  return text.split('T').first;
}

String _normalPeriodKey(dynamic period) {
  final text = '${period ?? ''}'.trim().toLowerCase();
  if (text.isEmpty || text == '—' || text == '0' || text == 'all day') {
    return 'all_day';
  }
  return text.replaceAll(' ', '_');
}

Map<String, dynamic> _periodRowFromAttendanceRecord(Map<String, dynamic> row) {
  final session = row['session'] is Map
      ? Map<String, dynamic>.from(row['session'] as Map)
      : <String, dynamic>{};
  final staff = session['staff'] is Map
      ? Map<String, dynamic>.from(session['staff'] as Map)
      : <String, dynamic>{};
  final staffName = [
    staff['first_name'],
    staff['last_name'],
  ].where((part) => '${part ?? ''}'.trim().isNotEmpty).join(' ');
  return {
    'id': row['id'],
    'date': '${session['date'] ?? row['marked_at'] ?? ''}'.split('T').first,
    'period_number': session['period_number'] ?? '—',
    'status': _statusLabel(row['status']),
    'reason': row['reason'] ?? '',
    'marked_by': staffName.isEmpty ? 'Teacher' : staffName,
    'session_id': session['id'] ?? row['session_id'],
  };
}

List<Map<String, dynamic>> _approvedLeavePeriodRows(
  List<Map<String, dynamic>> leaveRequests,
) {
  final now = DateTime.now();
  final rows = <Map<String, dynamic>>[];
  for (final request in leaveRequests) {
    if ('${request['status'] ?? ''}'.toLowerCase() != 'approved') continue;
    final from = DateTime.tryParse(_leaveStartDate(request));
    final to = DateTime.tryParse(_leaveEndDate(request)) ?? from;
    if (from == null || to == null) continue;
    for (
      var day = from;
      !day.isAfter(to);
      day = day.add(const Duration(days: 1))
    ) {
      if (day.month != now.month || day.year != now.year) continue;
      final isHalfDay = _leaveIsHalfDay(request);
      rows.add({
        'id': request['id'],
        'date': DateFormat('yyyy-MM-dd').format(day),
        'period_number': isHalfDay ? 'Half Day' : 'All Day',
        'status': isHalfDay ? 'Half Day' : 'Leave',
        'reason': request['reason'] ?? '',
        'marked_by': 'Approved leave',
      });
    }
  }
  return rows;
}

Map<int, String> _dayStatusFromPeriodRows(List<Map<String, dynamic>> rows) {
  final now = DateTime.now();
  final statuses = <int, String>{};
  for (final row in rows) {
    final parsed = DateTime.tryParse('${row['date'] ?? ''}');
    if (parsed == null ||
        parsed.month != now.month ||
        parsed.year != now.year) {
      continue;
    }
    final code = _statusCode(row['status']);
    if (code.isNotEmpty) statuses[parsed.day] = code;
  }
  return statuses;
}

Map<int, List<Map<String, dynamic>>> _groupPeriodRowsByDay(
  List<Map<String, dynamic>> rows,
) {
  final grouped = <int, List<Map<String, dynamic>>>{};
  final now = DateTime.now();
  for (final row in rows) {
    final parsed = DateTime.tryParse('${row['date'] ?? ''}');
    if (parsed == null ||
        parsed.month != now.month ||
        parsed.year != now.year) {
      continue;
    }
    grouped.putIfAbsent(parsed.day, () => []).add(row);
  }
  return grouped;
}

String _statusLabel(dynamic raw) {
  switch ('${raw ?? ''}'.trim().toLowerCase().replaceAll('-', '_')) {
    case 'present':
    case 'p':
      return 'Present';
    case 'absent':
    case 'a':
      return 'Absent';
    case 'late':
    case 'l':
      return 'Late';
    case 'leave':
      return 'Leave';
    case 'half_day':
      return 'Half Day';
  }
  return '${raw ?? ''}'.trim().isEmpty ? '—' : '${raw ?? ''}';
}

Color _statusColor(String status) {
  switch (_statusLabel(status)) {
    case 'Present':
      return Colors.green;
    case 'Absent':
      return Colors.red;
    case 'Late':
      return Colors.orange;
    case 'Leave':
      return Colors.blue;
    case 'Half Day':
      return Colors.purple;
  }
  return Colors.grey;
}

String _statusCode(dynamic raw) {
  switch ('${raw ?? ''}'.trim().toLowerCase().replaceAll('-', '_')) {
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
    case 'leave':
      return 'V';
    case 'half_day':
      return 'HD';
  }
  return '';
}

String _numberLabel(dynamic value) {
  if (value is num) return value.toInt().toString();
  return '—';
}

double? _numberValue(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}'.trim());
}

String _leaveStartDate(Map<String, dynamic> request) {
  return '${request['from_date'] ?? request['start_date'] ?? ''}'.trim();
}

String _leaveEndDate(Map<String, dynamic> request) {
  return '${request['to_date'] ?? request['end_date'] ?? _leaveStartDate(request)}'
      .trim();
}

bool _leaveIsHalfDay(Map<String, dynamic> request) {
  final direct = request['half_day'];
  if (direct is bool) return direct;
  final value = '${direct ?? request['is_half_day'] ?? ''}'
      .trim()
      .toLowerCase();
  return value == 'true' || value == '1' || value == 'yes';
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

  Future<void> _pickDate(TextEditingController controller) async {
    final current = DateTime.tryParse(controller.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    controller.text = DateFormat('yyyy-MM-dd').format(picked);
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
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'From date',
                  suffixIcon: Icon(Icons.calendar_month_rounded),
                ),
                onTap: _saving ? null : () => _pickDate(_fromDateCtrl),
                validator: _dateValidator,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _toDateCtrl,
                enabled: !_saving,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'To date',
                  suffixIcon: Icon(Icons.calendar_month_rounded),
                ),
                onTap: _saving ? null : () => _pickDate(_toDateCtrl),
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
        color: context.appTheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: GoogleFonts.dmSans(fontSize: 13, color: context.appTheme.error),
      ),
    );
  }
}
