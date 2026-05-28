import 'package:flutter/material.dart';

import '../../services/backend_api_client.dart';
import '../../services/role_access_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/teacher_flow_ui.dart';

class TeacherDiaryScreen extends StatefulWidget {
  const TeacherDiaryScreen({super.key});

  @override
  State<TeacherDiaryScreen> createState() => _TeacherDiaryScreenState();
}

class _TeacherDiaryScreenState extends State<TeacherDiaryScreen> {
  final _classworkController = TextEditingController();
  final _homeworkController = TextEditingController();
  final _noteController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _entryType = 'regular';
  List<Map<String, dynamic>> _entries = const [];

  @override
  void initState() {
    super.initState();
    _loadDiary();
  }

  @override
  void dispose() {
    _classworkController.dispose();
    _homeworkController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadDiary() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await RoleAccessService.initialize();
      final rows = await BackendApiClient.instance.getRawList('/diary-entries');
      if (!mounted) return;
      setState(() {
        _entries = rows.where(_belongsToTeacherFlow).map(_mapEntry).toList()
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

  bool _belongsToTeacherFlow(Map<String, dynamic> row) {
    final teacherId = teacherFlowText(row['teacher_id'] ?? row['staff_id']);
    final sectionId = teacherFlowText(row['section_id']);
    if (teacherId.isNotEmpty && teacherId == RoleAccessService.teacherStaffId) {
      return true;
    }
    if (sectionId.isNotEmpty && sectionId == RoleAccessService.teacherClassId) {
      return true;
    }
    return teacherId.isEmpty && sectionId.isEmpty;
  }

  Map<String, dynamic> _mapEntry(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'date': teacherFlowDateOnly(row['date'] ?? row['created_at']),
      'class': teacherFlowText(
        row['class'] ?? row['class_name'],
        fallback: teacherCurrentClassLabel(),
      ),
      'subject': teacherFlowText(
        row['subject'] ?? row['subject_name'],
        fallback: RoleAccessService.teacherSubject,
      ),
      'title': teacherFlowText(row['title'], fallback: 'Class diary'),
      'classwork': teacherFlowText(row['classwork'] ?? row['work_done']),
      'homework': teacherFlowText(row['homework']),
      'notes': teacherFlowText(row['notes'] ?? row['remarks']),
      'type': teacherFlowText(row['type'], fallback: 'regular'),
    };
  }

  Future<void> _saveDiaryEntry({bool noHomework = false}) async {
    if (_saving) return;
    final classwork = _classworkController.text.trim();
    final homework = noHomework
        ? 'No homework'
        : _homeworkController.text.trim();
    final notes = _noteController.text.trim();
    if (classwork.isEmpty && homework.isEmpty && notes.isEmpty) return;

    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.createRaw('/diary-entries', {
        'date': DateTime.now().toUtc().toIso8601String(),
        'section_id': RoleAccessService.teacherClassId,
        'teacher_id': RoleAccessService.teacherStaffId,
        'class': RoleAccessService.teacherClassName,
        'subject': RoleAccessService.teacherSubject,
        'title': noHomework ? 'No homework assigned' : 'Daily class diary',
        'classwork': classwork,
        'homework': homework,
        'notes': notes,
        'type': noHomework ? 'no_homework' : _entryType,
        'created_by': RoleAccessService.teacherName,
      });
      _classworkController.clear();
      _homeworkController.clear();
      _noteController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(noHomework ? 'No-homework diary saved' : 'Diary saved'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _saving = false);
      await _loadDiary();
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
    return TeacherFlowScaffold(
      title: 'Class Diary',
      subtitle: 'Record teaching progress, homework, and class notes',
      selectedIndex: 13,
      loading: _loading,
      error: _error,
      onRefresh: _loadDiary,
      child: TeacherFlowScrollView(
        children: [
          TeacherCurrentClassCard(
            greeting: 'Period completion',
            classLabel: teacherCurrentClassLabel(),
            subject: RoleAccessService.teacherSubject,
            timeLabel: teacherFlowDate(DateTime.now()),
            actions: [
              TeacherFlowAction(
                label: 'Save Diary',
                icon: Icons.save_rounded,
                filled: true,
                onTap: _saving ? null : _saveDiaryEntry,
              ),
              TeacherFlowAction(
                label: 'No Homework',
                icon: Icons.assignment_turned_in_rounded,
                onTap: _saving ? null : () => _saveDiaryEntry(noHomework: true),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TeacherFlowMetricGrid(
            metrics: [
              TeacherFlowMetric(
                label: 'Entries',
                value: '${_entries.length}',
                icon: Icons.menu_book_rounded,
                color: AppTheme.primary,
                tone: const Color(0xFFEAF3FF),
              ),
              TeacherFlowMetric(
                label: 'No homework',
                value:
                    '${_entries.where((row) => row['type'] == 'no_homework').length}',
                icon: Icons.task_alt_rounded,
                color: teacherFlowAccent,
                tone: const Color(0xFFEAFBF5),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildQuickEntry(),
          const SizedBox(height: 18),
          const TeacherFlowSectionHeader(title: 'Recent Diary Entries'),
          const SizedBox(height: 10),
          if (_entries.isEmpty)
            const TeacherFlowCard(
              icon: Icons.menu_book_outlined,
              title: 'No diary entries',
              subtitle:
                  'Saved teaching logs from the backend will appear here.',
            )
          else
            ..._entries
                .take(20)
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _entryCard(entry),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildQuickEntry() {
    return TeacherFlowCard(
      icon: Icons.edit_note_rounded,
      title: 'Complete this period',
      subtitle: 'Record what was taught before leaving the class workflow.',
      body: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _entryType,
            decoration: const InputDecoration(
              labelText: 'Diary type',
              prefixIcon: Icon(Icons.category_rounded),
            ),
            items: const [
              DropdownMenuItem(value: 'regular', child: Text('Regular Class')),
              DropdownMenuItem(value: 'revision', child: Text('Revision')),
              DropdownMenuItem(value: 'test', child: Text('Class Test')),
              DropdownMenuItem(value: 'activity', child: Text('Activity')),
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() => _entryType = value ?? 'regular'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _classworkController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Classwork completed',
              prefixIcon: Icon(Icons.school_rounded),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _homeworkController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Homework assigned',
              prefixIcon: Icon(Icons.assignment_rounded),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteController,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Teacher note',
              prefixIcon: Icon(Icons.sticky_note_2_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _entryCard(Map<String, dynamic> entry) {
    final homework = teacherFlowText(entry['homework']);
    final classwork = teacherFlowText(entry['classwork']);
    final notes = teacherFlowText(entry['notes']);
    return TeacherFlowCard(
      icon: Icons.menu_book_rounded,
      title: teacherFlowText(entry['title'], fallback: 'Class diary'),
      subtitle:
          '${teacherFlowText(entry['subject'])} · ${teacherFlowText(entry['class'])}',
      status: teacherFlowText(entry['date'], fallback: 'Today'),
      statusColor: _typeColor(teacherFlowText(entry['type'])),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (classwork.isNotEmpty)
            TeacherInfoPill(icon: Icons.school_rounded, label: classwork),
          if (classwork.isNotEmpty) const SizedBox(height: 8),
          if (homework.isNotEmpty)
            TeacherInfoPill(icon: Icons.assignment_rounded, label: homework),
          if (homework.isNotEmpty) const SizedBox(height: 8),
          if (notes.isNotEmpty)
            TeacherInfoPill(icon: Icons.notes_rounded, label: notes),
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'test':
        return AppTheme.error;
      case 'activity':
        return AppTheme.secondary;
      case 'revision':
        return teacherFlowWarm;
      default:
        return teacherFlowAccent;
    }
  }
}
