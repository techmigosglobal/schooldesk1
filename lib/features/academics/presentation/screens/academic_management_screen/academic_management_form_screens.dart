import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/services/backend_data_service.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/admin_navigation.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';

@immutable
class AcademicYearFormArgs {
  final String ownerRole;
  final Map<String, dynamic>? year;

  const AcademicYearFormArgs({required this.ownerRole, this.year});

  bool get isEditing => year != null;
}

@immutable
class AcademicSubjectFormArgs {
  final String ownerRole;
  final Map<String, dynamic>? subject;

  const AcademicSubjectFormArgs({required this.ownerRole, this.subject});

  bool get isEditing => subject != null;
}

@immutable
class AcademicClassFormArgs {
  final String ownerRole;
  final List<Map<String, dynamic>> staff;
  final Map<String, dynamic>? classData;

  const AcademicClassFormArgs({
    required this.ownerRole,
    required this.staff,
    this.classData,
  });

  bool get isEditing => classData != null;
}

@immutable
class AcademicCurriculumFormArgs {
  final String ownerRole;
  final List<Map<String, dynamic>> classes;
  final List<Map<String, dynamic>> subjects;
  final Map<String, dynamic>? item;

  const AcademicCurriculumFormArgs({
    required this.ownerRole,
    required this.classes,
    required this.subjects,
    this.item,
  });

  bool get isEditing => item != null;
}

@immutable
class AcademicFormResult {
  final String message;
  final bool isWarning;

  const AcademicFormResult(this.message, {this.isWarning = false});
}

class AcademicYearFormScreen extends StatefulWidget {
  final AcademicYearFormArgs args;

  const AcademicYearFormScreen({super.key, required this.args});

  @override
  State<AcademicYearFormScreen> createState() => _AcademicYearFormScreenState();
}

class _AcademicYearFormScreenState extends State<AcademicYearFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  late bool _isCurrent;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final year = widget.args.year ?? const <String, dynamic>{};
    _nameController = TextEditingController(
      text: _textValue(year['name'] ?? year['year_label']),
    );
    _startController = TextEditingController(
      text: _dateText(year['start_date'] ?? year['start'], '2026-04-01'),
    );
    _endController = TextEditingController(
      text: _dateText(year['end_date'] ?? year['end'], '2027-03-31'),
    );
    _isCurrent = year['is_current'] == true || year['status'] == 'active';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AcademicFormScaffold(
      ownerRole: widget.args.ownerRole,
      title: widget.args.isEditing ? 'Edit Academic Year' : 'Add Academic Year',
      subtitle: 'Create or update the backend academic-year record',
      saving: _saving,
      saveLabel: widget.args.isEditing ? 'Save year' : 'Create year',
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _nameController,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Year name',
                hintText: 'Example: 2026-2027',
              ),
              validator: (value) => _required(value, 'Enter academic year.'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _startController,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Start date',
                helperText: 'YYYY-MM-DD',
              ),
              keyboardType: TextInputType.datetime,
              validator: _dateValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _endController,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'End date',
                helperText: 'YYYY-MM-DD',
              ),
              keyboardType: TextInputType.datetime,
              validator: _dateValidator,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isCurrent,
              title: Text(
                'Set as current year',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'The active year drives classes, fees, attendance, and events.',
                style: GoogleFonts.dmSans(fontSize: 12),
              ),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _isCurrent = value),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final start = DateTime.parse(_startController.text.trim());
    final end = DateTime.parse(_endController.text.trim());
    if (end.isBefore(start)) {
      _showError(context, 'End date must be after start date.');
      return;
    }
    setState(() => _saving = true);
    try {
      final storage = await BackendDataService.getInstance();
      await storage.saveAcademicYearRecord({
        ...?widget.args.year,
        'id':
            widget.args.year?['id'] ??
            'ay${DateTime.now().millisecondsSinceEpoch}',
        'name': _nameController.text.trim(),
        'year_label': _nameController.text.trim(),
        'start_date': _startController.text.trim(),
        'end_date': _endController.text.trim(),
        'is_current': _isCurrent,
        'status': _isCurrent ? 'active' : 'upcoming',
      });
      if (!mounted) return;
      Navigator.pop(
        context,
        AcademicFormResult(
          widget.args.isEditing
              ? 'Academic year updated'
              : 'Academic year created',
        ),
      );
    } catch (error) {
      _showError(context, _cleanError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class AcademicSubjectFormScreen extends StatefulWidget {
  final AcademicSubjectFormArgs args;

  const AcademicSubjectFormScreen({super.key, required this.args});

  @override
  State<AcademicSubjectFormScreen> createState() =>
      _AcademicSubjectFormScreenState();
}

class _AcademicSubjectFormScreenState extends State<AcademicSubjectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  String _type = 'Core';
  bool _saving = false;

  static const _types = ['Core', 'Elective', 'Co-curricular', 'Language'];

  @override
  void initState() {
    super.initState();
    final subject = widget.args.subject ?? const <String, dynamic>{};
    _nameController = TextEditingController(
      text: _textValue(subject['name'] ?? subject['subject_name']),
    );
    _codeController = TextEditingController(
      text: _textValue(subject['code'] ?? subject['subject_code']),
    );
    final existingType = _textValue(
      subject['type'] ?? subject['subject_type'],
      fallback: 'Core',
    );
    _type = _types.contains(existingType) ? existingType : 'Core';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AcademicFormScaffold(
      ownerRole: widget.args.ownerRole,
      title: widget.args.isEditing ? 'Edit Subject' : 'Add Subject',
      subtitle: 'Maintain backend subject catalog records',
      saving: _saving,
      saveLabel: widget.args.isEditing ? 'Save subject' : 'Add subject',
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _nameController,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Subject name'),
              validator: (value) => _required(value, 'Enter subject name.'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _codeController,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Subject code'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: _types
                  .map(
                    (type) => DropdownMenuItem(value: type, child: Text(type)),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _type = value ?? 'Core'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final storage = await BackendDataService.getInstance();
      await storage.saveAcademicSubjectRecord({
        ...?widget.args.subject,
        'id':
            widget.args.subject?['id'] ??
            'sub${DateTime.now().millisecondsSinceEpoch}',
        'name': _nameController.text.trim(),
        'subject_name': _nameController.text.trim(),
        'code': _codeController.text.trim(),
        'subject_code': _codeController.text.trim(),
        'type': _type,
        'subject_type': _type,
      });
      if (!mounted) return;
      Navigator.pop(
        context,
        AcademicFormResult(
          widget.args.isEditing ? 'Subject updated' : 'Subject added',
        ),
      );
    } catch (error) {
      _showError(context, _cleanError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class AcademicClassFormScreen extends StatefulWidget {
  final AcademicClassFormArgs args;

  const AcademicClassFormScreen({super.key, required this.args});

  @override
  State<AcademicClassFormScreen> createState() =>
      _AcademicClassFormScreenState();
}

class _AcademicClassFormScreenState extends State<AcademicClassFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _sectionsController;
  late final TextEditingController _strengthController;
  String _teacherId = '';
  bool _saving = false;

  bool get _isAdminOwner => widget.args.ownerRole.toLowerCase() == 'admin';

  List<Map<String, dynamic>> get _teacherOptions {
    final active = widget.args.staff
        .where(
          (staff) => '${staff['status'] ?? 'active'}'.toLowerCase() == 'active',
        )
        .toList();
    final teachers = active
        .where(
          (staff) =>
              '${staff['designation'] ?? ''}'.toLowerCase().contains('teacher'),
        )
        .toList();
    return teachers.isEmpty ? active : teachers;
  }

  @override
  void initState() {
    super.initState();
    final classData = widget.args.classData ?? const <String, dynamic>{};
    _nameController = TextEditingController(
      text: _textValue(classData['name'] ?? classData['grade_name']),
    );
    _sectionsController = TextEditingController(
      text: (classData['sections'] as List?)?.join(', ') ?? 'A, B',
    );
    _strengthController = TextEditingController(
      text: '${classData['strength'] ?? classData['capacity'] ?? 40}',
    );
    _teacherId = _textValue(
      classData['classTeacherId'] ?? classData['class_teacher_id'],
    );
    if (_teacherId.isNotEmpty &&
        !_teacherOptions.any((teacher) => '${teacher['id']}' == _teacherId)) {
      _teacherId = '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sectionsController.dispose();
    _strengthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AcademicFormScaffold(
      ownerRole: widget.args.ownerRole,
      title: widget.args.isEditing
          ? 'Edit Class'
          : (_isAdminOwner ? 'Request Class Creation' : 'Add Class'),
      subtitle: _isAdminOwner && !widget.args.isEditing
          ? 'Admin class creation is sent to Principal approval'
          : 'Maintain class sections and class-teacher ownership',
      saving: _saving,
      saveLabel: widget.args.isEditing
          ? 'Save class'
          : (_isAdminOwner ? 'Send request' : 'Add class'),
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _nameController,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Class name',
                hintText: 'Example: Class 5',
              ),
              validator: (value) => _required(value, 'Enter class name.'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sectionsController,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Sections',
                helperText: 'Comma separated, for example: A, B',
              ),
              validator: (value) =>
                  _required(value, 'Enter at least one section.'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _strengthController,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Strength per section',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                final strength = int.tryParse(value ?? '') ?? 0;
                return strength <= 0 ? 'Enter valid section strength.' : null;
              },
            ),
            const SizedBox(height: 12),
            _buildTeacherPicker(),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherPicker() {
    final options = _teacherOptions;
    if (options.isEmpty) {
      return const TextField(
        enabled: false,
        decoration: InputDecoration(
          labelText: 'Class teacher',
          helperText: 'Create a teacher account before assigning a class.',
        ),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: _teacherId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Class teacher',
        helperText: 'Optional',
      ),
      items: [
        const DropdownMenuItem(value: '', child: Text('No class teacher')),
        ...options.map(
          (teacher) => DropdownMenuItem(
            value: '${teacher['id'] ?? ''}',
            child: Text(_teacherName(teacher), overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: _saving
          ? null
          : (value) => setState(() => _teacherId = value ?? ''),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final sections = _sectionsController.text
        .split(',')
        .map((section) => section.trim())
        .where((section) => section.isNotEmpty)
        .toList();
    if (sections.isEmpty) {
      _showError(context, 'Enter at least one section.');
      return;
    }
    setState(() => _saving = true);
    try {
      final selectedTeacher = _teacherById(_teacherId);
      final storage = await BackendDataService.getInstance();
      await storage.saveAcademicClassRecord({
        ...?widget.args.classData,
        'id':
            widget.args.classData?['id'] ??
            'cls${DateTime.now().millisecondsSinceEpoch}',
        'name': _nameController.text.trim(),
        'sections': sections,
        'strength': int.parse(_strengthController.text.trim()),
        'classTeacherId': _teacherId,
        'classTeacher': selectedTeacher == null
            ? ''
            : _teacherName(selectedTeacher),
        'request_principal_approval': _isAdminOwner && !widget.args.isEditing,
        'createdAt': DateTime.now().toIso8601String(),
      });
      if (!mounted) return;
      Navigator.pop(
        context,
        AcademicFormResult(
          widget.args.isEditing
              ? 'Class updated'
              : (_isAdminOwner
                    ? 'Class request sent to Principal for approval'
                    : 'Class created successfully'),
          isWarning: _isAdminOwner && !widget.args.isEditing,
        ),
      );
    } catch (error) {
      _showError(context, _cleanError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic>? _teacherById(String id) {
    for (final teacher in _teacherOptions) {
      if ('${teacher['id'] ?? ''}' == id) return teacher;
    }
    return null;
  }
}

class AcademicCurriculumFormScreen extends StatefulWidget {
  final AcademicCurriculumFormArgs args;

  const AcademicCurriculumFormScreen({super.key, required this.args});

  @override
  State<AcademicCurriculumFormScreen> createState() =>
      _AcademicCurriculumFormScreenState();
}

class _AcademicCurriculumFormScreenState
    extends State<AcademicCurriculumFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _classController;
  late final TextEditingController _subjectsController;
  late final TextEditingController _termController;
  String _selectedClass = '';
  late final Set<String> _selectedSubjects;
  bool _saving = false;

  List<String> get _classOptions => widget.args.classes
      .map((item) => _textValue(item['name'] ?? item['class']))
      .where((name) => name.isNotEmpty)
      .toSet()
      .toList();

  List<String> get _subjectOptions => widget.args.subjects
      .map((item) => _textValue(item['name'] ?? item['subject_name']))
      .where((name) => name.isNotEmpty)
      .toSet()
      .toList();

  @override
  void initState() {
    super.initState();
    final item = widget.args.item ?? const <String, dynamic>{};
    final currentClass = _textValue(item['class']);
    final classOptions = {
      if (currentClass.isNotEmpty) currentClass,
      ..._classOptions,
    }.toList();
    _selectedClass = currentClass.isNotEmpty
        ? currentClass
        : (classOptions.isEmpty ? '' : classOptions.first);
    _classController = TextEditingController(text: _selectedClass);
    _selectedSubjects =
        (item['subjects'] as List?)
            ?.map((subject) => '$subject'.trim())
            .toSet() ??
        <String>{};
    _subjectsController = TextEditingController(
      text: _selectedSubjects.join(', '),
    );
    _termController = TextEditingController(
      text: _textValue(item['term'], fallback: 'Term 1'),
    );
  }

  @override
  void dispose() {
    _classController.dispose();
    _subjectsController.dispose();
    _termController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AcademicFormScaffold(
      ownerRole: widget.args.ownerRole,
      title: widget.args.isEditing
          ? 'Edit Curriculum Entry'
          : 'Add Curriculum Entry',
      subtitle: 'Map classes, terms, and subjects for academic records',
      saving: _saving,
      saveLabel: widget.args.isEditing ? 'Save curriculum' : 'Add curriculum',
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildClassInput(),
            const SizedBox(height: 12),
            _buildSubjectInput(),
            const SizedBox(height: 12),
            TextFormField(
              controller: _termController,
              enabled: !_saving,
              decoration: const InputDecoration(labelText: 'Term'),
              validator: (value) => _required(value, 'Enter term.'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassInput() {
    final options = {
      if (_selectedClass.isNotEmpty) _selectedClass,
      ..._classOptions,
    }.toList();
    if (options.isEmpty) {
      return TextFormField(
        controller: _classController,
        enabled: !_saving,
        decoration: const InputDecoration(labelText: 'Class'),
        validator: (value) => _required(value, 'Enter class.'),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: _selectedClass.isEmpty ? options.first : _selectedClass,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Class'),
      items: options
          .map((name) => DropdownMenuItem(value: name, child: Text(name)))
          .toList(),
      onChanged: _saving
          ? null
          : (value) => setState(() {
              _selectedClass = value ?? '';
              _classController.text = _selectedClass;
            }),
    );
  }

  Widget _buildSubjectInput() {
    final options = _subjectOptions;
    if (options.isEmpty) {
      return TextFormField(
        controller: _subjectsController,
        enabled: !_saving,
        decoration: const InputDecoration(
          labelText: 'Subjects',
          helperText: 'Comma separated',
        ),
        validator: (value) => _required(value, 'Enter at least one subject.'),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: options
            .map(
              (subject) => FilterChip(
                label: Text(subject),
                selected: _selectedSubjects.contains(subject),
                onSelected: _saving
                    ? null
                    : (_) => setState(() {
                        if (!_selectedSubjects.remove(subject)) {
                          _selectedSubjects.add(subject);
                        }
                      }),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final className = _classOptions.isEmpty
        ? _classController.text.trim()
        : _selectedClass.trim();
    final subjectList = _subjectOptions.isEmpty
        ? _subjectsController.text
              .split(',')
              .map((subject) => subject.trim())
              .where((subject) => subject.isNotEmpty)
              .toList()
        : _selectedSubjects.toList();
    if (className.isEmpty) {
      _showError(context, 'Enter class.');
      return;
    }
    if (subjectList.isEmpty) {
      _showError(context, 'Select at least one subject.');
      return;
    }
    setState(() => _saving = true);
    try {
      final storage = await BackendDataService.getInstance();
      await storage.saveAcademicCurriculumRecord({
        ...?widget.args.item,
        'id':
            widget.args.item?['id'] ??
            'cur${DateTime.now().millisecondsSinceEpoch}',
        'class': className,
        'subjects': subjectList,
        'term': _termController.text.trim(),
        'published': widget.args.item?['published'] == true,
        'createdAt': DateTime.now().toIso8601String(),
      });
      if (!mounted) return;
      Navigator.pop(
        context,
        AcademicFormResult(
          widget.args.isEditing
              ? 'Curriculum entry updated'
              : 'Curriculum entry added',
        ),
      );
    } catch (error) {
      _showError(context, _cleanError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _AcademicFormScaffold extends StatelessWidget {
  final String ownerRole;
  final String title;
  final String subtitle;
  final Widget child;
  final bool saving;
  final String saveLabel;
  final VoidCallback onSave;

  const _AcademicFormScaffold({
    required this.ownerRole,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.saving,
    required this.saveLabel,
    required this.onSave,
  });

  bool get _isAdminOwner => ownerRole.toLowerCase() == 'admin';

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: title,
      subtitle: subtitle,
      drawer: _isAdminOwner
          ? AdminDrawer(selectedIndex: 15, onDestinationSelected: (_) {})
          : PrincipalDrawer(selectedIndex: 12, onDestinationSelected: (_) {}),
      floatingActionButton: DashboardFabWidget(
        role: _isAdminOwner ? DashboardRole.admin : DashboardRole.principal,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.outlineVariant),
            ),
            child: child,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(saving ? 'Saving...' : saveLabel),
          ),
        ],
      ),
    );
  }
}

String? _required(String? value, String message) {
  if (value == null || value.trim().isEmpty) return message;
  return null;
}

String? _dateValidator(String? value) {
  final text = (value ?? '').trim();
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
    return 'Use YYYY-MM-DD.';
  }
  return DateTime.tryParse(text) == null ? 'Enter a valid date.' : null;
}

String _dateText(Object? value, String fallback) {
  final text = _textValue(value, fallback: fallback);
  return text.split('T').first;
}

String _textValue(Object? value, {String fallback = ''}) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty || text == 'null' ? fallback : text;
}

String _teacherName(Map<String, dynamic> teacher) {
  final name = _textValue(teacher['name']);
  if (name.isNotEmpty) return name;
  final email = _textValue(teacher['email']);
  return email.isNotEmpty ? email : _textValue(teacher['id']);
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: AppTheme.error),
  );
}

String _cleanError(Object error) {
  final raw = error.toString();
  final server = RegExp(r'ServerException\([^)]*\):\s*(.*)').firstMatch(raw);
  if (server != null) return server.group(1)?.trim() ?? raw;
  final exception = RegExp(r'Exception:\s*(.*)').firstMatch(raw);
  if (exception != null) return exception.group(1)?.trim() ?? raw;
  return raw;
}
