import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:schooldesk1/core/config/env_config.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/share_export_service.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/principal_directory_ui.dart';
import 'package:schooldesk1/features/academics/presentation/screens/academic_management_screen/academic_management_form_screens.dart';
import 'package:schooldesk1/routes/app_routes.dart';

const _ayBlue = Color(0xFF105DDF);
const _ayInk = Color(0xFF08142F);
const _ayMuted = Color(0xFF60708C);
const _ayBorder = Color(0xFFDCE7F5);
const _ayGreen = Color(0xFF16A34A);
const _ayOrange = Color(0xFFF97316);

class AcademicYearRouteArgs {
  final Map<String, dynamic> year;

  const AcademicYearRouteArgs({required this.year});
}

class PrincipalAcademicYearsScreen extends StatefulWidget {
  const PrincipalAcademicYearsScreen({super.key});

  @override
  State<PrincipalAcademicYearsScreen> createState() =>
      _PrincipalAcademicYearsScreenState();
}

class _PrincipalAcademicYearsScreenState
    extends State<PrincipalAcademicYearsScreen> {
  bool _loading = true;
  String _query = '';
  String _status = 'all';
  List<Map<String, dynamic>> _years = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await BackendApiClient.instance.getAcademicYears();
      if (!mounted) return;
      setState(() {
        _years = rows.map(_yearMap).toList()
          ..sort(
            (a, b) => (_dateValue(a['start_date']) ?? DateTime(1900)).compareTo(
              _dateValue(b['start_date']) ?? DateTime(1900),
            ),
          );
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(context, 'Unable to load academic years: $error', error: true);
    }
  }

  List<Map<String, dynamic>> get _filteredYears {
    final q = _query.trim().toLowerCase();
    return _years.where((year) {
      final status = _yearStatus(year).toLowerCase();
      if (_status != 'all' && status != _status) return false;
      if (q.isEmpty) return true;
      return _yearLabel(year).toLowerCase().contains(q) ||
          _rangeLabel(year).toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return _AyPageShell(
      title: 'Academic Years',
      actions: [
        IconButton(
          tooltip: 'Create academic year',
          onPressed: _openCreate,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: _load,
        color: _ayBlue,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 88),
          children: [
            Row(
              children: [
                Expanded(
                  child: _SearchBox(
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                const SizedBox(width: 12),
                _FilterButton(
                  status: _status,
                  onChanged: (value) => setState(() => _status = value),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filteredYears.isEmpty)
              const _EmptyPanel(
                icon: Icons.calendar_month_outlined,
                title: 'No academic years found',
                body: 'Create an academic year to enable exports.',
              )
            else
              for (final year in _filteredYears) ...[
                _YearListCard(
                  year: year,
                  onView: () => _openDetail(year),
                  onEdit: () => _openEdit(year),
                  onActivate: () => _activate(year),
                  onDelete: () => _deleteYear(year),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _openCreate() async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.academicYearForm,
      arguments: const AcademicYearFormArgs(ownerRole: 'principal'),
    );
    if (result is AcademicFormResult) {
      await _load();
      if (mounted) _snack(context, result.message);
    }
  }

  Future<void> _openEdit(Map<String, dynamic> year) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.academicYearForm,
      arguments: AcademicYearFormArgs(ownerRole: 'principal', year: year),
    );
    if (result is AcademicFormResult) {
      await _load();
      if (mounted) _snack(context, result.message);
    }
  }

  void _openDetail(Map<String, dynamic> year) {
    Navigator.pushNamed(
      context,
      AppRoutes.academicYearDetail,
      arguments: AcademicYearRouteArgs(year: year),
    );
  }

  Future<void> _activate(Map<String, dynamic> year) async {
    try {
      await BackendApiClient.instance.updateAcademicYear(
        '${year['id']}',
        yearLabel: _yearLabel(year),
        startDate: _isoDate(year['start_date']),
        endDate: _isoDate(year['end_date']),
        isCurrent: true,
      );
      await _load();
      if (mounted) {
        _snack(context, '${_yearLabel(year)} set as current');
      }
    } catch (error) {
      if (mounted) {
        _snack(context, 'Unable to update year: $error', error: true);
      }
    }
  }

  Future<void> _deleteYear(Map<String, dynamic> year) async {
    final firstConfirm = await _confirmAcademicYearDelete(context, year);
    if (firstConfirm != true || !mounted) return;
    final finalConfirm = await _confirmAcademicYearFinalDelete(context, year);
    if (finalConfirm != true || !mounted) return;
    try {
      await BackendApiClient.instance.deleteAcademicYear(
        '${year['id']}',
        cascadeConfirmed: true,
      );
      await _load();
      if (mounted) {
        _snack(context, '${_yearLabel(year)} deleted');
      }
    } catch (error) {
      if (mounted) {
        _snack(context, 'Unable to delete year: $error', error: true);
      }
    }
  }
}

class PrincipalAcademicYearDetailScreen extends StatelessWidget {
  final AcademicYearRouteArgs args;

  const PrincipalAcademicYearDetailScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    final year = args.year;
    return _AyPageShell(
      title: _yearLabel(year),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 30),
        children: [
          _YearHeroCard(year: year, centered: true),
          const SizedBox(height: 30),
          Text('Export Data', style: _titleStyle(22)),
          const SizedBox(height: 18),
          _ExportHubCard(
            icon: Icons.co_present_rounded,
            iconColor: _ayBlue,
            title: 'Classwise Data Export',
            subtitle:
                'Classes, sections, students, subjects, timetable summary',
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.academicYearClasswiseExport,
              arguments: args,
            ),
          ),
          const SizedBox(height: 18),
          _ExportHubCard(
            icon: Icons.groups_rounded,
            iconColor: const Color(0xFF7C3AED),
            title: 'Users-wise Data Export',
            subtitle: 'Principal, teachers, class teachers, parents',
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.academicYearUsersExport,
              arguments: args,
            ),
          ),
          const SizedBox(height: 18),
          _ExportHubCard(
            icon: Icons.request_quote_rounded,
            iconColor: _ayGreen,
            title: 'Fees Data Export',
            subtitle: 'Fee structure, invoices, paid, pending, due reports',
            onTap: () => Navigator.pushNamed(
              context,
              AppRoutes.academicYearFeesExport,
              arguments: args,
            ),
          ),
        ],
      ),
    );
  }
}

class AcademicYearClasswiseExportScreen extends StatefulWidget {
  final AcademicYearRouteArgs args;

  const AcademicYearClasswiseExportScreen({super.key, required this.args});

  @override
  State<AcademicYearClasswiseExportScreen> createState() =>
      _AcademicYearClasswiseExportScreenState();
}

class _AcademicYearClasswiseExportScreenState
    extends State<AcademicYearClasswiseExportScreen> {
  String _gradeId = 'all';
  String _sectionId = 'all';
  String _exportType = 'complete_classwise_data';
  String _format = 'xlsx';
  bool _loading = true;
  bool _exporting = false;
  List<GradeModel> _grades = const [];
  List<SectionModel> _sections = const [];
  int _studentCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = BackendApiClient.instance;
      final results = await Future.wait([
        api.getGrades(),
        api.getSections(yearId: '${widget.args.year['id']}'),
        api.getStudents(pageSize: 1),
      ]);
      if (!mounted) return;
      setState(() {
        _grades = results[0] as List<GradeModel>;
        _sections = results[1] as List<SectionModel>;
        _studentCount = (results[2] as PaginatedList<StudentModel>).total;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(context, 'Unable to load export data: $error', error: true);
    }
  }

  List<SectionModel> get _visibleSections => _gradeId == 'all'
      ? _sections
      : _sections.where((section) => section.gradeId == _gradeId).toList();

  @override
  Widget build(BuildContext context) {
    final year = widget.args.year;
    return _AyPageShell(
      title: 'Classwise Export',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 26),
              children: [
                _YearHeroCard(year: year, compact: true),
                const SizedBox(height: 18),
                _AyCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SelectTile(
                        label: 'Select Class',
                        icon: Icons.groups_outlined,
                        value: _gradeId,
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('All Classes'),
                          ),
                          for (final grade in _grades)
                            DropdownMenuItem(
                              value: grade.id,
                              child: Text(grade.gradeName),
                            ),
                        ],
                        onChanged: (value) => setState(() {
                          _gradeId = value ?? 'all';
                          _sectionId = 'all';
                        }),
                      ),
                      _SelectTile(
                        label: 'Select Section',
                        icon: Icons.groups_2_outlined,
                        value: _sectionId,
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('All Sections'),
                          ),
                          for (final section in _visibleSections)
                            DropdownMenuItem(
                              value: section.id,
                              child: Text(_sectionLabel(section)),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _sectionId = value ?? 'all'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _OptionCard(
                  title: 'Export Type',
                  children: [
                    _RadioOption(
                      icon: Icons.bar_chart_rounded,
                      label: 'Class Summary',
                      value: 'class_summary',
                      groupValue: _exportType,
                      onChanged: (value) => setState(() => _exportType = value),
                    ),
                    _RadioOption(
                      icon: Icons.person_outline_rounded,
                      label: 'Students List',
                      value: 'students_list',
                      groupValue: _exportType,
                      onChanged: (value) => setState(() => _exportType = value),
                    ),
                    _RadioOption(
                      icon: Icons.menu_book_outlined,
                      label: 'Subjects Mapping',
                      value: 'subjects_mapping',
                      groupValue: _exportType,
                      onChanged: (value) => setState(() => _exportType = value),
                    ),
                    _RadioOption(
                      icon: Icons.person_pin_outlined,
                      label: 'Teacher Mapping',
                      value: 'teacher_mapping',
                      groupValue: _exportType,
                      onChanged: (value) => setState(() => _exportType = value),
                    ),
                    _RadioOption(
                      icon: Icons.calendar_month_outlined,
                      label: 'Timetable Summary',
                      value: 'timetable_summary',
                      groupValue: _exportType,
                      onChanged: (value) => setState(() => _exportType = value),
                    ),
                    _RadioOption(
                      icon: Icons.storage_outlined,
                      label: 'Complete Classwise Data',
                      value: 'complete_classwise_data',
                      groupValue: _exportType,
                      onChanged: (value) => setState(() => _exportType = value),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _FormatCard(
                  value: _format,
                  onChanged: (value) => setState(() => _format = value),
                ),
                const SizedBox(height: 24),
                _BottomActions(
                  exporting: _exporting,
                  onPreview: _preview,
                  onExport: _export,
                ),
              ],
            ),
    );
  }

  Map<String, dynamic> _parameters() => {
    'academic_year_id': widget.args.year['id'],
    'academic_year': _yearLabel(widget.args.year),
    'grade_id': _gradeId == 'all' ? null : _gradeId,
    'section_id': _sectionId == 'all' ? null : _sectionId,
    'export_type': _exportType,
    'format': _format,
    'section_count': _visibleSections.length,
    'student_count': _studentCount,
  };

  void _preview() {
    _showPreviewSheet(
      context,
      title: 'Classwise Preview',
      rows: [
        ('Academic Year', _yearLabel(widget.args.year)),
        (
          'Class Scope',
          _gradeId == 'all' ? 'All Classes' : _gradeName(_gradeId),
        ),
        ('Sections', '${_visibleSections.length} section(s)'),
        ('Students', '$_studentCount student record(s) available'),
        ('Export Type', _labelize(_exportType)),
        ('Format', _formatLabel(_format)),
      ],
    );
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final export = await BackendApiClient.instance.createReportExport(
        '/reports/exports',
        reportTitle: 'Classwise ${_labelize(_exportType)}',
        reportType: _exportType,
        format: _format,
        scope: 'principal',
        parameters: _parameters(),
      );
      if (mounted) {
        await _downloadExportArtifact(
          context,
          export: export,
          format: _format,
          title: 'Classwise ${_labelize(_exportType)}',
        );
      }
    } catch (error) {
      if (mounted) {
        _snack(context, 'Unable to queue export: $error', error: true);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _gradeName(String id) =>
      _grades.firstWhere((grade) => grade.id == id).gradeName;
}

class AcademicYearUsersExportScreen extends StatefulWidget {
  final AcademicYearRouteArgs args;

  const AcademicYearUsersExportScreen({super.key, required this.args});

  @override
  State<AcademicYearUsersExportScreen> createState() =>
      _AcademicYearUsersExportScreenState();
}

class _AcademicYearUsersExportScreenState
    extends State<AcademicYearUsersExportScreen> {
  final Set<String> _roles = {'principal', 'teacher', 'parent'};
  String _status = 'all';
  String _format = 'xlsx';
  bool _exporting = false;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    try {
      var total = 0;
      for (final role in _roles) {
        final result = await BackendApiClient.instance.getUsers(
          role: role,
          status: _status == 'all' ? null : _status,
          pageSize: 1,
        );
        total += result.total;
      }
      if (mounted) setState(() => _total = total);
    } catch (error) {
      if (EnvConfig.enableLogging) {
        developer.log(
          'Failed to load user count for export: $error',
          name: 'AcademicYearUsersExportScreen',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final year = widget.args.year;
    return _AyPageShell(
      title: 'Users-wise Export',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 26),
        children: [
          _YearHeroCard(year: year),
          const SizedBox(height: 18),
          _OptionCard(
            title: 'User Role',
            top: _SelectFieldShell(
              icon: Icons.people_outline_rounded,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: 'all',
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Users')),
                  ],
                  onChanged: (_) {},
                ),
              ),
            ),
            children: [
              _CheckOption(
                icon: Icons.person_outline_rounded,
                label: 'Principal',
                value: _roles.contains('principal'),
                onChanged: (value) => _toggleRole('principal', value),
              ),
              _CheckOption(
                icon: Icons.school_outlined,
                label: 'Teacher',
                value: _roles.contains('teacher'),
                onChanged: (value) => _toggleRole('teacher', value),
              ),
              _CheckOption(
                icon: Icons.person_pin_outlined,
                label: 'Class Teacher',
                value: _roles.contains('class_teacher'),
                onChanged: (value) => _toggleRole('class_teacher', value),
              ),
              _CheckOption(
                icon: Icons.groups_2_outlined,
                label: 'Parents / Guardians',
                value: _roles.contains('parent'),
                onChanged: (value) => _toggleRole('parent', value),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _AyCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Segmented(
                  title: 'Status',
                  value: _status,
                  values: const ['all', 'active', 'inactive'],
                  onChanged: (value) {
                    setState(() => _status = value);
                    _loadCount();
                  },
                ),
                const SizedBox(height: 24),
                _Segmented(
                  title: 'File Format',
                  value: _format,
                  values: const ['csv', 'xlsx', 'pdf'],
                  onChanged: (value) => setState(() => _format = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _BottomActions(
            vertical: true,
            exporting: _exporting,
            onPreview: _preview,
            onExport: _export,
          ),
        ],
      ),
    );
  }

  void _toggleRole(String role, bool value) {
    setState(() {
      if (value) {
        _roles.add(role);
      } else {
        _roles.remove(role);
      }
    });
    _loadCount();
  }

  void _preview() {
    _showPreviewSheet(
      context,
      title: 'Users-wise Preview',
      rows: [
        ('Academic Year', _yearLabel(widget.args.year)),
        ('Roles', _roles.map(_labelize).join(', ')),
        ('Status', _labelize(_status)),
        ('Matched Users', '$_total user account(s)'),
        ('Format', _formatLabel(_format)),
      ],
    );
  }

  Future<void> _export() async {
    if (_roles.isEmpty) {
      _snack(context, 'Select at least one role.', error: true);
      return;
    }
    setState(() => _exporting = true);
    try {
      final export = await BackendApiClient.instance.createReportExport(
        '/reports/exports',
        reportTitle: 'Users-wise Data Export',
        reportType: 'users_wise_export',
        format: _format,
        scope: 'principal',
        parameters: {
          'academic_year_id': widget.args.year['id'],
          'academic_year': _yearLabel(widget.args.year),
          'roles': _roles.toList(),
          'status': _status,
          'matched_users': _total,
        },
      );
      if (mounted) {
        await _downloadExportArtifact(
          context,
          export: export,
          format: _format,
          title: 'Users-wise Data Export',
        );
      }
    } catch (error) {
      if (mounted) {
        _snack(context, 'Unable to queue export: $error', error: true);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

class AcademicYearFeesExportScreen extends StatefulWidget {
  final AcademicYearRouteArgs args;

  const AcademicYearFeesExportScreen({super.key, required this.args});

  @override
  State<AcademicYearFeesExportScreen> createState() =>
      _AcademicYearFeesExportScreenState();
}

class _AcademicYearFeesExportScreenState
    extends State<AcademicYearFeesExportScreen> {
  String _gradeId = 'all';
  String _sectionId = 'all';
  String _reportType = 'complete_fees_report';
  String _paymentStatus = 'all';
  String _format = 'pdf';
  bool _loading = true;
  bool _exporting = false;
  List<GradeModel> _grades = const [];
  List<SectionModel> _sections = const [];
  int _invoiceCount = 0;
  int _structureCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = BackendApiClient.instance;
      final yearId = '${widget.args.year['id']}';
      final results = await Future.wait([
        api.getGrades(),
        api.getSections(yearId: yearId),
        api.getFeeStructures(academicYearId: yearId),
        api.getInvoicesPage(academicYearId: yearId, pageSize: 1),
      ]);
      if (!mounted) return;
      setState(() {
        _grades = results[0] as List<GradeModel>;
        _sections = results[1] as List<SectionModel>;
        _structureCount = (results[2] as List<Map<String, dynamic>>).length;
        _invoiceCount =
            (results[3] as PaginatedList<Map<String, dynamic>>).total;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(context, 'Unable to load fees data: $error', error: true);
    }
  }

  List<SectionModel> get _visibleSections => _gradeId == 'all'
      ? _sections
      : _sections.where((section) => section.gradeId == _gradeId).toList();

  @override
  Widget build(BuildContext context) {
    final year = widget.args.year;
    return _AyPageShell(
      title: 'Fees Export',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 26),
              children: [
                Center(child: _YearChip(year: year)),
                const SizedBox(height: 20),
                _AyCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SelectTile(
                        label: 'Select Class',
                        icon: Icons.school_outlined,
                        value: _gradeId,
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('All Classes'),
                          ),
                          for (final grade in _grades)
                            DropdownMenuItem(
                              value: grade.id,
                              child: Text(grade.gradeName),
                            ),
                        ],
                        onChanged: (value) => setState(() {
                          _gradeId = value ?? 'all';
                          _sectionId = 'all';
                        }),
                      ),
                      _SelectTile(
                        label: 'Select Section',
                        icon: Icons.groups_2_outlined,
                        value: _sectionId,
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('All Sections'),
                          ),
                          for (final section in _visibleSections)
                            DropdownMenuItem(
                              value: section.id,
                              child: Text(_sectionLabel(section)),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _sectionId = value ?? 'all'),
                      ),
                      const SizedBox(height: 10),
                      Text('Fee Report Type', style: _labelStyle(18)),
                      for (final item in const [
                        ('fee_structure', 'Fee Structure'),
                        ('student_fee_invoices', 'Student Fee Invoices'),
                        ('paid_fees', 'Paid Fees'),
                        ('pending_fees', 'Pending Fees'),
                        ('due_fees', 'Due Fees'),
                        ('complete_fees_report', 'Complete Fees Report'),
                      ])
                        RadioListTile<String>(
                          value: item.$1,
                          groupValue: _reportType,
                          onChanged: (value) =>
                              setState(() => _reportType = value ?? item.$1),
                          title: Text(item.$2, style: _bodyStyle()),
                          activeColor: _ayBlue,
                          contentPadding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _AyCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Payment Status', style: _labelStyle(18)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final item in const [
                            'all',
                            'paid',
                            'partial',
                            'pending',
                            'overdue',
                          ])
                            _ChoicePill(
                              label: _labelize(item),
                              selected: _paymentStatus == item,
                              onTap: () =>
                                  setState(() => _paymentStatus = item),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Divider(color: _ayBorder),
                      const SizedBox(height: 18),
                      _FormatCard(
                        value: _format,
                        onChanged: (value) => setState(() => _format = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _BottomActions(
                  exporting: _exporting,
                  onPreview: _preview,
                  onExport: _export,
                ),
              ],
            ),
    );
  }

  void _preview() {
    _showPreviewSheet(
      context,
      title: 'Fees Preview',
      rows: [
        ('Academic Year', _yearLabel(widget.args.year)),
        ('Structures', '$_structureCount fee structure(s)'),
        ('Invoices', '$_invoiceCount invoice(s)'),
        ('Payment Status', _labelize(_paymentStatus)),
        ('Report Type', _labelize(_reportType)),
        ('Format', _formatLabel(_format)),
      ],
    );
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final export = await BackendApiClient.instance.createReportExport(
        '/fees/reports/exports',
        reportTitle: _labelize(_reportType),
        reportType: _reportType,
        format: _format,
        scope: 'principal',
        parameters: {
          'academic_year_id': widget.args.year['id'],
          'academic_year': _yearLabel(widget.args.year),
          'grade_id': _gradeId == 'all' ? null : _gradeId,
          'section_id': _sectionId == 'all' ? null : _sectionId,
          'payment_status': _paymentStatus,
          'invoice_count': _invoiceCount,
          'structure_count': _structureCount,
        },
      );
      if (mounted) {
        await _downloadExportArtifact(
          context,
          export: export,
          format: _format,
          title: _labelize(_reportType),
        );
      }
    } catch (error) {
      if (mounted) {
        _snack(context, 'Unable to queue export: $error', error: true);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

class _AyPageShell extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;

  const _AyPageShell({
    required this.title,
    required this.child,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: principalDirectoryBackground,
      bottomNavigationBar: const PrincipalShellBottomBar(),
      body: SafeArea(
        child: Column(
          children: [
            PrincipalDirectoryHeader(
              title: title,
              subtitle: 'Academic sessions, exports, and yearly setup',
              actions: actions,
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YearListCard extends StatelessWidget {
  final Map<String, dynamic> year;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onActivate;
  final VoidCallback onDelete;

  const _YearListCard({
    required this.year,
    required this.onView,
    required this.onEdit,
    required this.onActivate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _AyCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CalendarBadge(status: _yearStatus(year), size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _yearLabel(year),
                        style: _titleStyle(17),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _StatusPill(status: _yearStatus(year)),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: _ayMuted,
                      ),
                      onSelected: (value) {
                        if (value == 'edit') onEdit();
                        if (value == 'activate') onActivate();
                        if (value == 'delete') onDelete();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(
                          value: 'activate',
                          child: Text('Mark current'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Delete',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_rangeLabel(year), style: _mutedStyle(12)),
                const SizedBox(height: 12),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    if (_isCurrent(year)) const _CurrentChip(compact: true),
                    SizedBox(
                      width: 88,
                      child: _OutlineButton(label: 'View', onPressed: onView),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _YearHeroCard extends StatelessWidget {
  final Map<String, dynamic> year;
  final bool compact;
  final bool centered;

  const _YearHeroCard({
    required this.year,
    this.compact = false,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    return _AyCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _CalendarBadge(status: _yearStatus(year), size: compact ? 48 : 60),
          SizedBox(width: compact ? 14 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: centered
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  compact
                      ? 'Academic Year:  ${_yearLabel(year)}'
                      : _yearLabel(year),
                  style: compact ? _titleStyle(16) : _titleStyle(20),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!compact) ...[
                  const SizedBox(height: 8),
                  Text(_rangeLabel(year), style: _mutedStyle(13)),
                  if (_isCurrent(year)) ...[
                    const SizedBox(height: 18),
                    const _CurrentChip(),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Flexible(child: _StatusPill(status: _yearStatus(year))),
        ],
      ),
    );
  }
}

class _YearChip extends StatelessWidget {
  final Map<String, dynamic> year;

  const _YearChip({required this.year});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ayBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1408142F),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month_rounded, color: _ayGreen),
          const SizedBox(width: 12),
          Text('Academic Year: ', style: _mutedStyle(17)),
          Text(_yearLabel(year), style: _labelStyle(17, color: _ayGreen)),
        ],
      ),
    );
  }
}

class _ExportHubCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ExportHubCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _AyCard(
      padding: const EdgeInsets.all(20),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(22),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 27),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _titleStyle(15)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: _mutedStyle(12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _ayBlue, size: 24),
          ],
        ),
      ),
    );
  }
}

class _AyCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _AyCard({required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ayBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1208142F),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SearchBox extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SearchBox({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search academic years...',
        prefixIcon: const Icon(Icons.search_rounded, size: 22),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _ayBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _ayBorder),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String status;
  final ValueChanged<String> onChanged;

  const _FilterButton({required this.status, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'all', child: Text('All')),
        PopupMenuItem(value: 'active', child: Text('Active')),
        PopupMenuItem(value: 'closed', child: Text('Closed')),
        PopupMenuItem(value: 'upcoming', child: Text('Upcoming')),
      ],
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _ayBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.tune_rounded, color: _ayBlue),
            const SizedBox(width: 10),
            Text(
              status == 'all' ? 'Filter' : _labelize(status),
              style: _labelStyle(13, color: _ayBlue),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String title;
  final Widget? top;
  final List<Widget> children;

  const _OptionCard({required this.title, required this.children, this.top});

  @override
  Widget build(BuildContext context) {
    return _AyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (top != null) ...[
            Text(title, style: _labelStyle(18)),
            const SizedBox(height: 10),
            top!,
            const SizedBox(height: 22),
            Text('Options', style: _labelStyle(19)),
            const SizedBox(height: 14),
            const Divider(color: _ayBorder),
          ] else ...[
            Text(title, style: _labelStyle(18)),
            const SizedBox(height: 12),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _SelectTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;

  const _SelectTile({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _labelStyle(18)),
          const SizedBox(height: 10),
          _SelectFieldShell(
            icon: icon,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectFieldShell extends StatelessWidget {
  final IconData icon;
  final Widget child;

  const _SelectFieldShell({required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: _ayBorder),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Icon(icon, color: _ayBlue),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _RadioOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;

  const _RadioOption({
    required this.icon,
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      value: value,
      groupValue: groupValue,
      activeColor: _ayBlue,
      contentPadding: EdgeInsets.zero,
      onChanged: (value) => onChanged(value ?? this.value),
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFEFF5FF),
            child: Icon(icon, color: _ayBlue, size: 23),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: _bodyStyle())),
        ],
      ),
    );
  }
}

class _CheckOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CheckOption({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      activeColor: _ayBlue,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      secondary: Icon(icon, color: value ? _ayBlue : _ayMuted),
      title: Text(label, style: _bodyStyle()),
      onChanged: (value) => onChanged(value ?? false),
    );
  }
}

class _FormatCard extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _FormatCard({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _AyCard(
      child: _Segmented(
        title: 'File Format',
        value: value,
        values: const ['csv', 'xlsx', 'pdf'],
        onChanged: onChanged,
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  final String title;
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  const _Segmented({
    required this.title,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: _labelStyle(18)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _ayBorder),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            children: [
              for (final item in values)
                Expanded(
                  child: InkWell(
                    onTap: () => onChanged(item),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: value == item
                            ? const Color(0xFFF0F6FF)
                            : Colors.transparent,
                        border: Border(
                          left: item == values.first
                              ? BorderSide.none
                              : const BorderSide(color: _ayBorder),
                        ),
                      ),
                      child: Text(
                        _formatLabel(item),
                        style: _labelStyle(
                          16,
                          color: value == item ? _ayBlue : _ayInk,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0F6FF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? _ayBlue : _ayBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? _ayBlue : _ayMuted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: _labelStyle(14, color: selected ? _ayBlue : _ayInk),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final bool exporting;
  final VoidCallback onPreview;
  final VoidCallback onExport;
  final bool vertical;

  const _BottomActions({
    required this.exporting,
    required this.onPreview,
    required this.onExport,
    this.vertical = false,
  });

  @override
  Widget build(BuildContext context) {
    final preview = _OutlineButton(
      label: 'Preview Data',
      icon: Icons.remove_red_eye_outlined,
      onPressed: onPreview,
      expanded: true,
    );
    final export = _PrimaryPillButton(
      label: exporting ? 'Exporting...' : 'Export',
      icon: Icons.file_download_outlined,
      onPressed: exporting ? null : onExport,
    );
    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [preview, const SizedBox(height: 14), export],
      );
    }
    return Row(
      children: [
        Expanded(child: preview),
        const SizedBox(width: 18),
        Expanded(child: export),
      ],
    );
  }
}

class _PrimaryPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _PrimaryPillButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      height: 58,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 26),
        label: Text(label, style: _labelStyle(18, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _ayBlue,
          disabledBackgroundColor: _ayBlue.withAlpha(130),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
    return button;
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool expanded;

  const _OutlineButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      side: const BorderSide(color: _ayBlue, width: 1.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    return SizedBox(
      height: 52,
      width: expanded ? double.infinity : 88,
      child: icon == null
          ? OutlinedButton(
              onPressed: onPressed,
              style: style,
              child: Text(label, style: _labelStyle(14, color: _ayBlue)),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, color: _ayBlue, size: 22),
              label: Text(label, style: _labelStyle(14, color: _ayBlue)),
              style: style,
            ),
    );
  }
}

class _CalendarBadge extends StatelessWidget {
  final String status;
  final double size;

  const _CalendarBadge({required this.status, required this.size});

  @override
  Widget build(BuildContext context) {
    final color = status == 'upcoming'
        ? _ayOrange
        : status == 'closed'
        ? _ayMuted
        : _ayGreen;
    final icon = status == 'upcoming'
        ? Icons.access_time_rounded
        : status == 'closed'
        ? Icons.close_rounded
        : Icons.check_rounded;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.calendar_month_rounded, color: color, size: size * .55),
          Positioned(
            right: size * .15,
            bottom: size * .15,
            child: CircleAvatar(
              radius: size * .14,
              backgroundColor: color,
              child: Icon(icon, size: size * .18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == 'upcoming'
        ? _ayOrange
        : status == 'closed'
        ? _ayMuted
        : _ayGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 10),
          const SizedBox(width: 8),
          Text(_labelize(status), style: _labelStyle(14, color: color)),
        ],
      ),
    );
  }
}

class _CurrentChip extends StatelessWidget {
  final bool compact;

  const _CurrentChip({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: compact ? 118 : 220),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: _ayGreen.withAlpha(20),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bookmark_border_rounded,
            color: _ayGreen,
            size: compact ? 18 : 24,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              compact ? 'Current' : 'Current Academic Year',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _labelStyle(compact ? 13 : 15, color: _ayGreen),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return _AyCard(
      child: Column(
        children: [
          Icon(icon, color: _ayMuted, size: 48),
          const SizedBox(height: 12),
          Text(title, style: _titleStyle(20), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(body, style: _mutedStyle(15), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

Map<String, dynamic> _yearMap(AcademicYearModel year) => {
  'id': year.id,
  'school_id': year.schoolId,
  'name': year.yearLabel,
  'year_label': year.yearLabel,
  'start_date': year.startDate,
  'end_date': year.endDate,
  'is_current': year.isCurrent,
  'status': year.status,
};

String _yearLabel(Map<String, dynamic> year) =>
    '${year['year_label'] ?? year['name'] ?? year['year'] ?? 'Academic Year'}';

bool _isCurrent(Map<String, dynamic> year) =>
    year['is_current'] == true || '${year['status']}'.toLowerCase() == 'active';

String _yearStatus(Map<String, dynamic> year) {
  final status = '${year['status'] ?? ''}'.toLowerCase();
  if (status == 'closed' || status == 'upcoming' || status == 'active') {
    return status;
  }
  if (_isCurrent(year)) return 'active';
  final start = _dateValue(year['start_date']);
  final end = _dateValue(year['end_date']);
  final now = DateTime.now();
  if (end != null && end.isBefore(DateTime(now.year, now.month, now.day))) {
    return 'closed';
  }
  if (start != null && start.isAfter(now)) return 'upcoming';
  return 'active';
}

String _rangeLabel(Map<String, dynamic> year) {
  final start = _dateValue(year['start_date']);
  final end = _dateValue(year['end_date']);
  if (start == null || end == null) return '';
  return '${DateFormat('MMM yyyy').format(start)} - ${DateFormat('MMM yyyy').format(end)}';
}

DateTime? _dateValue(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse('$value'.split('T').first);
}

String _isoDate(Object? value) {
  final date = _dateValue(value);
  if (date == null) return '${value ?? ''}'.split('T').first;
  return DateFormat('yyyy-MM-dd').format(date);
}

String _sectionLabel(SectionModel section) {
  final grade = section.gradeName.trim().isEmpty ? 'Class' : section.gradeName;
  return '$grade ${section.sectionName}'.trim();
}

String _labelize(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');

String _formatLabel(String value) {
  switch (value.toLowerCase().trim()) {
    case 'csv':
      return 'CSV';
    case 'xlsx':
    case 'excel':
      return 'Excel';
    case 'pdf':
      return 'PDF';
    case 'json':
      return 'JSON';
    default:
      return _labelize(value);
  }
}

double _ayResponsiveTextScale([BuildContext? context]) {
  final width = context == null ? 360.0 : MediaQuery.sizeOf(context).width;
  if (width < 360) return .78;
  if (width < 430) return .86;
  if (width < 600) return .94;
  return 1;
}

TextStyle _ayFont(
  double size, {
  BuildContext? context,
  Color color = _ayInk,
  FontWeight fontWeight = FontWeight.w700,
}) {
  return GoogleFonts.dmSans(
    color: color,
    fontWeight: fontWeight,
    letterSpacing: 0,
  ).copyWith(fontSize: size * _ayResponsiveTextScale(context));
}

TextStyle _titleStyle(double size, {BuildContext? context}) =>
    _ayFont(size, context: context, color: _ayInk, fontWeight: FontWeight.w900);

TextStyle _labelStyle(
  double size, {
  BuildContext? context,
  Color color = _ayInk,
}) =>
    _ayFont(size, context: context, color: color, fontWeight: FontWeight.w800);

TextStyle _bodyStyle({BuildContext? context}) =>
    _ayFont(17, context: context, color: _ayInk, fontWeight: FontWeight.w600);

TextStyle _mutedStyle(double size, {BuildContext? context}) => _ayFont(
  size,
  context: context,
  color: _ayMuted,
  fontWeight: FontWeight.w600,
);

Future<bool?> _confirmAcademicYearDelete(
  BuildContext context,
  Map<String, dynamic> year,
) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete academic year?'),
      content: Text(
        'This will permanently delete ${_yearLabel(year)}. The backend will block deletion if classes, terms, fees, attendance, exams, or events still use this academic year.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.warning_amber_rounded),
          label: const Text('Continue'),
        ),
      ],
    ),
  );
}

Future<bool?> _confirmAcademicYearFinalDelete(
  BuildContext context,
  Map<String, dynamic> year,
) async {
  final controller = TextEditingController();
  try {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        var canDelete = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Final confirmation'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type DELETE to confirm deleting ${_yearLabel(year)}.'),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Confirmation',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setDialogState(
                    () => canDelete = value.trim().toUpperCase() == 'DELETE',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: canDelete
                    ? () => Navigator.pop(context, true)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
    );
  } finally {
    controller.dispose();
  }
}

Future<void> _downloadExportArtifact(
  BuildContext context, {
  required Map<String, dynamic> export,
  required String format,
  required String title,
}) async {
  final downloadUrl = '${export['download_url'] ?? ''}'.trim();
  if (downloadUrl.isEmpty) {
    _snack(context, '$title export queued');
    return;
  }
  final bytes = await BackendApiClient.instance.downloadReportExport(
    downloadUrl,
  );
  if (bytes.isEmpty) {
    throw StateError('Export file was empty');
  }
  await const ShareExportService().shareBytes(
    bytes: bytes,
    fileName: _exportFileName(downloadUrl, format, title),
    mimeType: _exportMimeType(format),
    title: title,
    subject: title,
    text: '$title generated from SchoolDesk.',
  );
  if (context.mounted) {
    _snack(context, '$title downloaded');
  }
}

String _exportFileName(String downloadUrl, String format, String title) {
  final path = Uri.tryParse(downloadUrl)?.path ?? '';
  final segments = path.split('/').where((part) => part.isNotEmpty).toList();
  final lastSegment = segments.isEmpty ? null : segments.last;
  if (lastSegment != null && lastSegment.contains('.')) return lastSegment;
  final safeTitle = title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final extension = format == 'xlsx' || format == 'excel' ? 'xlsx' : format;
  return '${safeTitle.isEmpty ? 'academic_export' : safeTitle}.$extension';
}

String _exportMimeType(String format) {
  switch (format.toLowerCase().trim()) {
    case 'csv':
      return 'text/csv';
    case 'xlsx':
    case 'excel':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'pdf':
      return 'application/pdf';
    default:
      return 'application/octet-stream';
  }
}

void _snack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red.shade700 : _ayGreen,
    ),
  );
}

void _showPreviewSheet(
  BuildContext context, {
  required String title,
  required List<(String, String)> rows,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _titleStyle(22)),
          const SizedBox(height: 14),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  Expanded(child: Text(row.$1, style: _mutedStyle(14))),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      row.$2,
                      textAlign: TextAlign.right,
                      style: _labelStyle(14),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
