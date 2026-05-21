import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_navigation.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_module_scaffold.dart';
import '../../services/backend_api_client.dart';
import 'admin_exam_form_screens.dart';

class AdminExamsScreen extends StatefulWidget {
  const AdminExamsScreen({super.key});

  @override
  State<AdminExamsScreen> createState() => _AdminExamsScreenState();
}

class _AdminExamsScreenState extends State<AdminExamsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _exams = [];
  List<Map<String, dynamic>> _examSchedules = [];
  List<Map<String, dynamic>> _reportCards = [];
  List<AcademicYearModel> _academicYears = [];
  List<Map<String, dynamic>> _examTypes = [];
  List<GradeModel> _grades = [];
  List<SectionModel> _sections = [];
  List<Map<String, dynamic>> _subjects = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = BackendApiClient.instance;
      final exams = await api.getExams();
      final schedules = await api.getRawList('/exams/schedules');
      final reportCards = await api.getRawList('/exams/report-cards');
      final academicYears = await api.getAcademicYears();
      final examTypes = await api.getExamTypes();
      final grades = await api.getGrades();
      final sections = await api.getSections();
      final subjects = await api.getRawList('/subjects');
      if (!mounted) return;
      setState(() {
        _exams = exams.map((e) {
          final relatedSchedules = schedules
              .where((s) => _scheduleExamId(s) == e.id)
              .toList();
          return {
            'id': e.id,
            'name': e.examName,
            'academicYearId': e.academicYearId,
            'termId': e.termId,
            'examTypeId': e.examTypeId,
            'startDate': e.startDate,
            'endDate': e.endDate,
            'class': _classLabelForSchedules(relatedSchedules),
            'from': _formatDate(e.startDate),
            'to': _formatDate(e.endDate),
            'scheduleCount': relatedSchedules.length,
            'subjects': _subjectLabelForSchedules(relatedSchedules),
            'status': e.isPublished ? 'Published' : 'Draft',
          };
        }).toList();
        _examSchedules = schedules.map(_normaliseSchedule).toList();
        _reportCards = reportCards;
        _academicYears = academicYears;
        _examTypes = examTypes;
        _grades = grades;
        _sections = sections;
        _subjects = subjects;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load exam records: $e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SchoolDeskModuleScaffold(
        title: 'Exams',
        subtitle: 'Schedules, marks, and report cards',
        drawer: AdminDrawer(selectedIndex: 6, onDestinationSelected: (_) {}),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SchoolDeskModuleScaffold(
        title: 'Exams',
        subtitle: 'Schedules, marks, and report cards',
        drawer: AdminDrawer(selectedIndex: 6, onDestinationSelected: (_) {}),
        body: _buildEmptyState(
          _error!,
          actionLabel: 'Retry',
          onAction: _loadData,
        ),
      );
    }
    return SchoolDeskModuleScaffold(
      title: 'Exams',
      subtitle: 'Schedules, marks, report cards, and publishing status',
      drawer: AdminDrawer(selectedIndex: 6, onDestinationSelected: (_) {}),
      floatingActionButton: const DashboardFabWidget(role: DashboardRole.admin),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      actions: [
        IconButton(
          tooltip: 'Create exam',
          icon: const Icon(Icons.add_rounded),
          onPressed: _openExamForm,
        ),
        IconButton(
          tooltip: 'Create exam type',
          icon: const Icon(Icons.category_rounded),
          onPressed: _openExamTypeForm,
        ),
        IconButton(
          tooltip: 'Add exam schedule',
          icon: const Icon(Icons.event_note_rounded),
          onPressed: _openScheduleForm,
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Exams'),
          Tab(text: 'Schedules'),
          Tab(text: 'Report Cards'),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExamSchedule(),
          _buildScheduleList(),
          _buildReportCards(),
        ],
      ),
    );
  }

  Widget _buildExamSchedule() {
    if (_exams.isEmpty) {
      return _buildEmptyState(
        'No backend exams are configured yet. Create an exam type first if the exam form is blocked.',
        actionLabel: 'Create Exam Type',
        onAction: _openExamTypeForm,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _exams.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final e = _exams[i];
        final statusColors = {
          'Upcoming': AppTheme.warning,
          'Scheduled': AppTheme.info,
          'Completed': AppTheme.success,
          'Published': AppTheme.success,
          'Draft': AppTheme.warning,
        };
        final c = statusColors[e['status']] ?? AppTheme.muted;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      e['name'] as String,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: c.withAlpha(25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      e['status'] as String,
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: c,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Classes: ${e['class']}',
                style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
              ),
              if ((e['subjects'] as String).isNotEmpty)
                Text(
                  'Subjects: ${e['subjects']}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.muted,
                  ),
                ),
              Text(
                '${e['from']} – ${e['to']}',
                style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openExamForm(exam: e),
                      icon: const Icon(Icons.edit_rounded, size: 14),
                      label: Text(
                        'Edit',
                        style: GoogleFonts.dmSans(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _setExamPublished(
                        e,
                        (e['status'] as String? ?? 'Draft') != 'Published',
                      ),
                      icon: const Icon(Icons.publish_rounded, size: 14),
                      label: Text(
                        (e['status'] as String? ?? 'Draft') == 'Published'
                            ? 'Unpublish'
                            : 'Publish',
                        style: GoogleFonts.dmSans(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScheduleList() {
    final schedules = _examSchedules;
    if (schedules.isEmpty) {
      return _buildEmptyState(
        'No backend exam schedules are available yet.',
        actionLabel: 'Add Schedule',
        onAction: _openScheduleForm,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: schedules.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final schedule = schedules[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.confirmation_number_rounded,
                      size: 20,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${schedule['exam']} · ${schedule['subject']}',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${schedule['class']} · ${schedule['date']} · ${schedule['time']}',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${schedule['passMarks']}/${schedule['maxMarks']}',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _openMarksEntry(schedule),
                    icon: const Icon(Icons.fact_check_rounded, size: 16),
                    label: Text(
                      'Enter Marks',
                      style: GoogleFonts.dmSans(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openMarksEntry(Map<String, dynamic> schedule) async {
    final result = await Navigator.of(context).push<AdminExamFormResult>(
      MaterialPageRoute(
        builder: (_) => AdminExamMarksEntryScreen(
          args: AdminExamMarksEntryArgs(schedule: schedule),
        ),
      ),
    );
    if (!mounted || result == null) return;
    await _loadData();
    if (!mounted) return;
    _showSuccess(result.message);
  }

  Widget _buildReportCards() {
    if (_reportCards.isEmpty) {
      return _buildEmptyState(
        'No backend report cards have been generated yet.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _reportCards.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final row = _reportCards[index];
        final student = row['student'];
        final exam = row['exam'];
        final studentName = student is Map
            ? '${student['first_name'] ?? ''} ${student['last_name'] ?? ''}'
                  .trim()
            : '${row['student_id'] ?? 'Student'}';
        final examName = exam is Map
            ? '${exam['exam_name'] ?? 'Exam'}'
            : '${row['exam_id'] ?? 'Exam'}';
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.infoContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.assignment_turned_in_rounded,
                  size: 20,
                  color: AppTheme.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName.isEmpty ? 'Student' : studentName,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$examName · ${row['percentage'] ?? 0}% · ${row['overall_grade'] ?? '-'}',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openExamForm({Map<String, dynamic>? exam}) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.adminExamForm,
      arguments: AdminExamFormArgs(
        academicYears: _academicYears,
        examTypes: _examTypes,
        exam: exam,
      ),
    );
    if (!mounted || result is! AdminExamFormResult) return;
    await _loadData();
    if (!mounted) return;
    _showSuccess(result.message);
  }

  Future<void> _openScheduleForm() async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.adminExamScheduleForm,
      arguments: AdminExamScheduleFormArgs(
        exams: _exams,
        grades: _grades,
        sections: _sections,
        subjects: _subjects,
      ),
    );
    if (!mounted || result is! AdminExamFormResult) return;
    await _loadData();
    if (!mounted) return;
    _showSuccess(result.message);
  }

  Future<void> _openExamTypeForm() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _AdminExamTypeFormPage()),
    );
    if (created != true || !mounted) return;
    await _loadData();
    if (!mounted) return;
    _showSuccess('Exam type created');
  }

  Future<void> _setExamPublished(
    Map<String, dynamic> exam,
    bool isPublished,
  ) async {
    final id = '${exam['id'] ?? ''}'.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backend exam ID is missing'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    try {
      await BackendApiClient.instance.setExamPublished(id, isPublished);
      await _loadData();
      if (!mounted) return;
      _showSuccess(isPublished ? 'Exam published' : 'Exam unpublished');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Publish update failed: $error'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  String _scheduleExamId(Map<String, dynamic> schedule) {
    final direct = schedule['exam_id']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    final exam = schedule['exam'];
    if (exam is Map && exam['id'] != null) return exam['id'].toString();
    return '';
  }

  Map<String, dynamic> _normaliseSchedule(Map<String, dynamic> schedule) {
    final exam = schedule['exam'];
    final subject = schedule['subject'];
    return {
      'id': schedule['id']?.toString() ?? '',
      'examId': schedule['exam_id']?.toString() ?? '',
      'gradeId': schedule['grade_id']?.toString() ?? '',
      'sectionId': schedule['section_id']?.toString() ?? '',
      'subjectId': schedule['subject_id']?.toString() ?? '',
      'exam': exam is Map
          ? exam['exam_name']?.toString() ?? 'Exam'
          : schedule['exam_id']?.toString() ?? 'Exam',
      'class': _classLabelForSchedules([schedule]),
      'subject': subject is Map
          ? subject['subject_name']?.toString() ?? 'Subject'
          : schedule['subject_id']?.toString() ?? 'Subject',
      'date': _formatDate('${schedule['exam_date'] ?? ''}'),
      'time': [
        schedule['start_time']?.toString() ?? '',
        schedule['end_time']?.toString() ?? '',
      ].where((part) => part.trim().isNotEmpty).join(' - '),
      'maxMarks': schedule['max_marks'] ?? 0,
      'passMarks': schedule['pass_marks'] ?? 0,
    };
  }

  String _classLabelForSchedules(List<Map<String, dynamic>> schedules) {
    final labels =
        schedules
            .map(_classLabelForSchedule)
            .where((label) => label.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    if (labels.isEmpty) return 'Not assigned';
    return labels.join(', ');
  }

  String _classLabelForSchedule(Map<String, dynamic> schedule) {
    final grade = schedule['grade'];
    final section = schedule['section'];
    final gradeName = grade is Map ? grade['grade_name']?.toString() : null;
    final sectionName = section is Map
        ? section['section_name']?.toString()
        : null;
    if (gradeName != null && gradeName.isNotEmpty) {
      if (sectionName != null && sectionName.isNotEmpty) {
        return '$gradeName $sectionName';
      }
      return gradeName;
    }
    if (schedule['grade_id'] != null && schedule['section_id'] != null) {
      return '${schedule['grade_id']} / ${schedule['section_id']}';
    }
    return '';
  }

  String _subjectLabelForSchedules(List<Map<String, dynamic>> schedules) {
    final labels =
        schedules
            .map((schedule) {
              final subject = schedule['subject'];
              if (subject is Map) {
                return subject['subject_name']?.toString() ?? '';
              }
              return schedule['subject_id']?.toString() ?? '';
            })
            .where((label) => label.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return labels.join(', ');
  }

  String _formatDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value.isEmpty ? 'Not scheduled' : value;
    return '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}';
  }

  Widget _buildEmptyState(
    String message, {
    String? actionLabel,
    Future<void> Function()? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.muted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.success),
    );
  }
}

class _AdminExamTypeFormPage extends StatefulWidget {
  const _AdminExamTypeFormPage();

  @override
  State<_AdminExamTypeFormPage> createState() => _AdminExamTypeFormPageState();
}

class _AdminExamTypeFormPageState extends State<_AdminExamTypeFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController(text: '10');
  bool _isBoardExam = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await BackendApiClient.instance.createRaw('/exams/types', {
        'name': _nameController.text.trim(),
        'weightage_percent':
            double.tryParse(_weightController.text.trim()) ?? 0,
        'is_board_exam': _isBoardExam,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Exam type save failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Exam Type')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _nameController,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Exam type name'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter exam type name.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _weightController,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Weightage percent',
                ),
                validator: (value) {
                  final parsed = double.tryParse(value ?? '');
                  if (parsed == null || parsed < 0 || parsed > 100) {
                    return 'Enter a value from 0 to 100.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isBoardExam,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _isBoardExam = value),
                title: Text(
                  'Board exam',
                  style: GoogleFonts.dmSans(fontSize: 13),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppTheme.error)),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Saving...' : 'Create Exam Type'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
