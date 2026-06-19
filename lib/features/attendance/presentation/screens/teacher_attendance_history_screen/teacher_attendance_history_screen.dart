import 'package:flutter/material.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';

class TeacherAttendanceHistoryScreen extends StatefulWidget {
  const TeacherAttendanceHistoryScreen({super.key});

  @override
  State<TeacherAttendanceHistoryScreen> createState() =>
      _TeacherAttendanceHistoryScreenState();
}

class _TeacherAttendanceHistoryScreenState
    extends State<TeacherAttendanceHistoryScreen> {
  bool _loading = true;
  String? _error;
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
    setState(() {
      _loading = true;
      _error = null;
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
      final sessions = await BackendApiClient.instance.getAttendanceSessions(
        sectionId: _sectionId,
        date: teacherFlowDate(_date),
      );
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final classes = RoleAccessService.teacherClassTeacherClasses;
    return TeacherFlowScaffold(
      title: 'Attendance History',
      subtitle: 'Submitted sessions and review',
      selectedIndex: 20,
      loading: _loading,
      error: _error,
      onRefresh: _load,
      child: TeacherFlowScrollView(
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
              title: 'No attendance sessions found.',
              subtitle:
                  'Submitted sessions for the selected class and date will appear here.',
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
                  title: 'Period ${session.periodNumber}',
                  subtitle:
                      'Present ${session.presentCount} · Absent/Late $absent · Total ${session.totalStudents}',
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
