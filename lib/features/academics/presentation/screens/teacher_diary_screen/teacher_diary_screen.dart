import 'package:flutter/material.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

class TeacherDiaryScreen extends StatefulWidget {
  const TeacherDiaryScreen({super.key});

  @override
  State<TeacherDiaryScreen> createState() => _TeacherDiaryScreenState();
}

class _TeacherDiaryScreenState extends State<TeacherDiaryScreen> {
  final _classworkController = TextEditingController();
  final _practiceController = TextEditingController();
  final _nextClassController = TextEditingController();
  final _noteController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _entryType = 'regular';
  int _periodNumber = 1;
  bool _routeArgsApplied = false;
  Map<String, dynamic>? _editingEntry;
  List<Map<String, dynamic>> _entries = const [];

  @override
  void initState() {
    super.initState();
    _loadDiary();
  }

  @override
  void dispose() {
    _classworkController.dispose();
    _practiceController.dispose();
    _nextClassController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prefillFromRouteArgs();
  }

  void _prefillFromRouteArgs() {
    if (_routeArgsApplied) return;
    _routeArgsApplied = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) return;
    final period = teacherFlowInt(args['period_number'] ?? args['period']);
    if (period > 0) _periodNumber = period;
    final subject = teacherFlowText(args['subject']);
    if (subject.isNotEmpty && _noteController.text.trim().isEmpty) {
      _noteController.text = 'Diary for $subject';
    }
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
      'date': teacherFlowDateOnly(
        row['date'] ?? row['entry_date'] ?? row['created_at'],
      ),
      'class': teacherFlowText(
        row['class'] ?? row['class_name'],
        fallback: teacherCurrentClassLabel(),
      ),
      'subject': teacherFlowText(
        row['subject'] ?? row['subject_name'],
        fallback: RoleAccessService.teacherSubject,
      ),
      'period_number': teacherFlowInt(row['period_number']),
      'title': teacherFlowText(row['title'], fallback: 'Class diary'),
      'classwork': teacherFlowText(row['classwork'] ?? row['work_done']),
      'practice': teacherFlowText(
        row['homework'],
        fallback: teacherFlowText(row['entry_type']) == 'no_homework'
            ? 'No practice work'
            : '',
      ),
      'notes': teacherFlowText(
        row['notes'] ?? row['remarks'] ?? row['content'],
      ),
      'schedule': teacherFlowText(row['schedule']),
      'type': teacherFlowText(
        row['type'] ?? row['entry_type'],
        fallback: 'regular',
      ),
    };
  }

  Future<void> _saveDiaryEntry({bool noPractice = false}) async {
    if (_saving) return;
    final classwork = _classworkController.text.trim();
    final practice = noPractice
        ? 'No practice work'
        : _practiceController.text.trim();
    final nextClass = _nextClassController.text.trim();
    final notes = _noteController.text.trim();
    if (classwork.isEmpty &&
        practice.isEmpty &&
        nextClass.isEmpty &&
        notes.isEmpty) {
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = {
        'date': DateTime.now().toUtc().toIso8601String(),
        'entry_date': teacherFlowDate(DateTime.now()),
        'section_id': RoleAccessService.teacherClassId,
        'teacher_id': RoleAccessService.teacherStaffId,
        'staff_id': RoleAccessService.teacherStaffId,
        'class': RoleAccessService.teacherClassName,
        'subject': RoleAccessService.teacherSubject,
        'period_number': _periodNumber,
        'title': noPractice
            ? 'No practice work'
            : 'Period $_periodNumber class diary',
        'classwork': classwork,
        'homework': practice,
        'schedule': nextClass,
        'notes': notes,
        'type': noPractice ? 'no_practice' : _entryType,
        'entry_type': noPractice ? 'no_practice' : _entryType,
        'content': [
          if (classwork.isNotEmpty) 'Today: $classwork',
          if (nextClass.isNotEmpty) 'Next: $nextClass',
          if (practice.isNotEmpty) 'Practice: $practice',
          if (notes.isNotEmpty) 'Notes: $notes',
        ].join('\n'),
        'created_by': RoleAccessService.teacherName,
      };
      final editingId = teacherFlowText(_editingEntry?['id']);
      if (editingId.isEmpty) {
        await BackendApiClient.instance.createRaw('/diary-entries', payload);
      } else {
        await BackendApiClient.instance.updateRaw(
          '/diary-entries/$editingId',
          payload,
        );
      }
      _clearEntryForm();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(editingId.isEmpty ? 'Diary saved' : 'Diary updated'),
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

  void _clearEntryForm() {
    _editingEntry = null;
    _classworkController.clear();
    _practiceController.clear();
    _nextClassController.clear();
    _noteController.clear();
    _periodNumber = 1;
  }

  void _editEntry(Map<String, dynamic> entry) {
    if (!_isTodayEntry(entry)) return;
    setState(() {
      _editingEntry = entry;
      _entryType = teacherFlowText(entry['type'], fallback: 'regular');
      final period = teacherFlowInt(entry['period_number']);
      _periodNumber = period > 0 ? period : 1;
      _classworkController.text = teacherFlowText(entry['classwork']);
      _practiceController.text = teacherFlowText(entry['practice']);
      _nextClassController.text = teacherFlowText(entry['schedule']);
      _noteController.text = teacherFlowText(entry['notes']);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TeacherFlowScaffold(
      title: 'Class Diary',
      subtitle: 'Record today, next class, and practice work',
      selectedIndex: 3,
      loading: _loading,
      error: _error,
      onRefresh: _loadDiary,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : () => _saveDiaryEntry(),
        icon: const Icon(Icons.save_rounded),
        label: const Text('Save Diary'),
      ),
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
                label: 'No Practice',
                icon: Icons.assignment_turned_in_rounded,
                onTap: _saving ? null : () => _saveDiaryEntry(noPractice: true),
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
                color: context.appTheme.primary,
                tone: const Color(0xFFEAF3FF),
              ),
              TeacherFlowMetric(
                label: 'Archived',
                value: '${_entries.where((row) => !_isTodayEntry(row)).length}',
                icon: Icons.task_alt_rounded,
                color: teacherFlowAccent,
                tone: const Color(0xFFEAFBF5),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildQuickEntry(),
          const SizedBox(height: 18),
          const TeacherFlowSectionHeader(title: "Today's Diary Entries"),
          const SizedBox(height: 10),
          if (_todayEntries.isEmpty)
            const TeacherFlowCard(
              icon: Icons.menu_book_outlined,
              title: 'No diary for today',
              subtitle: 'Record each completed period before the day ends.',
            )
          else
            ..._todayEntries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _entryCard(entry),
              ),
            ),
          if (_archivedEntries.isNotEmpty) ...[
            const SizedBox(height: 18),
            const TeacherFlowSectionHeader(title: 'Archived Diary Entries'),
            const SizedBox(height: 10),
            ..._archivedEntries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _entryCard(entry),
              ),
            ),
          ],
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
          DropdownButtonFormField<int>(
            value: _periodNumber,
            decoration: const InputDecoration(
              labelText: 'Period',
              prefixIcon: Icon(Icons.schedule_rounded),
            ),
            items: [
              for (var period = 1; period <= 10; period++)
                DropdownMenuItem(value: period, child: Text('Period $period')),
            ],
            onChanged: _saving
                ? null
                : (value) => setState(() => _periodNumber = value ?? 1),
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
            controller: _nextClassController,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Next class plan',
              prefixIcon: Icon(Icons.next_plan_rounded),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _practiceController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Practice work',
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

  Future<void> _deleteEntry(Map<String, dynamic> entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Diary Entry'),
        content: Text(
          'Are you sure you want to delete "${teacherFlowText(entry['title'], fallback: 'Class diary')}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: context.appTheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final id = teacherFlowText(entry['id'] ?? entry['diary_entry_id']);
      if (id.isEmpty) {
        throw Exception('Diary entry is missing its server id.');
      }
      await BackendApiClient.instance.deleteRaw('/diary-entries/$id');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Diary entry deleted successfully')),
      );
      await _loadDiary();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete diary entry: $error'),
          backgroundColor: context.appTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _entryCard(Map<String, dynamic> entry) {
    final practice = teacherFlowText(entry['practice']);
    final classwork = teacherFlowText(entry['classwork']);
    final notes = teacherFlowText(entry['notes']);
    final schedule = teacherFlowText(entry['schedule']);
    final period = teacherFlowInt(entry['period_number']);
    final editable = _isTodayEntry(entry);
    return TeacherFlowCard(
      icon: Icons.menu_book_rounded,
      title: teacherFlowText(entry['title'], fallback: 'Class diary'),
      subtitle:
          '${teacherFlowText(entry['subject'])} · ${teacherFlowText(entry['class'])}${period > 0 ? ' · Period $period' : ''}',
      status: teacherFlowText(entry['date'], fallback: 'Today'),
      statusColor: _typeColor(teacherFlowText(entry['type'])),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (classwork.isNotEmpty)
            TeacherInfoPill(icon: Icons.school_rounded, label: classwork),
          if (classwork.isNotEmpty) const SizedBox(height: 8),
          if (schedule.isNotEmpty)
            TeacherInfoPill(icon: Icons.next_plan_rounded, label: schedule),
          if (schedule.isNotEmpty) const SizedBox(height: 8),
          if (practice.isNotEmpty)
            TeacherInfoPill(icon: Icons.assignment_rounded, label: practice),
          if (practice.isNotEmpty) const SizedBox(height: 8),
          if (notes.isNotEmpty)
            TeacherInfoPill(icon: Icons.notes_rounded, label: notes),
          if (editable) ...[
            const SizedBox(height: 10),
            TeacherFlowActionWrap(
              actions: [
                TeacherFlowAction(
                  label: 'Edit',
                  icon: Icons.edit_rounded,
                  onTap: () => _editEntry(entry),
                ),
                TeacherFlowAction(
                  label: 'Delete',
                  icon: Icons.delete_rounded,
                  onTap: () => _deleteEntry(entry),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _todayEntries =>
      _entries.where(_isTodayEntry).toList();

  List<Map<String, dynamic>> get _archivedEntries =>
      _entries.where((entry) => !_isTodayEntry(entry)).toList();

  bool _isTodayEntry(Map<String, dynamic> entry) {
    return teacherFlowText(entry['date']) == teacherFlowDate(DateTime.now());
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'test':
        return context.appTheme.error;
      case 'activity':
        return context.appTheme.secondary;
      case 'revision':
        return teacherFlowWarm;
      default:
        return teacherFlowAccent;
    }
  }
}
