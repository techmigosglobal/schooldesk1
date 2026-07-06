import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

class AdminTeachersScreen extends StatefulWidget {
  const AdminTeachersScreen({super.key});

  @override
  State<AdminTeachersScreen> createState() => _AdminTeachersScreenState();
}

class _AdminTeachersScreenState extends State<AdminTeachersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _search = '';

  List<Map<String, dynamic>> _teachers = [];
  List<Map<String, dynamic>> _leaveRequests = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final api = BackendApiClient.instance;
      final staff = await api.getStaff(page: 1, pageSize: 100);
      final leaves = await api.getLeaveApplications();
      if (!mounted) return;
      setState(() {
        _teachers = staff.data
            .map(
              (s) => {
                'id': s.id,
                'name': '${s.firstName} ${s.lastName}'.trim(),
                'subject': s.designation ?? 'Teacher',
                'email': s.email ?? '',
                'phone': s.phone ?? '',
                'status': s.status ?? 'active',
                'dept': s.departmentName ?? s.designation ?? '',
              },
            )
            .toList();
        _leaveRequests = leaves
            .map(
              (l) => {
                'id': l.id,
                'teacher': l.staffName.isNotEmpty ? l.staffName : l.staffId,
                'type': l.leaveTypeName.isNotEmpty
                    ? l.leaveTypeName
                    : l.leaveTypeId,
                'from': l.fromDate.split('T').first,
                'to': l.toDate.split('T').first,
                'reason': l.reason ?? '',
                'status': l.status,
                'totalDays': l.totalDays,
              },
            )
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _teachers = [];
        _leaveRequests = [];
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered => _teachers
      .where(
        (t) =>
            t['name'].toString().toLowerCase().contains(
              _search.toLowerCase(),
            ) ||
            t['subject'].toString().toLowerCase().contains(
              _search.toLowerCase(),
            ),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appTheme.background,
      floatingActionButton: const DashboardFabWidget(role: DashboardRole.principal),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      appBar: AppBar(
        backgroundColor: context.appTheme.surface,
        title: Text(
          'Staff',
          style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            onPressed: _openAddTeacherPage,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 12),
          tabs: const [
            Tab(text: 'Teachers'),
            Tab(text: 'Leave Records'),
            Tab(text: 'Payroll'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            color: context.appTheme.surface,
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                hintText: 'Search teachers...',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTeacherList(),
                _buildLeaveRecords(),
                _buildPayroll(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherList() {
    return Semantics(
      label: '${_filtered.length} teachers list',
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _filtered.length,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        itemBuilder: (_, i) {
          if (i > 0) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                _buildTeacherCard(_filtered[i]),
              ],
            );
          }
          return _buildTeacherCard(_filtered[i]);
        },
      ),
    );
  }

  Widget _buildTeacherCard(Map<String, dynamic> t) {
    final isOnLeave = t['status'] == 'On Leave';
    return Semantics(
      label: 'Teacher ${t['name']}, ${t['subject']}, status ${t['status']}',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.appTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOnLeave
                ? context.appTheme.warningContainer
                : context.appTheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Semantics(
              label: 'Avatar for ${t['name']}',
              child: CircleAvatar(
                radius: 22,
                backgroundColor: isOnLeave
                    ? context.appTheme.warningContainer
                    : context.appTheme.primaryContainer,
                child: Text(
                  t['name'].toString().split(' ').last.substring(0, 1),
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isOnLeave ? context.appTheme.warning : context.appTheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t['name'] as String,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Semantics(
                        label: 'Status: ${t['status']}',
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isOnLeave
                                ? context.appTheme.warningContainer
                                : context.appTheme.successContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            t['status'] as String,
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isOnLeave
                                  ? context.appTheme.warning
                                  : context.appTheme.success,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${t['subject']}${(t['dept'] ?? '').toString().isNotEmpty ? ' • ${t['dept']}' : ''}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: context.appTheme.muted,
                    ),
                  ),
                  Text(
                    '${t['phone'] ?? ''}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: context.appTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              label: 'More actions for ${t['name']}',
              child: PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: context.appTheme.muted,
                ),
                onSelected: (v) => _handleTeacherAction(context, v, t),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Edit Profile'),
                  ),
                  const PopupMenuItem(
                    value: 'subjects',
                    child: Text('Assign Subjects'),
                  ),
                  const PopupMenuItem(
                    value: 'leave',
                    child: Text('Apply Leave'),
                  ),
                  const PopupMenuItem(
                    value: 'docs',
                    child: Text('Staff Documents'),
                  ),
                  const PopupMenuItem(
                    value: 'salary',
                    child: Text('View Salary'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveRecords() {
    return Semantics(
      label: '${_leaveRequests.length} leave records',
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _leaveRequests.length,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        itemBuilder: (_, i) {
          final l = _leaveRequests[i];
          final isPending = '${l['status']}' == 'pending';
          final item = Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.appTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.appTheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${l['teacher']}',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Semantics(
                      label: 'Leave status: ${l['status']}',
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isPending
                              ? context.appTheme.warningContainer
                              : context.appTheme.successContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),                          child: Text(
                          _titleCase(l['status']?.toString() ?? ''),
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isPending
                                ? context.appTheme.warning
                                : context.appTheme.success,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${l['from'] ?? ''} – ${l['to'] ?? ''}${(l['reason'] ?? '').toString().isNotEmpty ? ' • Reason: ${l['reason']}' : ''}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: context.appTheme.muted,
                  ),
                ),
                if (isPending) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          label: 'Reject leave for ${l['teacher']}',
                          child: OutlinedButton(
                            onPressed: () {
                              _decideLeave(l, 'rejected');
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: context.appTheme.error,
                              side: BorderSide(color: context.appTheme.error),
                            ),
                            child: const Text(
                              'Reject',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Semantics(
                          label: 'Approve leave for ${l['teacher']}',
                          child: ElevatedButton(
                            onPressed: () {
                              _decideLeave(l, 'approved');
                            },
                            child: const Text(
                              'Approve',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
          return i > 0
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [const SizedBox(height: 8), item],
                )
              : item;
        },
      ),
    );
  }

  Widget _buildPayroll() {
    return Semantics(
      label: '${_teachers.length} payroll records',
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _teachers.length,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        itemBuilder: (_, i) {
          final t = _teachers[i];
          final item = Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.appTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.appTheme.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t['name'] as String,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${t['subject']} • ${t['id']}',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: context.appTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${t['salary'] ?? '-'}',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.appTheme.success,
                      ),
                    ),
                    Text(
                      'per month',
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        color: context.appTheme.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Semantics(
                  label: 'Generate salary slip for ${t['name']}',
                  child: ElevatedButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Salary slip generated for ${t['name']}'),
                        backgroundColor: context.appTheme.success,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                    ),
                    child: Text(
                      'Slip',
                      style: GoogleFonts.dmSans(fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          );
          return i > 0
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [const SizedBox(height: 8), item],
                )
              : item;
        },
      ),
    );
  }

  void _handleTeacherAction(
    BuildContext context,
    String action,
    Map<String, dynamic> t,
  ) {
    switch (action) {
      case 'edit':
        _openEditTeacherPage(t);
        break;
      case 'subjects':
        _openSubjectAssignPage(t);
        break;
      case 'salary':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Salary info not available for ${t['name']}')),
        );
        break;
      default:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$action for ${t['name']}')));
        break;
    }
  }

  Future<void> _openAddTeacherPage() async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => _TeacherFormPage(
          onSubmit: (values) async {
            final parts = _splitTeacherName(values.name);
            await BackendApiClient.instance.createStaff(
              firstName: parts.first,
              lastName: parts.last,
              designation: values.subject.isEmpty ? 'Teacher' : values.subject,
            );
            await _loadData();
            return '${values.name} added';
          },
        ),
      ),
    );
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: context.appTheme.success),
    );
  }

  Future<void> _openEditTeacherPage(Map<String, dynamic> t) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => _TeacherFormPage(
          teacher: t,
          onSubmit: (values) async {
            final parts = _splitTeacherName(values.name);
            await BackendApiClient.instance.updateStaff(
              (t['id'] ?? '').toString(),
              firstName: parts.first,
              lastName: parts.last,
              designation: values.subject.isEmpty ? 'Teacher' : values.subject,
              phone: t['phone']?.toString(),
            );
            await _loadData();
            return 'Teacher updated';
          },
        ),
      ),
    );
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: context.appTheme.success),
    );
  }

  Future<void> _openSubjectAssignPage(Map<String, dynamic> t) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => _TeacherSubjectPage(
          teacher: t,
          onSubmit: (selected) async {
            final parts = _splitTeacherName((t['name'] ?? '').toString());
            await BackendApiClient.instance.updateStaff(
              (t['id'] ?? '').toString(),
              firstName: parts.first,
              lastName: parts.last,
              designation: selected,
              phone: t['phone']?.toString(),
            );
            await _loadData();
            return 'Subject updated to $selected';
          },
        ),
      ),
    );
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: context.appTheme.success),
    );
  }

  static String _titleCase(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  _TeacherNameParts _splitTeacherName(String name) {
    final trimmed = name.trim();
    final parts = trimmed.isEmpty ? ['Teacher'] : trimmed.split(RegExp(r'\s+'));
    return _TeacherNameParts(
      first: parts.first,
      last: parts.length > 1 ? parts.sublist(1).join(' ') : '.',
    );
  }

  Future<void> _decideLeave(Map<String, dynamic> leave, String status) async {
    try {
      await BackendApiClient.instance.decideLeaveApplication(
        (leave['id'] ?? '').toString(),
        status: status,
      );
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved' ? 'Leave approved' : 'Leave rejected',
          ),
          backgroundColor: status == 'approved'
              ? context.appTheme.success
              : context.appTheme.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: context.appTheme.error),
      );
    }
  }
}

class _TeacherNameParts {
  final String first;
  final String last;

  const _TeacherNameParts({required this.first, required this.last});
}

class _TeacherFormValues {
  final String name;
  final String subject;

  const _TeacherFormValues({required this.name, required this.subject});
}

class _TeacherFormPage extends StatefulWidget {
  final Map<String, dynamic>? teacher;
  final Future<String> Function(_TeacherFormValues values) onSubmit;

  const _TeacherFormPage({this.teacher, required this.onSubmit});

  @override
  State<_TeacherFormPage> createState() => _TeacherFormPageState();
}

class _TeacherFormPageState extends State<_TeacherFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _subjectCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: widget.teacher?['name']?.toString() ?? '',
    );
    _subjectCtrl = TextEditingController(
      text: widget.teacher?['subject']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _subjectCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final message = await widget.onSubmit(
        _TeacherFormValues(
          name: _nameCtrl.text.trim(),
          subject: _subjectCtrl.text.trim(),
        ),
      );
      if (mounted) Navigator.pop(context, message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Teacher save failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.teacher != null;
    return Scaffold(
      backgroundColor: context.appTheme.background,
      appBar: AppBar(
        title: Text(
          editing ? 'Edit Teacher' : 'Add New Teacher',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: context.appTheme.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Teacher Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final name = value?.trim() ?? '';
                  if (name.isEmpty) return 'Enter teacher name';
                  if (name.length < 3) return 'Enter a valid teacher name';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subjectCtrl,
                decoration: const InputDecoration(
                  labelText: 'Subject / Designation',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _TeacherInlineError(message: _error!),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(editing ? Icons.save_rounded : Icons.add_rounded),
                label: Text(
                  _saving
                      ? 'Saving...'
                      : editing
                      ? 'Save'
                      : 'Add',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: context.appTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeacherSubjectPage extends StatefulWidget {
  final Map<String, dynamic> teacher;
  final Future<String> Function(String subject) onSubmit;

  const _TeacherSubjectPage({required this.teacher, required this.onSubmit});

  @override
  State<_TeacherSubjectPage> createState() => _TeacherSubjectPageState();
}

class _TeacherSubjectPageState extends State<_TeacherSubjectPage> {
  static const _subjects = [
    'Mathematics',
    'Science',
    'English',
    'Hindi',
    'Social Studies',
    'Computer',
    'Art',
    'PE',
  ];

  late String _selected;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final current = widget.teacher['subject']?.toString() ?? '';
    _selected = _subjects.contains(current) ? current : _subjects.first;
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final message = await widget.onSubmit(_selected);
      if (mounted) Navigator.pop(context, message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Subject update failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final teacherName = widget.teacher['name']?.toString() ?? 'Teacher';
    return Scaffold(
      backgroundColor: context.appTheme.background,
      appBar: AppBar(
        title: Text(
          'Assign Subject',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: context.appTheme.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              teacherName,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ..._subjects.map(
              (subject) => RadioListTile<String>(
                title: Text(subject, style: GoogleFonts.dmSans(fontSize: 13)),
                value: subject,
                groupValue: _selected,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _selected = value!),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _TeacherInlineError(message: _error!),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.assignment_ind_rounded),
              label: Text(_saving ? 'Assigning...' : 'Assign'),
              style: FilledButton.styleFrom(backgroundColor: context.appTheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherInlineError extends StatelessWidget {
  final String message;

  const _TeacherInlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appTheme.error.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appTheme.error.withAlpha(80)),
      ),
      child: Text(
        message,
        style: GoogleFonts.dmSans(fontSize: 13, color: context.appTheme.error),
      ),
    );
  }
}
