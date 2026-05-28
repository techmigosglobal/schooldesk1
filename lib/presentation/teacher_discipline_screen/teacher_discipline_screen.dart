import 'package:flutter/material.dart';

import '../../services/backend_api_client.dart';
import '../../services/role_access_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/teacher_flow_ui.dart';

class TeacherDisciplineScreen extends StatefulWidget {
  const TeacherDisciplineScreen({super.key});

  @override
  State<TeacherDisciplineScreen> createState() =>
      _TeacherDisciplineScreenState();
}

class _TeacherDisciplineScreenState extends State<TeacherDisciplineScreen> {
  final _descriptionController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _selectedStudentId = '';
  String _incidentType = 'conduct';
  String _severity = 'medium';
  List<Map<String, dynamic>> _students = const [];
  List<Map<String, dynamic>> _incidents = const [];

  @override
  void initState() {
    super.initState();
    _loadIncidents();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadIncidents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await RoleAccessService.initialize();
      final students = RoleAccessService.teacherClassStudents;
      final rows = await BackendApiClient.instance.getRawList(
        '/discipline-incidents',
      );
      if (!mounted) return;
      setState(() {
        _students = students;
        if (_selectedStudentId.isEmpty && students.isNotEmpty) {
          _selectedStudentId = teacherFlowText(students.first['id']);
        }
        _incidents = rows.where(_belongsToTeacher).map(_mapIncident).toList()
          ..sort(
            (a, b) => teacherFlowText(
              b['date'],
            ).compareTo(teacherFlowText(a['date'])),
          );
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

  bool _belongsToTeacher(Map<String, dynamic> incident) {
    final teacherId = teacherFlowText(
      incident['teacher_id'] ?? incident['staff_id'],
    );
    final studentId = teacherFlowText(incident['student_id']);
    if (teacherId.isNotEmpty && teacherId == RoleAccessService.teacherStaffId) {
      return true;
    }
    return RoleAccessService.teacherClassStudents.any(
      (student) => teacherFlowText(student['id']) == studentId,
    );
  }

  Map<String, dynamic> _mapIncident(Map<String, dynamic> incident) {
    final studentId = teacherFlowText(incident['student_id']);
    final student = _students.firstWhere(
      (row) => teacherFlowText(row['id']) == studentId,
      orElse: () => const {},
    );
    return {
      'id': incident['id'],
      'student_id': studentId,
      'student': teacherFlowText(
        incident['student_name'],
        fallback: teacherFlowText(student['name'], fallback: 'Student'),
      ),
      'type': teacherFlowText(
        incident['type'] ?? incident['incident_type'],
        fallback: 'conduct',
      ),
      'severity': teacherFlowText(incident['severity'], fallback: 'medium'),
      'status': teacherFlowText(incident['status'], fallback: 'open'),
      'description': teacherFlowText(
        incident['description'] ?? incident['title'],
      ),
      'date': teacherFlowDateOnly(incident['created_at'] ?? incident['date']),
      'escalated':
          incident['escalated_to_principal'] == true ||
          incident['escalated'] == true,
    };
  }

  Future<void> _saveIncident() async {
    final description = _descriptionController.text.trim();
    if (_saving || _selectedStudentId.isEmpty || description.isEmpty) return;
    final student = _students.firstWhere(
      (row) => teacherFlowText(row['id']) == _selectedStudentId,
      orElse: () => const {},
    );
    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.createRaw('/discipline-incidents', {
        'teacher_id': RoleAccessService.teacherStaffId,
        'student_id': _selectedStudentId,
        'student_name': teacherFlowText(student['name']),
        'class': RoleAccessService.teacherClassName,
        'type': _incidentType,
        'severity': _severity,
        'description': description,
        'status': 'open',
        'reported_by': RoleAccessService.teacherName,
      });
      _descriptionController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incident recorded'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _saving = false);
      await _loadIncidents();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _updateStatus(
    Map<String, dynamic> incident,
    String status,
  ) async {
    final id = teacherFlowText(incident['id']);
    if (id.isEmpty) return;
    await BackendApiClient.instance.updateRaw('/discipline-incidents/$id', {
      'status': status,
      'teacher_id': RoleAccessService.teacherStaffId,
    });
    await _loadIncidents();
  }

  Future<void> _escalate(Map<String, dynamic> incident) async {
    final id = teacherFlowText(incident['id']);
    if (id.isEmpty) return;
    await BackendApiClient.instance.createRaw('/complaints', {
      'title': 'Discipline follow-up: ${teacherFlowText(incident['student'])}',
      'description': teacherFlowText(incident['description']),
      'category': 'Discipline',
      'priority': teacherFlowText(incident['severity'], fallback: 'medium'),
      'status': 'open',
      'source': 'teacher_discipline',
      'incident_id': id,
      'submitted_by': RoleAccessService.teacherName,
    });
    await BackendApiClient.instance.updateRaw('/discipline-incidents/$id', {
      'status': 'escalated',
      'escalated_to_principal': true,
    });
    await _loadIncidents();
  }

  @override
  Widget build(BuildContext context) {
    final open = _incidents
        .where((row) => teacherFlowText(row['status']) == 'open')
        .length;
    final escalated = _incidents
        .where((row) => teacherFlowText(row['status']) == 'escalated')
        .length;
    return TeacherFlowScaffold(
      title: 'Student Conduct',
      subtitle: 'Record incidents, resolve actions, and escalate when needed',
      selectedIndex: 11,
      loading: _loading,
      error: _error,
      onRefresh: _loadIncidents,
      child: TeacherFlowScrollView(
        children: [
          TeacherCurrentClassCard(
            greeting: 'Conduct workflow',
            classLabel: teacherCurrentClassLabel(),
            subject: '$open open incidents',
            timeLabel: '$escalated escalated',
            actions: [
              TeacherFlowAction(
                label: 'Record',
                icon: Icons.report_rounded,
                filled: true,
                onTap: _saving ? null : _saveIncident,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _incidentComposer(),
          const SizedBox(height: 18),
          const TeacherFlowSectionHeader(title: 'Incident Records'),
          const SizedBox(height: 10),
          if (_incidents.isEmpty)
            const TeacherFlowCard(
              icon: Icons.verified_user_outlined,
              title: 'No incidents',
              subtitle: 'Backend conduct records for this class appear here.',
            )
          else
            ..._incidents.map(
              (incident) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _incidentCard(incident),
              ),
            ),
        ],
      ),
    );
  }

  Widget _incidentComposer() {
    return TeacherFlowCard(
      icon: Icons.report_rounded,
      title: 'Record conduct event',
      subtitle: 'Keep the description factual and action oriented.',
      body: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _selectedStudentId.isEmpty ? null : _selectedStudentId,
            decoration: const InputDecoration(
              labelText: 'Student',
              prefixIcon: Icon(Icons.person_rounded),
            ),
            items: [
              for (final student in _students)
                DropdownMenuItem(
                  value: teacherFlowText(student['id']),
                  child: Text(
                    teacherFlowText(student['name'], fallback: 'Student'),
                  ),
                ),
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() => _selectedStudentId = value ?? ''),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _incidentType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'conduct', child: Text('Conduct')),
                    DropdownMenuItem(
                      value: 'attendance',
                      child: Text('Attendance'),
                    ),
                    DropdownMenuItem(value: 'safety', child: Text('Safety')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) =>
                            setState(() => _incidentType = value ?? 'conduct'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _severity,
                  decoration: const InputDecoration(labelText: 'Severity'),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) =>
                            setState(() => _severity = value ?? 'medium'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'What happened?',
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _incidentCard(Map<String, dynamic> incident) {
    final status = teacherFlowText(incident['status'], fallback: 'open');
    final severity = teacherFlowText(incident['severity'], fallback: 'medium');
    return TeacherFlowCard(
      icon: Icons.health_and_safety_rounded,
      title: teacherFlowText(incident['student'], fallback: 'Student'),
      subtitle: teacherFlowText(
        incident['description'],
        fallback: 'Incident details unavailable',
      ),
      status: teacherFlowTitleCase(status),
      statusColor: _statusColor(status, severity),
      body: TeacherFlowActionWrap(
        actions: [
          TeacherFlowAction(
            label: 'Resolve',
            icon: Icons.done_all_rounded,
            onTap: status == 'resolved'
                ? null
                : () => _updateStatus(incident, 'resolved'),
          ),
          TeacherFlowAction(
            label: 'Escalate',
            icon: Icons.keyboard_double_arrow_up_rounded,
            onTap: status == 'escalated' ? null : () => _escalate(incident),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status, String severity) {
    if (status == 'resolved') return AppTheme.success;
    if (status == 'escalated' || severity == 'high') return AppTheme.error;
    if (severity == 'low') return teacherFlowAccent;
    return AppTheme.warning;
  }
}
