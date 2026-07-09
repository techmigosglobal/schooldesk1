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
import 'package:schooldesk1/core/theme/design_tokens.dart';

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
      subtitle: 'Today status, month summary, calendar, and attendance',
      drawer: ParentDrawer(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,

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
                ],
              ),
            ),
    );
  }

  Widget _buildChildSelector() {
    if (_childRows.isEmpty) {
      final tokens = Theme.of(context).schoolDesk;
      return Container(
        padding: EdgeInsets.all(tokens.spacing.md),
        decoration: BoxDecoration(
          color: context.appTheme.surface,
          borderRadius: BorderRadius.circular(tokens.radius.card),
          border: Border.all(color: context.appTheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.family_restroom_rounded, color: context.appTheme.muted),
            SizedBox(width: tokens.spacing.sm),
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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? _headerColor : context.appTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: isActive
                    ? null
                    : Border.all(color: context.appTheme.outlineVariant),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: _headerColor.withAlpha(40),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isActive)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Text(
                    _childShortLabel(_childRows[i]),
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : context.appTheme.onSurface,
                    ),
                  ),
                ],
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withAlpha(22), color.withAlpha(10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(45)),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withAlpha(200)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha(50),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 17),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
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
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appTheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A6B4A).withAlpha(15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient month header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F766E), Color(0xFF1A6B4A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  monthLabel,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                // Legend
                _legendDot(Colors.green, 'Present'),
                const SizedBox(width: 8),
                _legendDot(Colors.red, 'Absent'),
                const SizedBox(width: 8),
                _legendDot(Colors.orange, 'Late'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                      .map(
                        (d) => Text(
                          d,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
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
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 9,
            color: Colors.white.withAlpha(210),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A6B4A), Color(0xFF0F766E)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Recent Attendance',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: context.appTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.appTheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: context.appTheme.onSurface.withAlpha(8),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
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
                        if (i > 0)
                          Divider(
                            height: 1,
                            color: context.appTheme.outlineVariant,
                          ),
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
      return const Color(0xFF0284C7); // info blue — matches appTheme.info
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


