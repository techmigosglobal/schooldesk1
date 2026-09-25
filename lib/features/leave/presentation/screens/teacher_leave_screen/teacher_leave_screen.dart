import 'package:flutter/material.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/network/models/backend_models.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';
import 'package:schooldesk1/features/leave/presentation/screens/teacher_leave_screen/teacher_leave_request_form_screen.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/roles/teacher/data/api_teacher_leave_repository.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_leave_repository.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_leave_context.dart';

import 'package:schooldesk1/core/navigation/schooldesk_navigation.dart';

class TeacherLeaveScreen extends StatefulWidget {
  final TeacherLeaveRepository? repository;

  const TeacherLeaveScreen({super.key, this.repository});

  @override
  State<TeacherLeaveScreen> createState() => _TeacherLeaveScreenState();
}

class _TeacherLeaveScreenState extends State<TeacherLeaveScreen> {
  RepositoryState<TeacherLeaveContext> _repositoryState =
      const RepositoryState.loading();
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

  Future<void> _loadLeave({bool forceRefresh = false}) async {
    final previous = _repositoryState;
    setState(() {
      _repositoryState = RepositoryState.loading(
        data: previous.data,
        source: previous.source,
        isStale: previous.isStale,
        isRefreshing: previous.hasData,
        lastUpdated: previous.lastUpdated,
      );
    });
    try {
      await RoleAccessService.initialize();
      final result =
          await (widget.repository ?? ApiTeacherLeaveRepository.legacyDefault)
              .load(
                staffId: RoleAccessService.teacherStaffId,
                forceRefresh: forceRefresh,
              );
      if (result.isFailure) {
        throw StateError(
          result.failureOrNull?.message ?? 'Unable to load leave',
        );
      }
      final snapshot = result.dataOrNull!;
      if (!mounted) return;
      setState(() {
        _staffId = snapshot.staffId;
        _staffName = RoleAccessService.teacherName;
        _leaveTypes = snapshot.leaveTypes;
        _balances = snapshot.balances;
        _applications = snapshot.applications;
        _repositoryState = RepositoryState(
          data: snapshot,
          source: RepositorySource.remote,
          lastUpdated: DateTime.now().toUtc(),
        );
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _repositoryState = previous.hasData
            ? RepositoryState(
                data: previous.data,
                source: RepositorySource.cache,
                isStale: true,
                error: error,
                lastUpdated: previous.lastUpdated,
              )
            : RepositoryState.error(error: error);
      });
    }
  }

  Future<void> _openApply() async {
    final result = await SchoolDeskNavigation.push(
      context,
      AppRoutes.teacherLeaveRequestForm,
      arguments: TeacherLeaveRequestFormArgs(
        staffId: _staffId,
        staffName: _staffName,
        leaveTypes: _leaveTypes,
        balances: _balances,
        repository: widget.repository,
      ),
    );
    if (result != null) await _loadLeave();
  }

  Future<void> _recallApplication(LeaveApplicationModel app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recall Leave Request'),
        content: Text(
          'Recall your ${_leaveTypeLabel(app.leaveTypeId)} request from '
          '${app.fromDate.split('T').first} to ${app.toDate.split('T').first}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Recall'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final result =
          await (widget.repository ?? ApiTeacherLeaveRepository.legacyDefault)
              .recall(app.id);
      if (result.isFailure) {
        throw StateError(
          result.failureOrNull?.message ?? 'Unable to recall leave request',
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Leave request recalled')));
      await _loadLeave();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to recall leave request: $error')),
      );
    }
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
      selectedIndex: TeacherNav.leave,
      loading: _repositoryState.isLoading && !_repositoryState.hasData,
      error: _repositoryState.isError && !_repositoryState.hasData
          ? '${_repositoryState.error}'
          : null,
      onRefresh: () => _loadLeave(forceRefresh: true),
      child: SchoolDeskRepositoryStateView<TeacherLeaveContext>(
        state: _repositoryState,
        onRetry: () => _loadLeave(),
        emptyTitle: 'No leave data',
        emptyMessage: 'Leave data is not available for this teacher scope.',
        data: (_) => TeacherFlowScrollView(
          children: [
            TeacherCurrentClassCard(
              greeting: 'Leave desk',
              classLabel: _staffName,
              subject: pending == 0
                  ? 'No pending requests'
                  : '$pending pending',
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
            const TeacherFlowSectionHeader(title: 'Leave History'),
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
                    title: _leaveTypeLabel(app.leaveTypeId),
                    subtitle:
                        '${app.fromDate.split('T').first} to ${app.toDate.split('T').first} · ${app.reason ?? ''}',
                    status: teacherFlowTitleCase(app.status),
                    statusColor: _statusColor(app.status),
                    body: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TeacherInfoPill(
                              icon: Icons.timer_rounded,
                              label:
                                  '${app.totalDays.toStringAsFixed(1)} day(s)',
                            ),
                            const TeacherInfoPill(
                              icon: Icons.swap_horiz_rounded,
                              label: 'Substitute shown after approval',
                            ),
                          ],
                        ),
                        if (app.status == 'pending') ...[
                          const SizedBox(height: 10),
                          TeacherFlowActionWrap(
                            actions: [
                              TeacherFlowAction(
                                label: 'Recall',
                                icon: Icons.undo_rounded,
                                onTap: () => _recallApplication(app),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'approved' => Colors.green,
      'rejected' => context.appTheme.error,
      'pending' => Colors.orange,
      _ => teacherFlowAccent,
    };
  }

  String _leaveTypeLabel(String leaveTypeId) {
    final normalizedId = leaveTypeId.trim();
    for (final type in _leaveTypes) {
      final id = teacherFlowText(type['id'] ?? type['leave_type_id']);
      if (id == normalizedId) {
        final label = teacherFlowText(
          type['leave_name'] ??
              type['name'] ??
              type['type_name'] ??
              type['label'] ??
              type['code'],
        );
        if (label.isNotEmpty) return label;
      }
    }
    if (normalizedId.isEmpty || _looksLikeRawId(normalizedId)) {
      return 'Leave request';
    }
    return teacherFlowTitleCase(normalizedId.replaceAll('_', ' '));
  }

  bool _looksLikeRawId(String value) {
    final compact = value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (compact.length >= 16) return true;
    return RegExp(r'^[a-fA-F0-9]{2,}([ -]?[a-fA-F0-9]{2,})+$').hasMatch(value);
  }
}
