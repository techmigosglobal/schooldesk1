import 'package:flutter/material.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';

class TeacherStudentNotesScreen extends StatefulWidget {
  const TeacherStudentNotesScreen({super.key});

  @override
  State<TeacherStudentNotesScreen> createState() =>
      _TeacherStudentNotesScreenState();
}

class _TeacherStudentNotesScreenState extends State<TeacherStudentNotesScreen> {
  final _noteController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _selectedStudentId = '';
  String _category = 'academic';
  String _priority = 'medium';
  List<Map<String, dynamic>> _students = const [];
  List<Map<String, dynamic>> _notes = const [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && _selectedStudentId.isEmpty) {
      _selectedStudentId = teacherFlowText(args['student_id']);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await RoleAccessService.initialize();
      final students = RoleAccessService.teacherClassStudents;
      final notes = await BackendApiClient.instance.getRawList(
        '/student-notes',
      );
      if (!mounted) return;
      setState(() {
        _students = students;
        final selectedExists = students.any(
          (student) => teacherFlowText(student['id']) == _selectedStudentId,
        );
        _selectedStudentId = selectedExists
            ? _selectedStudentId
            : (students.isNotEmpty
                  ? teacherFlowText(students.first['id'])
                  : '');
        _notes = notes.where(_belongsToTeacher).map(_mapNote).toList()
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

  bool _belongsToTeacher(Map<String, dynamic> note) {
    final teacherId = teacherFlowText(note['teacher_id'] ?? note['staff_id']);
    final studentId = teacherFlowText(note['student_id']);
    if (teacherId.isNotEmpty && teacherId == RoleAccessService.teacherStaffId) {
      return true;
    }
    return RoleAccessService.teacherClassStudents.any(
      (student) => teacherFlowText(student['id']) == studentId,
    );
  }

  Map<String, dynamic> _mapNote(Map<String, dynamic> note) {
    final studentId = teacherFlowText(note['student_id']);
    final student = _students.firstWhere(
      (row) => teacherFlowText(row['id']) == studentId,
      orElse: () => const {},
    );
    return {
      'id': note['id'],
      'student_id': studentId,
      'student': teacherFlowText(
        note['student_name'],
        fallback: teacherFlowText(student['name'], fallback: 'Student'),
      ),
      'roll': teacherFlowText(student['roll'] ?? note['roll'], fallback: '-'),
      'category': teacherFlowText(
        note['category'] ?? note['type'],
        fallback: 'academic',
      ),
      'priority': teacherFlowText(note['priority'], fallback: 'medium'),
      'note': teacherFlowText(
        note['note'] ?? note['description'] ?? note['title'],
      ),
      'date': teacherFlowDateOnly(note['created_at'] ?? note['date']),
    };
  }

  Future<void> _saveNote() async {
    final note = _noteController.text.trim();
    if (_saving || _selectedStudentId.isEmpty || note.isEmpty) return;
    final student = _students.firstWhere(
      (row) => teacherFlowText(row['id']) == _selectedStudentId,
      orElse: () => const {},
    );
    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.createRaw('/student-notes', {
        'student_id': _selectedStudentId,
        'student_name': teacherFlowText(student['name']),
        'teacher_id': RoleAccessService.teacherStaffId,
        'category': _category,
        'priority': _priority,
        'note': note,
        'class': RoleAccessService.teacherClassName,
      });
      _noteController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student note saved'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _saving = false);
      await _loadNotes();
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

  @override
  Widget build(BuildContext context) {
    final highPriority = _notes
        .where((row) => teacherFlowText(row['priority']) == 'high')
        .length;
    return TeacherFlowScaffold(
      title: 'Student Notes',
      subtitle: 'Private observations and follow-ups for class students',
      selectedIndex: 6,
      loading: _loading,
      error: _error,
      onRefresh: _loadNotes,
      child: TeacherFlowScrollView(
        children: [
          TeacherCurrentClassCard(
            greeting: 'Observation notebook',
            classLabel: teacherCurrentClassLabel(),
            subject: '${_students.length} linked students',
            timeLabel: '$highPriority priority notes',
            actions: [
              TeacherFlowAction(
                label: 'Save Note',
                icon: Icons.note_add_rounded,
                filled: true,
                onTap: _saving ? null : _saveNote,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _noteComposer(),
          const SizedBox(height: 18),
          const TeacherFlowSectionHeader(title: 'Recent Notes'),
          const SizedBox(height: 10),
          if (_notes.isEmpty)
            const TeacherFlowCard(
              icon: Icons.sticky_note_2_outlined,
              title: 'No notes yet',
              subtitle: 'Backend student observations will appear here.',
            )
          else
            ..._notes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _noteCard(note),
              ),
            ),
        ],
      ),
    );
  }

  Widget _noteComposer() {
    return TeacherFlowCard(
      icon: Icons.note_add_rounded,
      title: 'Add observation',
      subtitle: 'Capture academic, behavior, or support notes privately.',
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
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(
                      value: 'academic',
                      child: Text('Academic'),
                    ),
                    DropdownMenuItem(
                      value: 'behavior',
                      child: Text('Behavior'),
                    ),
                    DropdownMenuItem(value: 'support', child: Text('Support')),
                    DropdownMenuItem(
                      value: 'strength',
                      child: Text('Strength'),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) =>
                            setState(() => _category = value ?? 'academic'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) =>
                            setState(() => _priority = value ?? 'medium'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Observation',
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noteCard(Map<String, dynamic> note) {
    final priority = teacherFlowText(note['priority'], fallback: 'medium');
    return TeacherFlowCard(
      icon: Icons.sticky_note_2_rounded,
      title: teacherFlowText(note['student'], fallback: 'Student'),
      subtitle: teacherFlowText(note['note'], fallback: 'No note text'),
      status: teacherFlowTitleCase(priority),
      statusColor: _priorityColor(priority),
      body: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          TeacherInfoPill(
            icon: Icons.badge_rounded,
            label: 'Roll ${teacherFlowText(note['roll'], fallback: '-')}',
          ),
          TeacherInfoPill(
            icon: Icons.category_rounded,
            label: teacherFlowTitleCase(
              teacherFlowText(note['category'], fallback: 'academic'),
            ),
          ),
          TeacherInfoPill(
            icon: Icons.calendar_month_rounded,
            label: teacherFlowText(note['date'], fallback: 'Today'),
          ),
        ],
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'high':
        return AppTheme.error;
      case 'low':
        return AppTheme.success;
      default:
        return AppTheme.warning;
    }
  }
}
