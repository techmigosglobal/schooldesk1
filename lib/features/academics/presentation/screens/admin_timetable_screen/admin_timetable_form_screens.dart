import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/admin_navigation.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';

@immutable
class AdminTimetableGenerationFormArgs {
  final String classLabel;
  final SectionModel? section;
  final AcademicYearModel? academicYear;
  final String termId;
  final String dayLabel;
  final int dayNumber;

  const AdminTimetableGenerationFormArgs({
    required this.classLabel,
    required this.section,
    required this.academicYear,
    required this.termId,
    required this.dayLabel,
    required this.dayNumber,
  });
}

@immutable
class AdminTimetablePeriodFormArgs {
  final String classLabel;
  final SectionModel? section;
  final AcademicYearModel? academicYear;
  final String termId;
  final String dayLabel;
  final int dayNumber;
  final int nextPeriodNumber;
  final List<Map<String, dynamic>> subjects;
  final List<StaffModel> staff;
  final Map<String, dynamic>? period;

  const AdminTimetablePeriodFormArgs({
    required this.classLabel,
    required this.section,
    required this.academicYear,
    required this.termId,
    required this.dayLabel,
    required this.dayNumber,
    required this.nextPeriodNumber,
    required this.subjects,
    required this.staff,
    this.period,
  });

  bool get isEditing => period != null;
}

@immutable
class AdminTimetableSubstitutionFormArgs {
  final String classLabel;
  final String dayLabel;
  final List<Map<String, dynamic>> periods;
  final List<StaffModel> staff;
  final Map<String, dynamic>? initialPeriod;

  const AdminTimetableSubstitutionFormArgs({
    required this.classLabel,
    required this.dayLabel,
    required this.periods,
    required this.staff,
    this.initialPeriod,
  });
}

@immutable
class AdminTimetableFormResult {
  final String message;

  const AdminTimetableFormResult(this.message);
}

class AdminTimetableGenerationFormScreen extends StatefulWidget {
  final AdminTimetableGenerationFormArgs args;

  const AdminTimetableGenerationFormScreen({super.key, required this.args});

  @override
  State<AdminTimetableGenerationFormScreen> createState() =>
      _AdminTimetableGenerationFormScreenState();
}

class _AdminTimetableGenerationFormScreenState
    extends State<AdminTimetableGenerationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _periodCountController = TextEditingController(text: '7');
  final _startController = TextEditingController(text: '09:00');
  final _durationController = TextEditingController(text: '40');
  final _gapController = TextEditingController(text: '5');
  TimetableSuggestionResult? _preview;
  bool _loadingPreview = false;
  bool _applying = false;

  bool get _ready =>
      widget.args.section != null &&
      widget.args.academicYear != null &&
      widget.args.termId.trim().isNotEmpty;

  @override
  void dispose() {
    _periodCountController.dispose();
    _startController.dispose();
    _durationController.dispose();
    _gapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _TimetableFormScaffold(
      title: 'Generate ${widget.args.dayLabel} Timetable',
      subtitle: 'Preview backend suggestions before creating timetable slots',
      saving: _applying,
      saveLabel: 'Apply ${_preview?.creatablePeriods ?? 0}',
      onSave: _preview == null || _preview!.creatablePeriods == 0
          ? null
          : _apply,
      child: _ready
          ? Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _contextHeader(widget.args.classLabel, widget.args.dayLabel),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _periodCountController,
                          enabled: !_loadingPreview && !_applying,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Periods',
                          ),
                          validator: _positiveIntValidator,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _startController,
                          enabled: !_loadingPreview && !_applying,
                          decoration: const InputDecoration(
                            labelText: 'Start time',
                            helperText: 'HH:MM',
                          ),
                          validator: _timeValidator,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _durationController,
                          enabled: !_loadingPreview && !_applying,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Minutes',
                          ),
                          validator: _positiveIntValidator,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _gapController,
                          enabled: !_loadingPreview && !_applying,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(labelText: 'Gap'),
                          validator: _nonNegativeIntValidator,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _loadingPreview || _applying
                        ? null
                        : _previewSlots,
                    icon: _loadingPreview
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_outlined, size: 16),
                    label: const Text('Preview suggestions'),
                  ),
                  const SizedBox(height: 14),
                  _buildSuggestionPreview(),
                ],
              ),
            )
          : const SchoolDeskStatusPanel.empty(
              title: 'Class and term setup required',
              message:
                  'Select a backend class with active academic year and term before generating timetable slots.',
            ),
    );
  }

  Widget _buildSuggestionPreview() {
    if (_loadingPreview) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }
    final preview = _preview;
    if (preview == null) {
      return _softPanel('Preview backend-generated periods before applying.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${preview.creatablePeriods} ready, ${preview.blockedPeriods} need review',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: preview.blockedPeriods == 0
                ? AppTheme.success
                : AppTheme.warning,
          ),
        ),
        const SizedBox(height: 8),
        ...preview.suggestions.map(_suggestionRow),
      ],
    );
  }

  Widget _suggestionRow(TimetableSuggestionModel suggestion) {
    final color = suggestion.blocking ? AppTheme.warning : AppTheme.success;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: suggestion.blocking
            ? AppTheme.warningContainer
            : AppTheme.successContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              'P${suggestion.periodNumber}',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  suggestion.subjectName,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${suggestion.staffName} - ${suggestion.startTime} to ${suggestion.endTime}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (suggestion.warnings.isNotEmpty)
                  Text(
                    suggestion.warnings.join(' '),
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: AppTheme.warning,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _previewSlots() async {
    if (!_formKey.currentState!.validate() || !_ready) return;
    setState(() => _loadingPreview = true);
    try {
      final preview = await BackendApiClient.instance.suggestTimetableSlots(
        sectionId: widget.args.section!.id,
        academicYearId: widget.args.academicYear!.id,
        termId: widget.args.termId,
        dayOfWeek: widget.args.dayNumber,
        periodCount: _positiveInt(_periodCountController.text, 7),
        startTime: _startController.text.trim(),
        periodDurationMinutes: _positiveInt(_durationController.text, 40),
        gapMinutes: _nonNegativeInt(_gapController.text, 5),
      );
      if (!mounted) return;
      setState(() => _preview = preview);
    } catch (error) {
      _showError(context, 'Suggestion preview failed: ${_cleanError(error)}');
    } finally {
      if (mounted) setState(() => _loadingPreview = false);
    }
  }

  Future<void> _apply() async {
    if (!_formKey.currentState!.validate() || !_ready) return;
    setState(() => _applying = true);
    try {
      final result = await BackendApiClient.instance.generateTimetableSlots(
        sectionId: widget.args.section!.id,
        academicYearId: widget.args.academicYear!.id,
        termId: widget.args.termId,
        dayOfWeek: widget.args.dayNumber,
        periodCount: _positiveInt(_periodCountController.text, 7),
        startTime: _startController.text.trim(),
        periodDurationMinutes: _positiveInt(_durationController.text, 40),
        gapMinutes: _nonNegativeInt(_gapController.text, 5),
      );
      if (!mounted) return;
      Navigator.pop(
        context,
        AdminTimetableFormResult(
          'Generated ${result.created} periods, skipped ${result.skipped}',
        ),
      );
    } catch (error) {
      _showError(context, 'Timetable generation failed: ${_cleanError(error)}');
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }
}

class AdminTimetablePeriodFormScreen extends StatefulWidget {
  final AdminTimetablePeriodFormArgs args;

  const AdminTimetablePeriodFormScreen({super.key, required this.args});

  @override
  State<AdminTimetablePeriodFormScreen> createState() =>
      _AdminTimetablePeriodFormScreenState();
}

class _AdminTimetablePeriodFormScreenState
    extends State<AdminTimetablePeriodFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _periodController;
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  late String _subjectId;
  late String _staffId;
  bool _saving = false;

  bool get _ready =>
      widget.args.section != null &&
      widget.args.academicYear != null &&
      widget.args.termId.trim().isNotEmpty &&
      widget.args.subjects.isNotEmpty &&
      widget.args.staff.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final period = widget.args.period ?? const <String, dynamic>{};
    _periodController = TextEditingController(
      text:
          '${period['period'] ?? period['period_number'] ?? widget.args.nextPeriodNumber}',
    );
    _startController = TextEditingController(
      text: _textValue(period['start_time'], fallback: '09:00'),
    );
    _endController = TextEditingController(
      text: _textValue(period['end_time'], fallback: '09:40'),
    );
    _subjectId = _initialId(
      _textValue(period['subject_id']),
      widget.args.subjects.map((subject) => '${subject['id']}'),
    );
    _staffId = _initialId(
      _textValue(period['staff_id']),
      widget.args.staff.map((staff) => staff.id),
    );
  }

  @override
  void dispose() {
    _periodController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _TimetableFormScaffold(
      title: widget.args.isEditing ? 'Edit Period' : 'Add Period',
      subtitle: '${widget.args.classLabel} - ${widget.args.dayLabel}',
      saving: _saving,
      saveLabel: widget.args.isEditing ? 'Save period' : 'Add period',
      onSave: _ready ? _save : null,
      child: _ready
          ? Form(
              key: _formKey,
              child: Column(
                children: [
                  _contextHeader(widget.args.classLabel, widget.args.dayLabel),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _periodController,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Period number',
                    ),
                    validator: _positiveIntValidator,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _subjectId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Subject'),
                    items: widget.args.subjects
                        .map(
                          (subject) => DropdownMenuItem(
                            value: '${subject['id']}',
                            child: Text(
                              _subjectName(subject),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    validator: (value) => _required(value, 'Select subject.'),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _subjectId = value ?? ''),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _staffId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Teacher'),
                    items: widget.args.staff
                        .map(
                          (staff) => DropdownMenuItem(
                            value: staff.id,
                            child: Text(
                              _staffName(staff),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    validator: (value) => _required(value, 'Select teacher.'),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _staffId = value ?? ''),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _startController,
                          enabled: !_saving,
                          decoration: const InputDecoration(
                            labelText: 'Start',
                            helperText: 'HH:MM',
                          ),
                          validator: _timeValidator,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _endController,
                          enabled: !_saving,
                          decoration: const InputDecoration(
                            labelText: 'End',
                            helperText: 'HH:MM',
                          ),
                          validator: _timeValidator,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : const SchoolDeskStatusPanel.empty(
              title: 'Setup data required',
              message:
                  'Class, term, subject, and staff setup are required before editing periods.',
            ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || !_ready) return;
    final payload = {
      'section_id': widget.args.section!.id,
      'academic_year_id': widget.args.academicYear!.id,
      'term_id': widget.args.termId,
      'day_of_week': widget.args.dayNumber,
      'period_number': int.parse(_periodController.text.trim()),
      'subject_id': _subjectId,
      'staff_id': _staffId,
      'start_time': _startController.text.trim(),
      'end_time': _endController.text.trim(),
    };
    setState(() => _saving = true);
    try {
      if (widget.args.isEditing) {
        final id = '${widget.args.period?['id'] ?? ''}'.trim();
        if (id.isEmpty) throw Exception('Backend timetable slot ID is missing');
        await BackendApiClient.instance.updateRaw(
          '/timetable/slots/$id',
          payload,
        );
      } else {
        await BackendApiClient.instance.createRaw('/timetable/slots', payload);
      }
      if (!mounted) return;
      Navigator.pop(
        context,
        AdminTimetableFormResult(
          widget.args.isEditing
              ? 'Period updated in backend'
              : 'Period saved to backend',
        ),
      );
    } catch (error) {
      _showError(context, 'Period save failed: ${_cleanError(error)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class AdminTimetableSubstitutionFormScreen extends StatefulWidget {
  final AdminTimetableSubstitutionFormArgs args;

  const AdminTimetableSubstitutionFormScreen({super.key, required this.args});

  @override
  State<AdminTimetableSubstitutionFormScreen> createState() =>
      _AdminTimetableSubstitutionFormScreenState();
}

class _AdminTimetableSubstitutionFormScreenState
    extends State<AdminTimetableSubstitutionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _dateController;
  final _reasonController = TextEditingController(
    text: 'Admin timetable substitution',
  );
  String _periodId = '';
  String _substituteStaffId = '';
  bool _saving = false;

  Map<String, dynamic> get _selectedPeriod {
    return widget.args.periods.firstWhere(
      (period) => '${period['id'] ?? ''}' == _periodId,
      orElse: () => const <String, dynamic>{},
    );
  }

  String get _originalStaffId => _textValue(_selectedPeriod['staff_id']);

  List<StaffModel> get _substituteOptions =>
      widget.args.staff.where((staff) => staff.id != _originalStaffId).toList();

  bool get _ready =>
      widget.args.periods.any(
        (period) => '${period['id'] ?? ''}'.trim().isNotEmpty,
      ) &&
      widget.args.staff.length > 1;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(text: _dateInput(DateTime.now()));
    _periodId = _initialId(
      _textValue(widget.args.initialPeriod?['id']),
      widget.args.periods.map((period) => '${period['id']}'),
    );
    _substituteStaffId = _initialId(
      '',
      _substituteOptions.map((staff) => staff.id),
    );
  }

  @override
  void dispose() {
    _dateController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _TimetableFormScaffold(
      title: 'Assign Substitute',
      subtitle: '${widget.args.classLabel} - ${widget.args.dayLabel}',
      saving: _saving,
      saveLabel: 'Assign substitute',
      onSave: _ready ? _save : null,
      child: _ready
          ? Form(
              key: _formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _periodId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Period'),
                    items: widget.args.periods
                        .where(
                          (period) => '${period['id'] ?? ''}'.trim().isNotEmpty,
                        )
                        .map(
                          (period) => DropdownMenuItem(
                            value: '${period['id']}',
                            child: Text(
                              'P${period['period'] ?? period['period_number'] ?? ''} - ${period['subject'] ?? 'Subject'}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    validator: (value) => _required(value, 'Select period.'),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() {
                            _periodId = value ?? '';
                            _substituteStaffId = _initialId(
                              '',
                              _substituteOptions.map((staff) => staff.id),
                            );
                          }),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dateController,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      helperText: 'YYYY-MM-DD',
                    ),
                    keyboardType: TextInputType.datetime,
                    validator: _dateValidator,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _substituteStaffId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Substitute teacher',
                    ),
                    items: _substituteOptions
                        .map(
                          (staff) => DropdownMenuItem(
                            value: staff.id,
                            child: Text(
                              _staffName(staff),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    validator: (value) =>
                        _required(value, 'Select substitute teacher.'),
                    onChanged: _saving
                        ? null
                        : (value) =>
                              setState(() => _substituteStaffId = value ?? ''),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _reasonController,
                    enabled: !_saving,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) => _required(value, 'Enter reason.'),
                  ),
                ],
              ),
            )
          : const SchoolDeskStatusPanel.empty(
              title: 'Substitution setup required',
              message:
                  'Select a timetable period and make sure at least two staff records exist before assigning a substitute.',
            ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final period = _selectedPeriod;
    final slotId = _textValue(period['id']);
    final originalStaffId = _textValue(period['staff_id']);
    if (slotId.isEmpty || originalStaffId.isEmpty) {
      _showError(
        context,
        'Selected timetable period is missing backend staff.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.createRaw('/timetable/substitutions', {
        'timetable_slot_id': slotId,
        'date': _dateController.text.trim(),
        'original_staff_id': originalStaffId,
        'substitute_staff_id': _substituteStaffId,
        'reason': _reasonController.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(
        context,
        const AdminTimetableFormResult('Substitute assignment saved'),
      );
    } catch (error) {
      _showError(
        context,
        'Substitute assignment failed: ${_cleanError(error)}',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _TimetableFormScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final bool saving;
  final String saveLabel;
  final VoidCallback? onSave;

  const _TimetableFormScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.saving,
    required this.saveLabel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final role = BackendApiClient.instance.currentRoleName?.toLowerCase();
    final isPrincipal = role == 'principal';
    return SchoolDeskModuleScaffold(
      title: title,
      subtitle: subtitle,
      drawer: isPrincipal
          ? PrincipalDrawer(selectedIndex: 4, onDestinationSelected: (_) {})
          : AdminDrawer(selectedIndex: 5, onDestinationSelected: (_) {}),
      floatingActionButton: DashboardFabWidget(
        role: isPrincipal ? DashboardRole.principal : DashboardRole.admin,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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

Widget _contextHeader(String classLabel, String dayLabel) {
  return Row(
    children: [
      const Icon(Icons.calendar_view_week_rounded, color: AppTheme.primary),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              classLabel.isEmpty ? 'Selected class' : classLabel,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              dayLabel,
              style: GoogleFonts.dmSans(color: AppTheme.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _softPanel(String message) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.surfaceVariant,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      message,
      style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
    ),
  );
}

String _initialId(String preferred, Iterable<String> options) {
  final values = options.where((value) => value.trim().isNotEmpty).toList();
  if (preferred.trim().isNotEmpty && values.contains(preferred)) {
    return preferred;
  }
  return values.isEmpty ? '' : values.first;
}

String _subjectName(Map<String, dynamic> subject) =>
    _textValue(subject['subject_name'] ?? subject['name'] ?? subject['id']);

String _staffName(StaffModel staff) => staff.fullName.trim().isEmpty
    ? staff.email ?? staff.id
    : staff.fullName.trim();

String _textValue(Object? value, {String fallback = ''}) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty || text == 'null' ? fallback : text;
}

String? _required(String? value, String message) {
  if (value == null || value.trim().isEmpty) return message;
  return null;
}

String? _positiveIntValidator(String? value) {
  final parsed = int.tryParse(value ?? '') ?? 0;
  return parsed <= 0 ? 'Enter a positive number.' : null;
}

String? _nonNegativeIntValidator(String? value) {
  final parsed = int.tryParse(value ?? '') ?? -1;
  return parsed < 0 ? 'Enter zero or a positive number.' : null;
}

String? _timeValidator(String? value) {
  final text = (value ?? '').trim();
  if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(text)) {
    return 'Use HH:MM.';
  }
  final hour = int.tryParse(text.substring(0, 2)) ?? -1;
  final minute = int.tryParse(text.substring(3, 5)) ?? -1;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return 'Enter a valid time.';
  }
  return null;
}

String? _dateValidator(String? value) {
  final text = (value ?? '').trim();
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
    return 'Use YYYY-MM-DD.';
  }
  return DateTime.tryParse(text) == null ? 'Enter a valid date.' : null;
}

int _positiveInt(String value, int fallback) {
  final parsed = int.tryParse(value.trim()) ?? fallback;
  return parsed <= 0 ? fallback : parsed;
}

int _nonNegativeInt(String value, int fallback) {
  final parsed = int.tryParse(value.trim()) ?? fallback;
  return parsed < 0 ? fallback : parsed;
}

String _dateInput(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: AppTheme.error),
  );
}

String _cleanError(Object error) {
  final raw = error.toString();
  final server = RegExp(r'ServerException\([^)]*\):\s*(.*)').firstMatch(raw);
  if (server != null) return server.group(1)?.trim() ?? raw;
  final network = RegExp(r'NetworkException\([^)]*\):\s*(.*)').firstMatch(raw);
  if (network != null) return network.group(1)?.trim() ?? raw;
  return raw.replaceFirst('Exception: ', '').trim();
}
