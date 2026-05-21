import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend_api_client.dart';
import '../../theme/app_theme.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/admin_navigation.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_components.dart';
import '../../widgets/erp_module_scaffold.dart';

class AdminStudentsScreen extends StatefulWidget {
  final String ownerRole;

  const AdminStudentsScreen({super.key, this.ownerRole = 'admin'});

  @override
  State<AdminStudentsScreen> createState() => _AdminStudentsScreenState();
}

class _AdminStudentsScreenState extends State<AdminStudentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _search = '';
  String _filterClass = 'All';
  List<Map<String, dynamic>> _students = [];
  String? _defaultSectionId;
  bool _loading = true;
  List<String> _classes = ['All'];
  List<Map<String, String>> _sectionOptions = [];
  List<Map<String, String>> _parentOptions = [];

  bool get _isPrincipal => widget.ownerRole.toLowerCase() == 'principal';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    await _refreshFromBackend();
  }

  Future<void> _refreshFromBackend() async {
    try {
      final grades = await BackendApiClient.instance.getGrades();
      final sections = await BackendApiClient.instance.getSections();
      final students = await BackendApiClient.instance.getStudents(
        page: 1,
        pageSize: 500,
      );
      final parents = await _loadParentAccounts();
      final parentByAdmission = await _loadParentMap(parents);

      if (sections.isNotEmpty) {
        _defaultSectionId = sections.first.id;
      }

      final gradeMap = {for (final g in grades) g.id: g};
      final sectionMap = {for (final s in sections) s.id: s};
      final sectionOptions = sections.map((section) {
        final grade = gradeMap[section.gradeId];
        final gradeLabel = grade == null ? 'Class' : 'Class ${grade.gradeName}';
        return {
          'id': section.id,
          'label': '$gradeLabel ${section.sectionName}',
        };
      }).toList();
      setState(() {
        _sectionOptions = sectionOptions;
        _classes = ['All', ...sectionOptions.map((e) => e['label']!)];
        _parentOptions = parents
            .map(
              (parent) => {
                'id': parent.id,
                'label': _parentLabel(parent),
                'phone': parent.phone,
              },
            )
            .toList();
        _students = students.data.map((s) {
          final sectionLabel = _sectionLabel(
            s.currentSectionId,
            sectionMap,
            gradeMap,
          );
          final roll = s.admissionNumber.isNotEmpty
              ? s.admissionNumber
              : s.studentCode;
          final parentLink =
              parentByAdmission[s.admissionNumber.toLowerCase().trim()] ??
              parentByAdmission[s.studentCode.toLowerCase().trim()];
          return {
            'id': s.id,
            'name': s.fullName,
            'class': sectionLabel,
            'sectionId': s.currentSectionId,
            'status': s.status,
            'admissionNumber': s.admissionNumber,
            'studentCode': s.studentCode,
            'roll': roll,
            'parent': parentLink?['label'] ?? '',
            'parentId': parentLink?['id'] ?? '',
            'phone': parentLink?['phone'] ?? '',
            'dob': _dateOnly(s.dateOfBirth),
            'gender': s.gender ?? '',
            'docs': <String>[],
          };
        }).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _students = [];
        _loading = false;
      });
    }
  }

  Future<List<UserAccountModel>> _loadParentAccounts() async {
    try {
      final result = await BackendApiClient.instance.getUsers(
        role: 'Parent',
        status: 'active',
        page: 1,
        pageSize: 500,
      );
      return result.data
          .where((user) => user.roleName.toLowerCase() == 'parent')
          .toList();
    } catch (_) {
      return const <UserAccountModel>[];
    }
  }

  Future<Map<String, Map<String, String>>> _loadParentMap(
    List<UserAccountModel> parents,
  ) async {
    final mapped = <String, Map<String, String>>{};
    for (final parent in parents) {
      try {
        final linked = await BackendApiClient.instance.getParentStudents(
          parentUserId: parent.id,
        );
        for (final row in linked) {
          final admission =
              '${row['student_admission_number'] ?? row['admission_number'] ?? ''}'
                  .trim()
                  .toLowerCase();
          if (admission.isEmpty) continue;
          mapped[admission] = {
            'id': parent.id,
            'label': _parentLabel(parent),
            'phone': parent.phone,
          };
        }
      } catch (_) {
        continue;
      }
    }
    return mapped;
  }

  String _parentLabel(UserAccountModel parent) {
    final name = parent.name.trim();
    if (name.isNotEmpty) return name;
    if (parent.username.trim().isNotEmpty) return parent.username.trim();
    if (parent.email.trim().isNotEmpty) return parent.email.trim();
    return 'Parent account';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    return _students.where((s) {
      final matchSearch =
          s['name'].toString().toLowerCase().contains(_search.toLowerCase()) ||
          s['id'].toString().toLowerCase().contains(_search.toLowerCase()) ||
          s['admissionNumber'].toString().toLowerCase().contains(
            _search.toLowerCase(),
          ) ||
          s['parent'].toString().toLowerCase().contains(_search.toLowerCase());
      final matchClass =
          _filterClass == 'All' || s['class'].toString() == _filterClass;
      return matchSearch && matchClass;
    }).toList();
  }

  String _sectionLabel(
    String? sectionId,
    Map<String, SectionModel> sectionMap,
    Map<String, GradeModel> gradeMap,
  ) {
    if (sectionId == null || sectionId.isEmpty) return 'Unassigned';
    final section = sectionMap[sectionId];
    if (section == null) return 'Unassigned';
    final grade = gradeMap[section.gradeId];
    final gradeLabel = grade == null ? 'Class' : 'Class ${grade.gradeName}';
    return '$gradeLabel ${section.sectionName}';
  }

  String _dateOnly(String? value) {
    if (value == null || value.isEmpty) return '2010-01-01';
    return value.length >= 10 ? value.substring(0, 10) : value;
  }

  @override
  Widget build(BuildContext context) {
    final Widget drawer = _isPrincipal
        ? PrincipalDrawer(selectedIndex: 2, onDestinationSelected: (_) {})
        : AdminDrawer(selectedIndex: 1, onDestinationSelected: (_) {});
    return SchoolDeskModuleScaffold(
      title: _isPrincipal ? 'Student Oversight' : 'Students',
      subtitle: _isPrincipal
          ? 'Review student records and handle requested changes'
          : 'Create, assign, and maintain student records',
      drawer: drawer,
      floatingActionButton: DashboardFabWidget(
        role: _isPrincipal ? DashboardRole.principal : DashboardRole.admin,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      actions: [
        IconButton(
          tooltip: 'Refresh students',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _refreshFromBackend,
        ),
        FilledButton.icon(
          onPressed: _openAddStudentPage,
          icon: const Icon(Icons.person_add_rounded, size: 18),
          label: Text(_isPrincipal ? 'Add student' : 'Request student'),
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: const [
          Tab(text: 'All Students'),
          Tab(text: 'Admissions'),
          Tab(text: 'Transfers'),
        ],
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: SchoolDeskStatusPanel.loading(
                message: 'Loading students from backend',
              ),
            )
          : Column(
              children: [
                _buildSearchFilter(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildStudentList(_filtered),
                      _buildStudentList(
                        _filtered
                            .where((s) => s['status']?.toString() == 'pending')
                            .toList(),
                      ),
                      _buildStudentList(
                        _filtered
                            .where((s) => s['status']?.toString() == 'transfer')
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchFilter() {
    final tokens = Theme.of(context).schoolDesk;
    return Container(
      color: tokens.panel,
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.md,
        tokens.spacing.sm,
        tokens.spacing.md,
        tokens.spacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SchoolDeskDataToolbar(
            searchLabel: 'Search students by name or ID',
            onSearchChanged: (v) => setState(() => _search = v),
          ),
          SizedBox(height: tokens.spacing.xs),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _classes.length,
              separatorBuilder: (_, __) => SizedBox(width: tokens.spacing.xs),
              itemBuilder: (_, i) {
                final selected = _filterClass == _classes[i];
                return FilterChip(
                  label: Text(_classes[i], overflow: TextOverflow.ellipsis),
                  selected: selected,
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  selectedColor: AppTheme.primaryContainer,
                  backgroundColor: AppTheme.surfaceVariant,
                  side: BorderSide(
                    color: selected ? AppTheme.primary : AppTheme.outline,
                  ),
                  labelStyle: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppTheme.primary : AppTheme.onSurface,
                  ),
                  onSelected: (_) => setState(() => _filterClass = _classes[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList(List<Map<String, dynamic>> students) {
    final tokens = Theme.of(context).schoolDesk;
    if (students.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: SchoolDeskStatusPanel.empty(
          title: 'No students found',
          message: 'Try another class filter or add a new student record.',
        ),
      );
    }
    return Semantics(
      label: '${students.length} students list',
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.md,
          tokens.spacing.md,
          tokens.spacing.md,
          96,
        ),
        itemCount: students.length,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        itemBuilder: (_, i) {
          if (i > 0) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                _buildStudentCard(students[i]),
              ],
            );
          }
          return _buildStudentCard(students[i]);
        },
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> s) {
    final status = s['status']?.toString() ?? 'active';
    final statusLabel = status.isEmpty
        ? 'Active'
        : '${status[0].toUpperCase()}${status.substring(1)}';
    return SchoolDeskRecordCard(
      title: s['name'] as String,
      subtitle:
          '${s['class']} • Roll No. ${s['roll']} • ID: ${s['id']}'
          '${_studentContactLine(s).isEmpty ? '' : '\n${_studentContactLine(s)}'}',
      leadingIcon: Icons.school_rounded,
      semanticLabel: 'Student ${s['name']}, ${s['class']}, status $statusLabel',
      chips: [
        SchoolDeskRecordChip(label: statusLabel, tone: _statusTone(status)),
        SchoolDeskRecordChip(label: '${s['class']}'),
        SchoolDeskRecordChip(label: 'Roll ${s['roll']}'),
        if ('${s['parent'] ?? ''}'.trim().isNotEmpty)
          SchoolDeskRecordChip(
            label: 'Parent linked',
            tone: RecordChipTone.info,
          ),
        if ((s['docs'] as List).isNotEmpty)
          SchoolDeskRecordChip(
            label: '${(s['docs'] as List).length} docs',
            tone: RecordChipTone.info,
          ),
      ],
      trailing: Semantics(
        label: 'More actions for ${s['name']}',
        child: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, size: 20),
          onSelected: (v) => _handleStudentAction(context, v, s),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'edit',
              child: Text(_isPrincipal ? 'Edit Profile' : 'Request Edit'),
            ),
            const PopupMenuItem(value: 'docs', child: Text('Upload Documents')),
            PopupMenuItem(
              value: 'transfer',
              child: Text(
                _isPrincipal ? 'Transfer Student' : 'Request Transfer',
              ),
            ),
            PopupMenuItem(
              value: 'promote',
              child: Text(
                _isPrincipal ? 'Promote to Next Class' : 'Request Promotion',
              ),
            ),
            PopupMenuItem(
              value: 'tc',
              child: Text(_isPrincipal ? 'Issue TC' : 'Request TC'),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text(_isPrincipal ? 'Delete' : 'Request Delete'),
            ),
          ],
        ),
      ),
    );
  }

  String _studentContactLine(Map<String, dynamic> s) {
    final parent = '${s['parent'] ?? ''}'.trim();
    final phone = '${s['phone'] ?? ''}'.trim();
    if (parent.isEmpty && phone.isEmpty) return '';
    return [
      if (parent.isNotEmpty) 'Parent: $parent',
      if (phone.isNotEmpty) phone,
    ].join(' • ');
  }

  RecordChipTone _statusTone(String status) {
    switch (status) {
      case 'active':
        return RecordChipTone.success;
      case 'pending':
        return RecordChipTone.warning;
      case 'transfer':
        return RecordChipTone.info;
      case 'inactive':
        return RecordChipTone.neutral;
      default:
        return RecordChipTone.neutral;
    }
  }

  void _handleStudentAction(
    BuildContext context,
    String action,
    Map<String, dynamic> s,
  ) {
    switch (action) {
      case 'edit':
        _openEditStudentPage(s);
        break;
      case 'docs':
        _openDocumentUploadPage(s);
        break;
      case 'transfer':
        _showTransferDialog(context, s);
        break;
      case 'promote':
        _openPromoteStudentPage(s);
        break;
      case 'tc':
        _showTCDialog(context, s);
        break;
      case 'delete':
        _deleteStudent(s);
        break;
    }
  }

  void _deleteStudent(Map<String, dynamic> s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          _isPrincipal ? 'Remove Student' : 'Request Student Removal',
        ),
        content: Text(
          _isPrincipal
              ? 'Move ${s['name']} to inactive records?'
              : 'Send a removal request for ${s['name']} to the Principal?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (_isPrincipal) {
        await BackendApiClient.instance.deleteStudent(
          (s['id'] ?? '').toString(),
        );
      } else {
        await _requestStudentApproval(
          action: 'delete',
          studentId: (s['id'] ?? '').toString(),
          student: _studentPayloadFromRecord(s),
        );
      }
      await _refreshFromBackend();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isPrincipal
                  ? '${s['name']} removed'
                  : '${s['name']} removal sent for approval',
            ),
            backgroundColor: _isPrincipal ? AppTheme.error : AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _openAddStudentPage() async {
    final result = await Navigator.of(context).push<_StudentActionResult>(
      MaterialPageRoute(
        builder: (_) => _StudentFormPage(
          isPrincipal: _isPrincipal,
          sectionOptions: _sectionOptions,
          parentOptions: _parentOptions,
          defaultSectionId: _defaultSectionId,
          onSubmit: (values) async {
            final payload = _studentPayloadFromForm(
              name: values.name,
              admissionNumber: values.admissionNumber,
              studentCode: values.studentCode,
              dateOfBirth: values.dateOfBirth,
              gender: values.gender,
              sectionId: values.sectionId,
              status: 'active',
            );
            if (_isPrincipal) {
              final created = await BackendApiClient.instance.createStudent(
                firstName: payload['first_name']!,
                lastName: payload['last_name']!,
                dateOfBirth: payload['date_of_birth']!,
                gender: payload['gender']!,
                admissionNumber: payload['admission_number'] ?? '',
                studentCode: payload['student_code'] ?? '',
                currentSectionId: payload['current_section_id'],
                status: 'active',
              );
              await BackendApiClient.instance.setStudentParent(
                studentId: created.id,
                parentUserId: values.parentUserId,
              );
            } else {
              await _requestStudentApproval(
                action: 'create',
                student: payload,
                parentUserId: values.parentUserId,
              );
            }
            await _refreshFromBackend();
            return _isPrincipal
                ? 'Student ${values.name.trim()} added successfully'
                : 'Student ${values.name.trim()} sent for approval';
          },
        ),
      ),
    );
    _showActionResult(result);
  }

  Future<void> _openEditStudentPage(Map<String, dynamic> s) async {
    final result = await Navigator.of(context).push<_StudentActionResult>(
      MaterialPageRoute(
        builder: (_) => _StudentFormPage(
          isPrincipal: _isPrincipal,
          student: s,
          sectionOptions: _sectionOptions,
          parentOptions: _parentOptions,
          defaultSectionId: _defaultSectionId,
          onSubmit: (values) async {
            final payload = _studentPayloadFromForm(
              name: values.name,
              admissionNumber: values.admissionNumber,
              studentCode: values.studentCode,
              dateOfBirth: values.dateOfBirth.trim().isEmpty
                  ? '2010-01-01'
                  : values.dateOfBirth,
              gender: values.gender,
              sectionId: values.sectionId,
              status: s['status']?.toString() ?? 'active',
            );
            if (_isPrincipal) {
              await BackendApiClient.instance.updateStudent(
                (s['id'] ?? '').toString(),
                firstName: payload['first_name']!,
                lastName: payload['last_name']!,
                dateOfBirth: payload['date_of_birth']!,
                gender: payload['gender']!,
                admissionNumber: payload['admission_number'] ?? '',
                studentCode: payload['student_code'] ?? '',
                currentSectionId: payload['current_section_id'],
                status: payload['status'] ?? 'active',
              );
              await BackendApiClient.instance.setStudentParent(
                studentId: (s['id'] ?? '').toString(),
                parentUserId: values.parentUserId,
              );
            } else {
              await _requestStudentApproval(
                action: 'update',
                studentId: (s['id'] ?? '').toString(),
                student: payload,
                parentUserId: values.parentUserId,
              );
            }
            await _refreshFromBackend();
            return _isPrincipal
                ? 'Student updated'
                : 'Student update sent for approval';
          },
        ),
      ),
    );
    _showActionResult(result);
  }

  Future<void> _openDocumentUploadPage(Map<String, dynamic> s) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => _StudentDocumentUploadPage(student: s)),
    );
  }

  void _showTransferDialog(BuildContext context, Map<String, dynamic> s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          _isPrincipal ? 'Transfer Student' : 'Request Student Transfer',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          _isPrincipal
              ? 'Initiate transfer process for ${s['name']}?\nThis will generate a Transfer Certificate.'
              : 'Send a transfer request for ${s['name']} to the Principal?',
          style: GoogleFonts.dmSans(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _saveStudentRecord(s, status: 'transfer');
              await _refreshFromBackend();
              if (mounted) Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _isPrincipal
                          ? 'Transfer initiated for ${s['name']}'
                          : 'Transfer request sent for ${s['name']}',
                    ),
                    backgroundColor: _isPrincipal
                        ? AppTheme.warning
                        : AppTheme.success,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
            child: Text(_isPrincipal ? 'Initiate Transfer' : 'Send Request'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPromoteStudentPage(Map<String, dynamic> s) async {
    final result = await Navigator.of(context).push<_StudentActionResult>(
      MaterialPageRoute(
        builder: (_) => _StudentPromotePage(
          isPrincipal: _isPrincipal,
          student: s,
          sectionOptions: _sectionOptions,
          defaultSectionId: _defaultSectionId,
          onSubmit: (sectionId) async {
            await _saveStudentRecord(s, sectionId: sectionId, status: 'active');
            await _refreshFromBackend();
            return _isPrincipal
                ? '${s['name']} promoted successfully'
                : 'Promotion request sent for ${s['name']}';
          },
        ),
      ),
    );
    _showActionResult(result);
  }

  void _showActionResult(_StudentActionResult? result) {
    if (!mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  void _showTCDialog(BuildContext context, Map<String, dynamic> s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          _isPrincipal ? 'Issue Transfer Certificate' : 'Request TC',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          _isPrincipal
              ? 'Generate TC for ${s['name']} (${s['class']})?'
              : 'Send a TC request for ${s['name']} (${s['class']})?',
          style: GoogleFonts.dmSans(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _saveStudentRecord(s, status: 'transfer');
              await _refreshFromBackend();
              if (mounted) Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _isPrincipal
                          ? 'TC workflow started for ${s['name']}'
                          : 'TC request sent for ${s['name']}',
                    ),
                    backgroundColor: AppTheme.success,
                  ),
                );
              }
            },
            child: Text(_isPrincipal ? 'Generate TC' : 'Send Request'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveStudentRecord(
    Map<String, dynamic> s, {
    String? sectionId,
    String? status,
  }) async {
    final payload = _studentPayloadFromRecord(
      s,
      sectionId: sectionId,
      status: status,
    );
    if (_isPrincipal) {
      await BackendApiClient.instance.updateStudent(
        (s['id'] ?? '').toString(),
        firstName: payload['first_name']!,
        lastName: payload['last_name']!,
        dateOfBirth: payload['date_of_birth']!,
        gender: payload['gender']!,
        admissionNumber: payload['admission_number'],
        studentCode: payload['student_code'],
        currentSectionId: payload['current_section_id'],
        status: payload['status'] ?? 'active',
      );
      return;
    }
    await _requestStudentApproval(
      action: 'update',
      studentId: (s['id'] ?? '').toString(),
      student: payload,
      parentUserId: s['parentId']?.toString() ?? '',
    );
  }

  Map<String, String> _studentPayloadFromForm({
    required String name,
    required String admissionNumber,
    required String studentCode,
    required String dateOfBirth,
    required String gender,
    required String? sectionId,
    required String status,
  }) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final firstName = parts.isEmpty || parts.first.isEmpty
        ? 'Student'
        : parts.first;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '.';
    final cleanSectionId = sectionId?.trim() ?? '';
    return {
      'first_name': firstName,
      'last_name': lastName,
      'date_of_birth': dateOfBirth.trim().isEmpty
          ? '2010-01-01'
          : dateOfBirth.trim(),
      'gender': gender.trim().isEmpty ? 'male' : gender.trim(),
      'admission_number': admissionNumber.trim(),
      'student_code': studentCode.trim(),
      'current_section_id': cleanSectionId,
      'class_label': _classLabelForSection(cleanSectionId),
      'admission_date': '2026-01-01',
      'status': status,
    };
  }

  Map<String, String> _studentPayloadFromRecord(
    Map<String, dynamic> s, {
    String? sectionId,
    String? status,
  }) {
    return _studentPayloadFromForm(
      name: (s['name'] ?? '').toString(),
      admissionNumber: s['admissionNumber']?.toString() ?? '',
      studentCode: s['studentCode']?.toString() ?? '',
      dateOfBirth: (s['dob']?.toString().isNotEmpty == true)
          ? s['dob'].toString()
          : '2010-01-01',
      gender: (s['gender']?.toString().isNotEmpty == true)
          ? s['gender'].toString()
          : 'male',
      sectionId: sectionId ?? s['sectionId']?.toString(),
      status: status ?? s['status']?.toString() ?? 'active',
    );
  }

  String _classLabelForSection(String sectionId) {
    if (sectionId.isEmpty) return 'Unassigned';
    for (final section in _sectionOptions) {
      if (section['id'] == sectionId) return section['label'] ?? 'Section';
    }
    return 'Unassigned';
  }

  Future<void> _requestStudentApproval({
    required String action,
    String? studentId,
    required Map<String, String> student,
    String? parentUserId,
  }) async {
    await BackendApiClient.instance.createRaw('/student-approvals', {
      'action': action,
      if (studentId != null && studentId.trim().isNotEmpty)
        'student_id': studentId.trim(),
      'student': student,
      'parent_user_id': parentUserId?.trim() ?? '',
    });
  }
}

class _StudentActionResult {
  final String message;

  const _StudentActionResult(this.message);
}

class _StudentFormValues {
  final String name;
  final String admissionNumber;
  final String studentCode;
  final String dateOfBirth;
  final String gender;
  final String? sectionId;
  final String parentUserId;

  const _StudentFormValues({
    required this.name,
    required this.admissionNumber,
    required this.studentCode,
    required this.dateOfBirth,
    required this.gender,
    required this.sectionId,
    required this.parentUserId,
  });
}

class _StudentFormPage extends StatefulWidget {
  final bool isPrincipal;
  final Map<String, dynamic>? student;
  final List<Map<String, String>> sectionOptions;
  final List<Map<String, String>> parentOptions;
  final String? defaultSectionId;
  final Future<String> Function(_StudentFormValues values) onSubmit;

  const _StudentFormPage({
    required this.isPrincipal,
    required this.sectionOptions,
    required this.parentOptions,
    required this.defaultSectionId,
    required this.onSubmit,
    this.student,
  });

  @override
  State<_StudentFormPage> createState() => _StudentFormPageState();
}

class _StudentFormPageState extends State<_StudentFormPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _admissionCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _dobCtrl;
  late String _selectedGender;
  late String? _selectedSectionId;
  late String _selectedParentId;
  bool _saving = false;
  String? _errorText;

  bool get _isEdit => widget.student != null;

  @override
  void initState() {
    super.initState();
    final student = widget.student;
    _nameCtrl = TextEditingController(text: student?['name']?.toString() ?? '');
    _admissionCtrl = TextEditingController(
      text: student?['admissionNumber']?.toString() ?? '',
    );
    _codeCtrl = TextEditingController(
      text: student?['studentCode']?.toString() ?? '',
    );
    _dobCtrl = TextEditingController(
      text: student?['dob']?.toString() ?? '2010-01-01',
    );
    _selectedGender = _normalizeGender(student?['gender']?.toString());
    _selectedSectionId = _normalizeSectionId(
      student?['sectionId']?.toString() ?? widget.defaultSectionId,
    );
    _selectedParentId = _normalizeParentId(student?['parentId']?.toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _admissionCtrl.dispose();
    _codeCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  String _normalizeGender(String? value) {
    const genders = {'male', 'female', 'other'};
    final clean = value?.trim().toLowerCase() ?? '';
    return genders.contains(clean) ? clean : 'male';
  }

  String? _normalizeSectionId(String? value) {
    final clean = value?.trim() ?? '';
    if (clean.isEmpty) return null;
    final exists = widget.sectionOptions.any(
      (section) => section['id'] == clean,
    );
    return exists ? clean : null;
  }

  String _normalizeParentId(String? value) {
    final clean = value?.trim() ?? '';
    if (clean.isEmpty) return '';
    final exists = widget.parentOptions.any((parent) => parent['id'] == clean);
    return exists ? clean : '';
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Student name is required');
      return;
    }
    setState(() {
      _saving = true;
      _errorText = null;
    });
    try {
      final message = await widget.onSubmit(
        _StudentFormValues(
          name: name,
          admissionNumber: _admissionCtrl.text,
          studentCode: _codeCtrl.text,
          dateOfBirth: _dobCtrl.text,
          gender: _selectedGender,
          sectionId: _selectedSectionId,
          parentUserId: _selectedParentId,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(_StudentActionResult(message));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorText = 'Save failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isEdit
        ? widget.isPrincipal
              ? 'Edit Student'
              : 'Request Student Update'
        : widget.isPrincipal
        ? 'Add New Student'
        : 'Request New Student';
    final submitLabel = _saving
        ? 'Saving...'
        : _isEdit
        ? widget.isPrincipal
              ? 'Save'
              : 'Send Request'
        : widget.isPrincipal
        ? 'Add Student'
        : 'Send Request';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _StudentPageHeader(
                    icon: _isEdit
                        ? Icons.edit_note_rounded
                        : Icons.person_add_rounded,
                    title: title,
                    subtitle: widget.isPrincipal
                        ? 'Changes save directly to the student backend.'
                        : 'Changes are submitted to the Principal approval queue.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Student Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSectionId,
                    decoration: const InputDecoration(
                      labelText: 'Class / Section',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.sectionOptions
                        .map(
                          (section) => DropdownMenuItem(
                            value: section['id'],
                            child: Text(section['label'] ?? 'Section'),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _selectedSectionId = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _admissionCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Admission / Roll Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Student Code',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _dobCtrl,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.datetime,
                    decoration: const InputDecoration(
                      labelText: 'Date of Birth (YYYY-MM-DD)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedGender,
                    decoration: const InputDecoration(
                      labelText: 'Gender',
                      border: OutlineInputBorder(),
                    ),
                    items: const ['male', 'female', 'other'].map((gender) {
                      return DropdownMenuItem(
                        value: gender,
                        child: Text(gender),
                      );
                    }).toList(),
                    onChanged: _saving
                        ? null
                        : (value) =>
                              setState(() => _selectedGender = value ?? 'male'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedParentId,
                    decoration: InputDecoration(
                      labelText: 'Linked Parent Account',
                      helperText: _isEdit
                          ? 'Select no parent to unlink this student.'
                          : 'Optional. Parent will see this student after assignment.',
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('No linked parent'),
                      ),
                      ...widget.parentOptions.map(
                        (parent) => DropdownMenuItem(
                          value: parent['id'],
                          child: Text(parent['label'] ?? 'Parent'),
                        ),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) =>
                              setState(() => _selectedParentId = value ?? ''),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorText!,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppTheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _StudentPageActions(
              saving: _saving,
              submitLabel: submitLabel,
              onCancel: () => Navigator.of(context).pop(),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentPromotePage extends StatefulWidget {
  final bool isPrincipal;
  final Map<String, dynamic> student;
  final List<Map<String, String>> sectionOptions;
  final String? defaultSectionId;
  final Future<String> Function(String? sectionId) onSubmit;

  const _StudentPromotePage({
    required this.isPrincipal,
    required this.student,
    required this.sectionOptions,
    required this.defaultSectionId,
    required this.onSubmit,
  });

  @override
  State<_StudentPromotePage> createState() => _StudentPromotePageState();
}

class _StudentPromotePageState extends State<_StudentPromotePage> {
  String? _selectedSectionId;
  bool _saving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _selectedSectionId = _normalizeSectionId(
      widget.student['sectionId']?.toString() ?? widget.defaultSectionId,
    );
  }

  String? _normalizeSectionId(String? value) {
    final clean = value?.trim() ?? '';
    if (clean.isEmpty) return null;
    final exists = widget.sectionOptions.any(
      (section) => section['id'] == clean,
    );
    return exists ? clean : null;
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _errorText = null;
    });
    try {
      final message = await widget.onSubmit(_selectedSectionId);
      if (!mounted) return;
      Navigator.of(context).pop(_StudentActionResult(message));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorText = 'Promotion failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isPrincipal ? 'Promote Student' : 'Request Promotion';
    final submitLabel = _saving
        ? 'Saving...'
        : widget.isPrincipal
        ? 'Promote'
        : 'Send Request';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _StudentPageHeader(
                    icon: Icons.trending_up_rounded,
                    title: title,
                    subtitle:
                        '${widget.student['name']} - ${widget.student['class']}',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSectionId,
                    decoration: const InputDecoration(
                      labelText: 'New Class / Section',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.sectionOptions
                        .map(
                          (section) => DropdownMenuItem(
                            value: section['id'],
                            child: Text(section['label'] ?? 'Section'),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _selectedSectionId = value),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorText!,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppTheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _StudentPageActions(
              saving: _saving,
              submitLabel: submitLabel,
              onCancel: () => Navigator.of(context).pop(),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentDocumentUploadPage extends StatelessWidget {
  final Map<String, dynamic> student;

  const _StudentDocumentUploadPage({required this.student});

  static const List<String> _documents = [
    'Aadhaar Card',
    'Birth Certificate',
    'TC',
    'Mark Sheet',
    'Medical Certificate',
  ];

  @override
  Widget build(BuildContext context) {
    final uploadedDocs = (student['docs'] as List?) ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Documents')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StudentPageHeader(
              icon: Icons.upload_file_rounded,
              title: 'Upload Documents',
              subtitle: '${student['name']} - ${student['class']}',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.warningContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warning),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.warning,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Student document upload is not connected to production file storage yet. This page blocks local-only uploads until a real file picker, storage URL, and /student-documents save path are wired.',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ..._documents.map((document) {
              final uploaded = uploadedDocs.contains(document);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    leading: Icon(
                      uploaded
                          ? Icons.check_circle_rounded
                          : Icons.upload_file_rounded,
                      color: uploaded ? AppTheme.success : AppTheme.muted,
                    ),
                    title: Text(
                      document,
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      uploaded
                          ? 'Already recorded'
                          : 'Upload blocked until backend file storage is implemented',
                      style: GoogleFonts.dmSans(fontSize: 12),
                    ),
                    trailing: uploaded
                        ? const Icon(
                            Icons.verified_rounded,
                            color: AppTheme.success,
                          )
                        : FilledButton.icon(
                            onPressed: null,
                            icon: const Icon(
                              Icons.lock_outline_rounded,
                              size: 18,
                            ),
                            label: const Text('Blocked'),
                          ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _StudentPageHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _StudentPageHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primaryContainer,
            foregroundColor: AppTheme.primary,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentPageActions extends StatelessWidget {
  final bool saving;
  final String submitLabel;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  const _StudentPageActions({
    required this.saving,
    required this.submitLabel,
    required this.onCancel,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.outline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: saving ? null : onCancel,
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: saving ? null : onSubmit,
              child: Text(submitLabel),
            ),
          ),
        ],
      ),
    );
  }
}
