import 'package:flutter/material.dart';

import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';
import 'package:schooldesk1/features/leave/presentation/screens/teacher_leave_screen/teacher_leave_request_form_screen.dart';

class TeacherLeaveScreen extends StatefulWidget {
  const TeacherLeaveScreen({super.key});

  @override
  State<TeacherLeaveScreen> createState() => _TeacherLeaveScreenState();
}

class _TeacherLeaveScreenState extends State<TeacherLeaveScreen> {
  bool _loading = true;
  String? _error;
  String _staffId = '';
  String _staffName = 'Teacher';
  List<Map<String, dynamic>> _leaveTypes = const [];
  List<Map<String, dynamic>> _balances = const [];
  List<LeaveApplicationModel> _applications = const [];

  @override
  void initState() {
    super.initState();
    _loadLeave();
  }

  Future<void> _loadLeave() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await RoleAccessService.initialize();
      final api = BackendApiClient.instance;
      final dashboard = await api.getDashboard('teacher');
      final staffId = teacherFlowText(
        dashboard['staff_id'],
        fallback: RoleAccessService.teacherStaffId,
      );
      final results = await Future.wait([
        api.getLeaveTypes(),
        api.getLeaveBalances(staffId: staffId),
        api.getLeaveApplications(staffId: staffId),
      ]);
      if (!mounted) return;
      setState(() {
        _staffId = staffId;
        _staffName = RoleAccessService.teacherName;
        _leaveTypes = (results[0] as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        _balances = (results[1] as List)
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        _applications = (results[2] as List)
            .whereType<LeaveApplicationModel>()
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _openApply() async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.teacherLeaveRequestForm,
      arguments: TeacherLeaveRequestFormArgs(
        staffId: _staffId,
        staffName: _staffName,
        leaveTypes: _leaveTypes,
        balances: _balances,
      ),
    );
    if (result != null) await _loadLeave();
  }

  @override
  Widget build(BuildContext context) {
    final pending = _applications
        .where((app) => app.status == 'pending')
        .length;
    final approved = _applications
        .where((app) => app.status == 'approved')
        .length;
    return TeacherFlowScaffold(
      title: 'My Leaves',
      subtitle: 'Apply, track status, and see substitute coverage',
      selectedIndex: 10,
      loading: _loading,
      error: _error,
      onRefresh: _loadLeave,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _staffId.isEmpty ? null : _openApply,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Apply'),
      ),
      child: TeacherFlowScrollView(
        children: [
          TeacherCurrentClassCard(
            greeting: 'Leave desk',
            classLabel: _staffName,
            subject: pending == 0 ? 'No pending requests' : '$pending pending',
            timeLabel: 'Admin review and substitute assignment',
            actions: [
              TeacherFlowAction(
                label: 'Apply Leave',
                icon: Icons.event_busy_rounded,
                filled: true,
                onTap: _staffId.isEmpty ? null : _openApply,
              ),
            ],
          ),
          const SizedBox(height: 18),
          TeacherFlowMetricGrid(
            metrics: [
              TeacherFlowMetric(
                label: 'Balance Rows',
                value: '${_balances.length}',
                icon: Icons.account_balance_wallet_rounded,
                color: teacherFlowAccent,
                tone: const Color(0xFFE3FAF5),
              ),
              TeacherFlowMetric(
                label: 'Pending',
                value: '$pending',
                icon: Icons.hourglass_top_rounded,
                color: Colors.orange,
                tone: const Color(0xFFFFF4E5),
              ),
              TeacherFlowMetric(
                label: 'Approved',
                value: '$approved',
                icon: Icons.check_circle_rounded,
                color: Colors.green,
                tone: const Color(0xFFEAFBF0),
              ),
              TeacherFlowMetric(
                label: 'History',
                value: '${_applications.length}',
                icon: Icons.history_rounded,
                color: Colors.indigo,
                tone: const Color(0xFFEAF0FF),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TeacherFlowSectionHeader(title: 'Leave History'),
          const SizedBox(height: 10),
          if (_applications.isEmpty)
            const TeacherFlowCard(
              icon: Icons.event_available_rounded,
              title: 'No leave requests',
              subtitle: 'Your submitted leave requests appear here.',
            )
          else
            ..._applications.map(
              (app) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TeacherFlowCard(
                  icon: Icons.event_busy_rounded,
                  title: app.leaveTypeId,
                  subtitle:
                      '${app.fromDate.split('T').first} to ${app.toDate.split('T').first} · ${app.reason ?? ''}',
                  status: teacherFlowTitleCase(app.status),
                  statusColor: _statusColor(app.status),
                  body: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TeacherInfoPill(
                        icon: Icons.timer_rounded,
                        label: '${app.totalDays.toStringAsFixed(1)} day(s)',
                      ),
                      const TeacherInfoPill(
                        icon: Icons.swap_horiz_rounded,
                        label: 'Substitute shown after approval',
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'approved' => Colors.green,
      'rejected' => AppTheme.error,
      'pending' => Colors.orange,
      _ => teacherFlowAccent,
    };
  }
}
