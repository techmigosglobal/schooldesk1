import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/services/parent_child_selection_service.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/utils/attachment_url_resolver.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/features/homework/presentation/screens/parent_homework_screen/parent_homework_submission_screen.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:url_launcher/url_launcher.dart';

class ParentHomeworkScreen extends StatefulWidget {
  const ParentHomeworkScreen({super.key});

  @override
  State<ParentHomeworkScreen> createState() => _ParentHomeworkScreenState();
}

class _ParentHomeworkScreenState extends State<ParentHomeworkScreen>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = ParentNav.homework;
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
      final selectedIndex = await ParentChildSelectionService.indexFor(
        children,
        fallback: _activeChildIndex,
      );
      if (!mounted) return;
      setState(() {
        _children = children;
        _activeChildIndex = selectedIndex;
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
    final dueDate = DateTime.tryParse(
      '${h['due_date'] ?? h['submission_date'] ?? ''}',
    );
    final status = '${h['status'] ?? 'pending'}'.toLowerCase();
    final submissionStatus = _text(h['submission_status']).toLowerCase();
    // Backend integration: subject and teacher labels should come from the
    // homework API. Keep them empty here when absent; do not invent defaults.
    return {
      'id': h['id'] ?? h['homework_id'],
      'title': h['title'] ?? '',
      'subject': h['subject'] ?? h['subject_name'] ?? '',
      'class': h['class'] ?? h['class_name'] ?? '',
      'deadline': dueDate == null
          ? '${h['deadline'] ?? h['submission_date'] ?? ''}'
          : '${dueDate.day}/${dueDate.month}/${dueDate.year}',
      'instructions': h['description'] ?? h['instructions'] ?? '',
      'teacher':
          h['teacher_name'] ?? h['created_by_name'] ?? h['created_by'] ?? '',
      'status': status == 'submitted' ||
              status == 'completed' ||
              submissionStatus == 'submitted' ||
              submissionStatus == 'approved' ||
              submissionStatus == 'reviewed'
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
                RefreshIndicator(
                  onRefresh: _loadData,
                  child: _buildHomeworkList(_pending),
                ),
                RefreshIndicator(
                  onRefresh: _loadData,
                  child: _buildHomeworkList(_submitted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildSelector() {
    return Container(
      color: context.appTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: List.generate(_children.length, (i) {
          final isActive = i == _activeChildIndex;
          return GestureDetector(
            onTap: () {
              setState(() => _activeChildIndex = i);
              ParentChildSelectionService.saveIndex(_children, i);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? _headerColor
                    : context.appTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_children[i]['name'] ?? _children[i]['first_name'] ?? 'Student'}'
                    .split(' ')
                    .first,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : context.appTheme.onSurface,
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
      color: context.appTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          _summaryChip(
            '${_pending.length} Pending',
            context.appTheme.warning,
            context.appTheme.warningContainer,
          ),
          const SizedBox(width: 8),
          _summaryChip(
            '${_submitted.length} Submitted',
            context.appTheme.success,
            context.appTheme.successContainer,
          ),
          const SizedBox(width: 8),
          _summaryChip(
            '${_homework.length} Total',
            context.appTheme.primary,
            context.appTheme.primaryContainer,
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
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 320,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_turned_in_rounded,
                    size: 48,
                    color: context.appTheme.muted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No homework published',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: context.appTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (_, i) => _homeworkCard(list[i]),
    );
  }

  Widget _homeworkCard(Map<String, dynamic> hw) {
    final isPending = hw['status'] == 'pending';
    final isUrgent = hw['urgent'] == true;
    final title = _text(
      hw['title'],
      fallback: 'Homework details not published',
    );
    final subject = _text(hw['subject']);
    final deadline = _text(hw['deadline']);
    final teacher = _text(hw['teacher']);
    final instructions = _text(hw['instructions']);
    final subtitleParts = <String>[
      if (subject.isNotEmpty) subject,
      if (deadline.isNotEmpty) 'Due: $deadline',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUrgent
              ? context.appTheme.warning.withAlpha(100)
              : context.appTheme.outlineVariant,
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
                ? context.appTheme.warningContainer
                : context.appTheme.successContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isPending
                ? Icons.assignment_late_rounded
                : Icons.assignment_turned_in_rounded,
            color: isPending
                ? context.appTheme.warning
                : context.appTheme.success,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
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
                  color: context.appTheme.warningContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Urgent',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: context.appTheme.warning,
                  ),
                ),
              ),
          ],
        ),
        subtitle: subtitleParts.isEmpty
            ? null
            : Text(
                subtitleParts.join(' • '),
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: context.appTheme.muted,
                ),
              ),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          if (teacher.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 14,
                  color: context.appTheme.muted,
                ),
                const SizedBox(width: 4),
                Text(
                  'Teacher: $teacher',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: context.appTheme.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (instructions.isNotEmpty) ...[
            Text(
              'Instructions:',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              instructions,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: context.appTheme.onSurfaceVariant,
              ),
            ),
          ],
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
                color: context.appTheme.onSurfaceVariant,
              ),
            ),
          ],
          if (hw['hasAttachment'] == true) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _openAttachment(hw),
              icon: const Icon(Icons.attach_file_rounded, size: 14),
              label: Text(
                'Open Attachment',
                style: GoogleFonts.dmSans(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                side: BorderSide(color: context.appTheme.primary),
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
        ? context.appTheme.success
        : status == 'needs_revision'
        ? context.appTheme.warning
        : context.appTheme.primary;
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
      ).toLowerCase();
      return {
        ...row,
        'submission_id': _text(submission['id']),
        'submission_status': submissionStatus,
        'submission_remarks': _text(submission['remarks']),
        'status': submissionStatus == 'needs_revision' ||
                submissionStatus == 'revision_requested'
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
          backgroundColor: context.appTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadData();
    }
  }

  Future<void> _openAttachment(Map<String, dynamic> homework) async {
    final attachment = _text(
      homework['attachment_url'] ?? homework['attachmentUrl'],
    );
    final uri = resolveAttachmentUrl(attachment);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attachment is not available.')),
      );
      return;
    }
    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open attachment.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open attachment: $e'),
          backgroundColor: context.appTheme.error,
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
