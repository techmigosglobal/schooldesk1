import 'package:flutter/material.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/network/models/backend_models.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';
import 'package:schooldesk1/roles/teacher/data/api_teacher_attendance_repository.dart';
import 'package:schooldesk1/roles/teacher/domain/teacher_attendance_repository.dart';

final class _TeacherAttendanceHistorySnapshot {
  const _TeacherAttendanceHistorySnapshot(this.sessions);

  final List<AttendanceSessionModel> sessions;
}

class TeacherAttendanceHistoryScreen extends StatefulWidget {
  final TeacherAttendanceRepository? repository;

  const TeacherAttendanceHistoryScreen({super.key, this.repository});

  @override
  State<TeacherAttendanceHistoryScreen> createState() =>
      _TeacherAttendanceHistoryScreenState();
}

class _TeacherAttendanceHistoryScreenState
    extends State<TeacherAttendanceHistoryScreen> {
  RepositoryState<_TeacherAttendanceHistorySnapshot> _repositoryState =
      const RepositoryState.loading();
  String _sectionId = '';
  DateTime _date = DateTime.now();
  List<AttendanceSessionModel> _sessions = const [];

  @override
  void initState() {
    super.initState();
    _sectionId = RoleAccessService.teacherClassId;
    _load();
  }

  Future<void> _load() async {
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
      _sectionId = _sectionId.isEmpty
          ? RoleAccessService.teacherClassId
          : _sectionId;
      if (!RoleAccessService.hasTeacherStaffLink) {
        throw Exception(RoleAccessService.teacherScopeStatus);
      }
      if (_sectionId.isEmpty) {
        throw Exception('No classes assigned yet.');
      }
      final result =
          await (widget.repository ??
                  ApiTeacherAttendanceRepository.legacyDefault)
              .loadHistory(
                sectionId: _sectionId,
                date: teacherFlowDate(_date),
              );
      if (result.isFailure) {
        throw StateError(
          result.failureOrNull?.message ?? 'Unable to load attendance history',
        );
      }
      final sessions = result.dataOrNull!;
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _repositoryState = RepositoryState(
          data: _TeacherAttendanceHistorySnapshot(List.unmodifiable(sessions)),
          source: RepositorySource.remote,
          lastUpdated: DateTime.now().toUtc(),
        );
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        final message = error.toString().replaceFirst('Exception: ', '');
        _repositoryState = previous.hasData
            ? RepositoryState(
                data: previous.data,
                source: RepositorySource.cache,
                isStale: true,
                error: message,
                lastUpdated: previous.lastUpdated,
              )
            : RepositoryState.error(error: message);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final classes = RoleAccessService.teacherClassTeacherClasses;
    return TeacherFlowScaffold(
      title: 'Attendance History',
      subtitle: 'Class day registers and review',
      selectedIndex: TeacherNav.attendanceHistory,
      loading: _repositoryState.isLoading && !_repositoryState.hasData,
      error: _repositoryState.isError && !_repositoryState.hasData
          ? '${_repositoryState.error}'
          : null,
      onRefresh: _load,
      child: SchoolDeskRepositoryStateView<_TeacherAttendanceHistorySnapshot>(
        state: _repositoryState,
        onRetry: _load,
        emptyTitle: 'No daily attendance found',
        emptyMessage:
            'Submitted class attendance for the selected date will appear here.',
        data: (_) => TeacherFlowScrollView(
          children: [
            TeacherFlowSectionHeader(
              title: 'Review',
              actionLabel: 'Pick Date',
              onAction: _pickDate,
            ),
            const SizedBox(height: 10),
            if (classes.length > 1) ...[
              DropdownButtonFormField<String>(
                value: _sectionId.isEmpty ? null : _sectionId,
                decoration: const InputDecoration(labelText: 'Class / Section'),
                items: classes
                    .map(
                      (row) => DropdownMenuItem(
                        value: teacherFlowText(row['id'] ?? row['section_id']),
                        child: Text(teacherFlowText(row['label'])),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _sectionId = value);
                  _load();
                },
              ),
              const SizedBox(height: 12),
            ],
            TeacherInfoPill(
              icon: Icons.calendar_today_rounded,
              label: teacherFlowDate(_date),
            ),
            const SizedBox(height: 14),
            if (_sessions.isEmpty)
              const TeacherFlowCard(
                icon: Icons.fact_check_outlined,
                title: 'No daily attendance found.',
                subtitle:
                    'Submitted class attendance for the selected date will appear here.',
              )
            else
              ..._sessions.map((session) {
                final absent = (session.totalStudents - session.presentCount)
                    .clamp(0, session.totalStudents);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TeacherFlowCard(
                    icon: session.isFinalized
                        ? Icons.lock_rounded
                        : Icons.pending_actions_rounded,
                    title: 'Daily attendance',
                    subtitle:
                        'Class day register · Present ${session.presentCount} · Absent $absent · Total ${session.totalStudents}',
                    status: session.isFinalized ? 'Submitted' : 'Pending',
                    statusColor: session.isFinalized
                        ? Colors.green
                        : Colors.orange,
                    body: const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Corrections must be requested through Admin/Principal.',
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked == null) return;
    setState(() => _date = picked);
    await _load();
  }
}
