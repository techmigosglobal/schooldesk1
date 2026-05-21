import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/teacher_navigation.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_module_scaffold.dart';
import '../../services/backend_api_client.dart';
import 'teacher_leave_request_form_screen.dart';

class TeacherLeaveScreen extends StatefulWidget {
  const TeacherLeaveScreen({super.key});

  @override
  State<TeacherLeaveScreen> createState() => _TeacherLeaveScreenState();
}

class _TeacherLeaveScreenState extends State<TeacherLeaveScreen> {
  int _selectedNavIndex = 10;

  double _totalLeave = 0;
  double _usedLeave = 0;
  double _pendingLeave = 0;
  double _remainingLeave = 0;

  List<Map<String, dynamic>> _leaveHistory = [];
  List<Map<String, dynamic>> _leaveTypes = [];
  List<Map<String, dynamic>> _balances = [];
  String _teacherStaffId = '';
  String _teacherName = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api = BackendApiClient.instance;
      final profile = await api.getProfile();
      final dashboard = await api.getDashboard('teacher');
      final staffId = _text(dashboard['staff_id']);
      if (staffId.isEmpty) {
        throw Exception('Teacher account is not linked to a staff profile');
      }
      final rows = await api.getLeaveApplications(staffId: staffId);
      final leaveTypes = await api.getLeaveTypes();
      final balances = await api.getLeaveBalances(staffId: staffId);
      final leaveTypeNames = {
        for (final type in leaveTypes) _text(type['id']): _leaveTypeName(type),
      };
      final totals = _balanceTotals(balances, leaveTypes, rows);
      if (!mounted) return;
      setState(() {
        _teacherStaffId = staffId;
        _teacherName = profile.name;
        _leaveTypes = leaveTypes;
        _balances = balances;
        _leaveHistory = rows
            .map(
              (l) => {
                'id': l.id,
                'teacherName': l.staffId,
                'leaveType': leaveTypeNames[l.leaveTypeId] ?? l.leaveTypeId,
                'leaveTypeId': l.leaveTypeId,
                'fromDate': l.fromDate.split('T').first,
                'toDate': l.toDate.split('T').first,
                'days': l.totalDays,
                'status': l.status,
                'reason': l.reason ?? '',
                'submittedOn': l.fromDate.split('T').first,
                'remarks': l.rejectionReason ?? '',
              },
            )
            .toList();
        _totalLeave = totals.total;
        _usedLeave = totals.used;
        _pendingLeave = totals.pending;
        _remainingLeave = totals.remaining;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final drawer = TeacherDrawer(
      selectedIndex: _selectedNavIndex,
      onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
    );
    if (_loading) {
      return SchoolDeskModuleScaffold(
        title: 'Leave Management',
        subtitle: 'Apply for leave and review approval history',
        drawer: drawer,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SchoolDeskModuleScaffold(
        title: 'Leave Management',
        subtitle: 'Apply for leave and review approval history',
        drawer: drawer,
        body: Center(child: Text(_error!)),
      );
    }
    return SchoolDeskModuleScaffold(
      title: 'Leave Management',
      subtitle: 'Apply for leave and review approval history',
      drawer: drawer,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DashboardFabWidget(role: DashboardRole.teacher),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            onPressed: _openLeaveRequestForm,
            backgroundColor: AppTheme.primary,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: Text(
              'Apply Leave',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLeaveBalance(),
            const SizedBox(height: 20),
            Text(
              'Leave History',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ..._leaveHistory.map((l) => _buildLeaveCard(l)),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveBalance() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A5276), Color(0xFF2E86C1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Leave Balance',
            style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildBalanceItem(
                  'Total',
                  _days(_totalLeave),
                  Colors.white,
                ),
              ),
              Expanded(
                child: _buildBalanceItem(
                  'Used',
                  _days(_usedLeave),
                  Colors.orange.shade200,
                ),
              ),
              Expanded(
                child: _buildBalanceItem(
                  'Pending',
                  _days(_pendingLeave),
                  Colors.yellow.shade100,
                ),
              ),
              Expanded(
                child: _buildBalanceItem(
                  'Remaining',
                  _days(_remainingLeave),
                  Colors.greenAccent.shade200,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _totalLeave > 0
                  ? (_usedLeave / _totalLeave).clamp(0, 1)
                  : 0,
              backgroundColor: Colors.white.withAlpha(40),
              color: Colors.white,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_totalLeave > 0 ? (_usedLeave / _totalLeave * 100).round() : 0}% of entitled leave used',
            style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> l) {
    final status = (l['status'] as String? ?? 'pending').toLowerCase();
    final statusColors = {
      'approved': AppTheme.success,
      'pending': AppTheme.warning,
      'rejected': AppTheme.error,
    };
    final color = statusColors[status] ?? AppTheme.muted;
    final leaveType =
        l['leaveType'] as String? ?? l['type'] as String? ?? 'Leave';
    final fromDate = l['fromDate'] as String? ?? l['from'] as String? ?? '';
    final toDate = l['toDate'] as String? ?? l['to'] as String? ?? '';
    final days = _number(l['days']);
    final reason = l['reason'] as String? ?? '';
    final substitute = l['substitute'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  leaveType,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.date_range_rounded,
                size: 13,
                color: AppTheme.muted,
              ),
              const SizedBox(width: 4),
              Text(
                '$fromDate - $toDate (${_days(days)})',
                style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Reason: $reason',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          if (substitute.isNotEmpty)
            Text(
              'Substitute: $substitute',
              style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
            ),
          if (status == 'pending')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.pending_actions_rounded,
                    size: 13,
                    color: AppTheme.warning,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Awaiting Admin/Principal approval',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppTheme.warning,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openLeaveRequestForm() async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.teacherLeaveRequestForm,
      arguments: TeacherLeaveRequestFormArgs(
        staffId: _teacherStaffId,
        staffName: _teacherName,
        leaveTypes: _leaveTypes,
        balances: _balances,
      ),
    );
    if (!mounted || result is! TeacherLeaveRequestResult) return;
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message), backgroundColor: AppTheme.info),
    );
  }
}

_LeaveTotals _balanceTotals(
  List<Map<String, dynamic>> balances,
  List<Map<String, dynamic>> leaveTypes,
  List<LeaveApplicationModel> applications,
) {
  if (balances.isNotEmpty) {
    final total = balances.fold<double>(
      0,
      (sum, balance) => sum + _number(balance['total_entitled']),
    );
    final used = balances.fold<double>(
      0,
      (sum, balance) => sum + _number(balance['used_days']),
    );
    final pending = balances.fold<double>(
      0,
      (sum, balance) => sum + _number(balance['pending_days']),
    );
    final remaining = balances.fold<double>(
      0,
      (sum, balance) => sum + _number(balance['remaining_days']),
    );
    return _LeaveTotals(total, used, pending, remaining);
  }
  final total = leaveTypes.fold<double>(
    0,
    (sum, type) => sum + _number(type['max_days_per_year']),
  );
  final used = applications
      .where((application) => application.status.toLowerCase() == 'approved')
      .fold<double>(0, (sum, application) => sum + application.totalDays);
  final pending = applications
      .where((application) => application.status.toLowerCase() == 'pending')
      .fold<double>(0, (sum, application) => sum + application.totalDays);
  final remaining = (total - used - pending).clamp(0, total);
  return _LeaveTotals(total, used, pending, remaining.toDouble());
}

String _leaveTypeName(Map<String, dynamic> type) {
  return _text(type['leave_name'], fallback: _text(type['name']));
}

String _text(Object? value, {String fallback = ''}) {
  final text = '${value ?? ''}'.trim();
  if (text.isEmpty || text == 'null') return fallback;
  return text;
}

double _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? 0;
}

String _days(double value) {
  final formatted = value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$formatted day${value == 1 ? '' : 's'}';
}

class _LeaveTotals {
  final double total;
  final double used;
  final double pending;
  final double remaining;

  const _LeaveTotals(this.total, this.used, this.pending, this.remaining);
}
