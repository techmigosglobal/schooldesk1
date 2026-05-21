import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend_api_client.dart';
import '../../services/role_access_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_module_scaffold.dart';
import '../../widgets/teacher_navigation.dart';

class TeacherStudentNotesScreen extends StatefulWidget {
  const TeacherStudentNotesScreen({super.key});

  @override
  State<TeacherStudentNotesScreen> createState() =>
      _TeacherStudentNotesScreenState();
}

class _TeacherStudentNotesScreenState extends State<TeacherStudentNotesScreen> {
  int _selectedNavIndex = 6;
  List<Map<String, dynamic>> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final notes = await BackendApiClient.instance.getRawList('/student-notes');
    setState(() {
      _notes = notes.where(_isTeacherNote).map(_mapNote).toList();
      _loading = false;
    });
  }

  bool _isTeacherNote(Map<String, dynamic> note) {
    final teacherId = note['teacher_id']?.toString() ?? '';
    final studentId = note['student_id']?.toString() ?? '';
    if (teacherId.isNotEmpty && teacherId == RoleAccessService.teacherStaffId) {
      return true;
    }
    return RoleAccessService.teacherClassStudents.any(
      (student) => student['id']?.toString() == studentId,
    );
  }

  Map<String, dynamic> _mapNote(Map<String, dynamic> note) {
    final studentId = note['student_id']?.toString() ?? '';
    final student = _studentFor(studentId);
    return {
      'id': note['id'],
      'student_id': studentId,
      'student': note['student_name'] ?? student['name'] ?? studentId,
      'class':
          note['class'] ??
          student['class'] ??
          RoleAccessService.teacherClassName,
      'roll': note['roll'] ?? student['roll'] ?? '',
      'type': note['category'] ?? note['type'] ?? 'academic',
      'note': note['note'] ?? note['description'] ?? note['title'] ?? '',
      'date': _formatBackendDate(note['created_at']),
      'priority': note['priority'] ?? 'medium',
    };
  }

  Map<String, dynamic> _studentFor(String studentId) {
    return RoleAccessService.teacherClassStudents.firstWhere(
      (student) => student['id']?.toString() == studentId,
      orElse: () => const {},
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SchoolDeskModuleScaffold(
        title: 'Student Notes',
        subtitle: 'Capture private student observations and follow-ups',
        drawer: TeacherDrawer(
          selectedIndex: _selectedNavIndex,
          onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return SchoolDeskModuleScaffold(
      title: 'Student Notes',
      subtitle: 'Capture private student observations and follow-ups',
      drawer: TeacherDrawer(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DashboardFabWidget(role: DashboardRole.teacher),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            onPressed: _showAddNoteSheet,
            backgroundColor: AppTheme.primary,
            icon: const Icon(Icons.note_add_rounded, color: Colors.white),
            label: Text(
              'Add Note',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: _notes.isEmpty
          ? Center(
              child: Text(
                'No notes yet. Tap + to add one.',
                style: GoogleFonts.dmSans(color: AppTheme.muted),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _notes.length,
              itemBuilder: (context, i) => _buildNoteCard(_notes[i], i),
            ),
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> n, int index) {
    final typeColors = {
      'academic': AppTheme.error,
      'behavior': AppTheme.warning,
      'strength': AppTheme.success,
      'participation': AppTheme.info,
    };
    final priorityColors = {
      'high': AppTheme.error,
      'medium': AppTheme.warning,
      'low': AppTheme.success,
    };
    final color = typeColors[n['type']] ?? AppTheme.muted;
    final priorityColor = priorityColors[n['priority']] ?? AppTheme.muted;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(40)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    n['student'].toString().substring(0, 1),
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n['student'] as String,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Class ${n['class']} · Roll ${n['roll']}',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: color.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      n['type'] as String,
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${n['priority']} priority',
                      style: GoogleFonts.dmSans(
                        fontSize: 9,
                        color: priorityColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            n['note'] as String,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 12,
                color: AppTheme.muted,
              ),
              const SizedBox(width: 4),
              Text(
                n['date'] as String,
                style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final id = n['id']?.toString() ?? '';
                  if (id.isNotEmpty) {
                    await BackendApiClient.instance.deleteRaw(
                      '/student-notes/$id',
                    );
                  }
                  await _loadData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Note deleted'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  'Delete',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showAddNoteSheet() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _AddStudentNotePage()),
    );
    if (!mounted || saved != true) return;
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Note saved'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatBackendDate(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return '';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${parsed.day} ${months[parsed.month - 1]}';
  }
}

class _AddStudentNotePage extends StatefulWidget {
  const _AddStudentNotePage();

  @override
  State<_AddStudentNotePage> createState() => _AddStudentNotePageState();
}

class _AddStudentNotePageState extends State<_AddStudentNotePage> {
  final _formKey = GlobalKey<FormState>();
  final _noteCtrl = TextEditingController();
  final _studentCtrl = TextEditingController();
  String _noteType = 'academic';
  String _priority = 'medium';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _noteCtrl.dispose();
    _studentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await BackendApiClient.instance.createRaw('/student-notes', {
        'student_id': _studentCtrl.text.trim(),
        'student_name': _studentCtrl.text.trim(),
        'teacher_id': RoleAccessService.teacherStaffId,
        'class': RoleAccessService.teacherClassName,
        'category': _noteType,
        'note': _noteCtrl.text.trim(),
        'priority': _priority,
        'visibility': 'staff',
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Student note could not be saved: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Student Note')),
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
              TextFormField(
                controller: _studentCtrl,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Student ID or name from backend',
                ),
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Enter the student ID or name.'
                    : null,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['academic', 'behavior', 'strength', 'participation']
                    .map(
                      (t) => ChoiceChip(
                        label: Text(t),
                        selected: _noteType == t,
                        onSelected: _saving
                            ? null
                            : (_) => setState(() => _noteType = t),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: ['high', 'medium', 'low']
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _priority = v ?? _priority),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteCtrl,
                enabled: !_saving,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Note'),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Enter a note.' : null,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Note'),
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
        color: AppTheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.error),
      ),
    );
  }
}
