import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/parent_navigation.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_module_scaffold.dart';
import '../../services/backend_api_client.dart';
import '../../routes/app_routes.dart';
import 'parent_homework_submission_screen.dart';

class ParentHomeworkScreen extends StatefulWidget {
  const ParentHomeworkScreen({super.key});

  @override
  State<ParentHomeworkScreen> createState() => _ParentHomeworkScreenState();
}

class _ParentHomeworkScreenState extends State<ParentHomeworkScreen>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = 3;
  late TabController _tabController;
  int _activeChildIndex = 0;
  static const _headerColor = Color(0xFF1A6B4A);

  List<Map<String, dynamic>> _children = [];

  List<Map<String, dynamic>> _homework = [];
  bool _loading = true;
  String? _error;

  String? get _activeStudentId => _children.isEmpty
      ? null
      : (_children[_activeChildIndex]['id'] ?? '').toString();

  List<Map<String, dynamic>> get _pending => _homework
      .where(
        (h) =>
            h['status'] == 'pending' &&
            h['student_id'].toString() == _activeStudentId,
      )
      .toList();
  List<Map<String, dynamic>> get _submitted => _homework
      .where(
        (h) =>
            h['status'] == 'submitted' &&
            h['student_id'].toString() == _activeStudentId,
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _loadData();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final children = await BackendApiClient.instance.getMyStudents();
      final rows = <Map<String, dynamic>>[];
      for (final child in children) {
        final studentId = (child['id'] ?? '').toString();
        if (studentId.isEmpty) continue;
        final childRows = await BackendApiClient.instance.getHomework(
          studentId: studentId,
        );
        for (final row in childRows) {
          final mapped = await _attachSubmissionState({
            ...row,
            'student_id': studentId,
          });
          rows.add(mapped);
        }
      }
      if (!mounted) return;
      setState(() {
        _children = children;
        if (_activeChildIndex >= _children.length) _activeChildIndex = 0;
        _homework = rows.map(_mapHomeworkFromApi).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load homework from the server.';
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _mapHomeworkFromApi(Map<String, dynamic> h) {
    final dueDate = DateTime.tryParse('${h['due_date'] ?? ''}');
    final status = '${h['status'] ?? 'pending'}'.toLowerCase();
    return {
      'id': h['id'],
      'title': h['title'] ?? '',
      'subject': h['subject'] ?? 'General',
      'class': h['class'] ?? h['class_name'] ?? '',
      'deadline': dueDate == null
          ? '${h['deadline'] ?? ''}'
          : '${dueDate.day}/${dueDate.month}/${dueDate.year}',
      'instructions': h['description'] ?? h['instructions'] ?? '',
      'teacher': h['teacher_name'] ?? h['created_by'] ?? 'Teacher',
      'status': status == 'submitted' || status == 'completed'
          ? 'submitted'
          : 'pending',
      'student_id': h['student_id'] ?? '',
      'submission_id': h['submission_id'] ?? '',
      'submission_status': h['submission_status'] ?? '',
      'submission_remarks': h['submission_remarks'] ?? '',
      'urgent':
          dueDate != null && dueDate.difference(DateTime.now()).inDays <= 1,
      'attachmentUrl': h['attachment_url'] ?? h['attachmentUrl'],
      'hasAttachment':
          '${h['attachment_url'] ?? h['attachmentUrl'] ?? ''}'.isNotEmpty,
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drawer = ParentDrawer(
      selectedIndex: _selectedNavIndex,
      onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
    );
    if (_loading) {
      return SchoolDeskModuleScaffold(
        title: 'Homework & Assignments',
        subtitle: 'Track pending and submitted work for linked children',
        drawer: drawer,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SchoolDeskModuleScaffold(
        title: 'Homework & Assignments',
        subtitle: 'Track pending and submitted work for linked children',
        drawer: drawer,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_children.isEmpty) {
      return SchoolDeskModuleScaffold(
        title: 'Homework & Assignments',
        subtitle: 'Track pending and submitted work for linked children',
        drawer: drawer,
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No linked students. Ask the school admin to link students to this parent account.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return SchoolDeskModuleScaffold(
      title: 'Homework & Assignments',
      subtitle: 'Track pending and submitted work for linked children',
      drawer: drawer,
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottom: TabBar(
        controller: _tabController,
        tabs: [
          Tab(text: 'Pending (${_pending.length})'),
          Tab(text: 'Submitted (${_submitted.length})'),
        ],
      ),
      body: Column(
        children: [
          _buildChildSelector(),
          _buildSummaryBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHomeworkList(_pending),
                _buildHomeworkList(_submitted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildSelector() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: List.generate(_children.length, (i) {
          final isActive = i == _activeChildIndex;
          return GestureDetector(
            onTap: () => setState(() => _activeChildIndex = i),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? _headerColor : AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_children[i]['name'] ?? _children[i]['first_name'] ?? 'Student'}'
                    .split(' ')
                    .first,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : AppTheme.onSurface,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _summaryChip(
            '${_pending.length} Pending',
            AppTheme.warning,
            AppTheme.warningContainer,
          ),
          const SizedBox(width: 8),
          _summaryChip(
            '${_submitted.length} Submitted',
            AppTheme.success,
            AppTheme.successContainer,
          ),
          const SizedBox(width: 8),
          _summaryChip(
            '${_homework.length} Total',
            AppTheme.primary,
            AppTheme.primaryContainer,
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, Color color, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildHomeworkList(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.assignment_turned_in_rounded,
              size: 48,
              color: AppTheme.muted,
            ),
            const SizedBox(height: 12),
            Text(
              'No homework here!',
              style: GoogleFonts.dmSans(fontSize: 14, color: AppTheme.muted),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (_, i) => _homeworkCard(list[i]),
    );
  }

  Widget _homeworkCard(Map<String, dynamic> hw) {
    final isPending = hw['status'] == 'pending';
    final isUrgent = hw['urgent'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUrgent
              ? AppTheme.warning.withAlpha(100)
              : AppTheme.outlineVariant,
          width: isUrgent ? 1.5 : 1,
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isPending
                ? AppTheme.warningContainer
                : AppTheme.successContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isPending
                ? Icons.assignment_late_rounded
                : Icons.assignment_turned_in_rounded,
            color: isPending ? AppTheme.warning : AppTheme.success,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                hw['title'],
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isUrgent)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.warningContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Urgent',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warning,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${hw['subject']} • Due: ${hw['deadline']}',
          style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
        ),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 14,
                color: AppTheme.muted,
              ),
              const SizedBox(width: 4),
              Text(
                'Teacher: ${hw['teacher']}',
                style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Instructions:',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hw['instructions'],
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          if ('${hw['submission_status'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 10),
            _submissionStatusChip(hw),
          ],
          if ('${hw['submission_remarks'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Teacher remarks: ${hw['submission_remarks']}',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ],
          if (hw['hasAttachment'] == true) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _requestAttachment(hw),
              icon: const Icon(Icons.attach_file_rounded, size: 14),
              label: Text(
                'Download Worksheet',
                style: GoogleFonts.dmSans(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                side: const BorderSide(color: AppTheme.primary),
              ),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openSubmissionScreen(hw),
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: Text(
                  _text(hw['submission_status']) == 'needs_revision'
                      ? 'Resubmit Homework'
                      : 'Submit Homework',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _submissionStatusChip(Map<String, dynamic> hw) {
    final status = _text(hw['submission_status']);
    final color = status == 'reviewed'
        ? AppTheme.success
        : status == 'needs_revision'
        ? AppTheme.warning
        : AppTheme.primary;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(24),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          status.replaceAll('_', ' '),
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _attachSubmissionState(
    Map<String, dynamic> row,
  ) async {
    final homeworkId = _text(row['id']);
    final studentId = _text(row['student_id']);
    if (homeworkId.isEmpty || studentId.isEmpty) return row;
    try {
      final response = await BackendApiClient.instance.getHomeworkSubmissions(
        homeworkId,
        studentId: studentId,
      );
      final submissions = response['submissions'];
      if (submissions is! List || submissions.isEmpty) return row;
      final submission = Map<String, dynamic>.from(submissions.first as Map);
      final submissionStatus = _text(
        submission['status'],
        fallback: 'submitted',
      );
      return {
        ...row,
        'submission_id': _text(submission['id']),
        'submission_status': submissionStatus,
        'submission_remarks': _text(submission['remarks']),
        'status': submissionStatus == 'needs_revision'
            ? 'pending'
            : 'submitted',
      };
    } catch (_) {
      return row;
    }
  }

  Future<void> _openSubmissionScreen(Map<String, dynamic> homework) async {
    final child = _children[_activeChildIndex];
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.parentHomeworkSubmit,
      arguments: ParentHomeworkSubmissionArgs(
        homework: homework,
        studentId: _text(
          homework['student_id'],
          fallback: _activeStudentId ?? '',
        ),
        studentName: _studentName(child),
      ),
    );
    if (!mounted) return;
    if (result is ParentHomeworkSubmissionResult) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadData();
    }
  }

  Future<void> _requestAttachment(Map<String, dynamic> homework) async {
    try {
      await BackendApiClient.instance.createRaw(
        '/homework/${homework['id']}/attachment-requests',
        {'student_id': _activeStudentId},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attachment request sent to backend')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attachment is not available: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  String _studentName(Map<String, dynamic> child) {
    final name = _text(child['name']);
    if (name.isNotEmpty) return name;
    final combined =
        '${_text(child['first_name'])} ${_text(child['last_name'])}'.trim();
    return combined.isEmpty ? 'Student' : combined;
  }

  String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}
