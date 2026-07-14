import 'package:flutter/material.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/desktop/desktop_responsive_breakpoints.dart';
import 'package:schooldesk1/core/widgets/desktop_screen_wrapper.dart';

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
  String _priority = 'normal';
  List<Map<String, dynamic>> _students = const [];
  List<Map<String, dynamic>> _notes = const [];

  @override
  void initState() {
    super.initState();
    _loadNotes();
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
      final rows = await BackendApiClient.instance.getRawList('/student-notes');
      if (!mounted) return;
      final classStudentIds = students
          .map((s) => teacherFlowText(s['id']))
          .toSet();
      setState(() {
        _students = students;
        if (_selectedStudentId.isEmpty && students.isNotEmpty) {
          _selectedStudentId = teacherFlowText(students.first['id']);
        }
        _notes =
            rows
                .where((note) {
                  final authorId = teacherFlowText(
                    note['author_id'] ?? note['teacher_id'] ?? note['staff_id'],
                  );
                  final noteStudentId = teacherFlowText(note['student_id']);
                  return authorId == RoleAccessService.teacherStaffId ||
                      classStudentIds.contains(noteStudentId);
                })
                .map(_mapNote)
                .toList()
              ..sort(
                (a, b) => teacherFlowText(
                  b['date'],
                ).compareTo(teacherFlowText(a['date'])),
              );
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Map<String, dynamic> _mapNote(Map<String, dynamic> note) {
    final studentId = teacherFlowText(note['student_id']);
    final student = _students.firstWhere(
      (s) => teacherFlowText(s['id']) == studentId,
      orElse: () => const {},
    );
    return {
      'id': note['id'],
      'student_id': studentId,
      'student': teacherFlowText(
        note['student_name'],
        fallback: teacherFlowText(student['name'], fallback: 'Student'),
      ),
      'category': teacherFlowText(note['category'], fallback: 'general'),
      'priority': teacherFlowText(note['priority'], fallback: 'normal'),
      'note': teacherFlowText(note['note'] ?? note['content'] ?? note['title']),
      'date': teacherFlowDateOnly(note['created_at'] ?? note['date']),
    };
  }

  Future<void> _saveNote() async {
    final content = _noteController.text.trim();
    if (_saving || _selectedStudentId.isEmpty || content.isEmpty) return;
    final student = _students.firstWhere(
      (s) => teacherFlowText(s['id']) == _selectedStudentId,
      orElse: () => const {},
    );
    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.createRaw('/student-notes', {
        'teacher_id': RoleAccessService.teacherStaffId,
        'author_id': RoleAccessService.teacherStaffId,
        'student_id': _selectedStudentId,
        'student_name': teacherFlowText(student['name']),
        'class': RoleAccessService.teacherClassName,
        'category': _category,
        'priority': _priority,
        'note': content,
        'author': RoleAccessService.teacherName,
      });
      _noteController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Observation saved'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _saving = false);
      await _loadNotes();
    } on Object catch (error) {
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


  final isDesktop = DesktopBreakpoints.isDesktopWidth(


        MediaQuery.sizeOf(context).width,


      );


      if (isDesktop) {


        return DesktopScreenWrapper(


          breadcrumbs: ['Academics', 'Notes'],


          title: 'Student Notes',


          actions: const [],


          child: Card(


            elevation: 0,


            child: Padding(


              padding: const EdgeInsets.all(32),


              child: Center(


                child: Column(


                  mainAxisSize: MainAxisSize.min,


                  children: [


                    Icon(Icons.desktop_windows_rounded, size: 48, color: Theme.of(context).colorScheme.primary),


                    const SizedBox(height: 16),


                    Text('Student Notes', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),


                    const SizedBox(height: 8),


                    Text('Desktop view coming soon', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5))),


                  ],


                ),


              ),


            ),


          ),


        );


      }

    return TeacherFlowScaffold(
      title: 'Student Notes',
      subtitle: 'Record observations and track student progress',
      selectedIndex: TeacherNav.studentNotes,
      loading: _loading,
      error: _error,
      onRefresh: _loadNotes,
      child: TeacherFlowScrollView(
        children: [
          TeacherCurrentClassCard(
            greeting: 'Observation log',
            classLabel: teacherCurrentClassLabel(),
            subject: RoleAccessService.teacherSubject,
            timeLabel: '${_notes.length} notes recorded',
            actions: [
              TeacherFlowAction(
                label: 'Save',
                icon: Icons.save_rounded,
                filled: true,
                onTap: _saving ? null : _saveNote,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _noteComposer(),
          const SizedBox(height: 18),
          const TeacherFlowSectionHeader(title: 'Previous Observations'),
          const SizedBox(height: 10),
          if (_notes.isEmpty)
            const TeacherFlowCard(
              icon: Icons.sticky_note_2_outlined,
              title: 'No observations yet',
              subtitle:
                  'Student notes you record will appear here. Use the form above to add the first observation.',
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
      icon: Icons.edit_note_rounded,
      title: 'New observation',
      subtitle: 'Keep notes factual, specific, and supportive.',
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
                      value: 'behaviour',
                      child: Text('Behaviour'),
                    ),
                    DropdownMenuItem(value: 'health', child: Text('Health')),
                    DropdownMenuItem(value: 'general', child: Text('General')),
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
                    DropdownMenuItem(value: 'normal', child: Text('Normal')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) =>
                            setState(() => _priority = value ?? 'normal'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteController,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Observation details',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noteCard(Map<String, dynamic> note) {
    final priority = teacherFlowText(note['priority'], fallback: 'normal');
    final category = teacherFlowText(note['category'], fallback: 'general');
    return TeacherFlowCard(
      icon: Icons.sticky_note_2_rounded,
      title: teacherFlowText(note['student'], fallback: 'Student'),
      subtitle: teacherFlowText(note['note'], fallback: 'No content'),
      status: teacherFlowTitleCase(category),
      statusColor: _priorityColor(priority),
      body: TeacherFlowActionWrap(
        actions: [
          TeacherFlowAction(
            label: teacherFlowTitleCase(priority),
            icon: _priorityIcon(priority),
          ),
          TeacherFlowAction(
            label: teacherFlowText(note['date'], fallback: 'Today'),
            icon: Icons.calendar_today_outlined,
          ),
        ],
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'high':
        return context.appTheme.error;
      case 'normal':
        return context.appTheme.primary;
      default:
        return teacherFlowMuted;
    }
  }

  IconData _priorityIcon(String priority) {
    switch (priority) {
      case 'high':
        return Icons.priority_high_rounded;
      case 'normal':
        return Icons.horizontal_rule_rounded;
      default:
        return Icons.low_priority_rounded;
    }
  }
}
