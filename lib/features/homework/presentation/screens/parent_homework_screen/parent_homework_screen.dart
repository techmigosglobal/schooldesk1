import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/services/parent_child_selection_service.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/features/homework/presentation/screens/parent_homework_screen/parent_homework_submission_screen.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/theme/design_tokens.dart';
import 'package:schooldesk1/core/widgets/school_desk_animations.dart';
import 'package:schooldesk1/core/widgets/event_post_media_preview.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/core/widgets/subject_card_widget.dart';
import 'package:schooldesk1/core/widgets/parent_child_selector.dart';
import 'package:schooldesk1/core/desktop/desktop_responsive_breakpoints.dart';
import 'package:schooldesk1/core/widgets/desktop_screen_wrapper.dart';

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
            (h['status'] == 'pending') &&
            h['student_id'].toString() == _activeStudentId,
      )
      .toList();
  List<Map<String, dynamic>> get _submitted => _homework
      .where(
        (h) =>
            (h['status'] == 'submitted' ||
                h['submission_status']?.toString().isNotEmpty == true) &&
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
      final studentIds = children
          .map((child) => (child['id'] ?? '').toString())
          .where((studentId) => studentId.isNotEmpty)
          .toList();
      // Fetch each child's homework list in parallel instead of sequentially
      // awaiting one child at a time, which previously serialized N network
      // round-trips (one per child).
      final childHomeworkLists = await Future.wait(
        studentIds.map(
          (studentId) =>
              BackendApiClient.instance.getHomework(studentId: studentId),
        ),
      );
      final flatRows = <Map<String, dynamic>>[];
      for (var i = 0; i < studentIds.length; i++) {
        for (final row in childHomeworkLists[i]) {
          flatRows.add({...row, 'student_id': studentIds[i]});
        }
      }
      // Likewise, resolve submission state for every homework row in
      // parallel rather than one request at a time - this was the biggest
      // source of latency on this screen since it previously issued one
      // sequential request per homework item.
      final rows = await Future.wait(flatRows.map(_attachSubmissionState));
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
    } on Object {
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
    // Build the full list of attachments from both the comma-separated
    // attachment_url field and the attachment_urls array if present.
    final fromUrl = '${h['attachment_url'] ?? h['attachmentUrl'] ?? ''}'
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final fromList = (h['attachment_urls'] is List)
        ? (h['attachment_urls'] as List)
              .map((e) => e?.toString().trim() ?? '')
              .where((s) => s.isNotEmpty)
              .toList()
        : <String>[];
    final allAttachments = {...fromUrl, ...fromList}.toList();
    return {
      'id': _homeworkId(h),
      'homework_id': h['homework_id'],
      'title': h['title'] ?? '',
      'subject': h['subject'] ?? h['subject_name'] ?? h['subject_id'] ?? '',
      'class': h['class'] ?? h['class_name'] ?? '',
      'deadline': dueDate == null
          ? '${h['deadline'] ?? ''}'
          : '${dueDate.day}/${dueDate.month}/${dueDate.year}',
      'instructions': h['description'] ?? h['instructions'] ?? '',
      'teacher':
          h['teacher_name'] ?? h['created_by_name'] ?? h['created_by'] ?? '',
      'status': status == 'submitted' || status == 'completed'
          ? 'submitted'
          : 'pending',
      'student_id': h['student_id'] ?? '',
      'submission_id': h['submission_id'] ?? '',
      'submission_status': h['submission_status'] ?? '',
      'submission_remarks': h['submission_remarks'] ?? '',
      'submission_attachment_url': h['submission_attachment_url'] ?? '',
      'submission_attachment_urls': h['submission_attachment_urls'] ?? const [],
      'urgent':
          dueDate != null && dueDate.difference(DateTime.now()).inDays <= 1,
      'attachmentUrl': h['attachment_url'] ?? h['attachmentUrl'],
      'hasAttachment': allAttachments.isNotEmpty,
      'attachments': allAttachments,
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {


  final isDesktop = DesktopBreakpoints.isDesktopWidth(


        MediaQuery.sizeOf(context).width,


      );


      if (isDesktop) {


        return DesktopScreenWrapper(


          breadcrumbs: ['Homework'],


          title: 'Homework',


          actions: const [],


          child: Card(


            elevation: 0,


            child: Padding(


              padding: const EdgeInsets.all(32),


              child: Center(


                child: Column(


                  mainAxisSize: MainAxisSize.min,


                  children: [


                    Icon(Icons.desktop_windows_rounded, size: 48, color: Theme.of(context).colorScheme.primary),


                    const SizedBox(height: 16),


                    Text('Homework', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),


                    const SizedBox(height: 8),


                    Text('Desktop view coming soon', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.5))),


                  ],


                ),


              ),


            ),


          ),


        );


      }

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
    final tokens = Theme.of(context).schoolDesk;
    return Container(
      color: context.appTheme.surface,
      padding: EdgeInsets.symmetric(
        horizontal: SchoolDeskResponsive.contentHorizontalPaddingForWidth(
          MediaQuery.sizeOf(context).width,
          tokens.spacing,
        ),
        vertical: 10,
      ),
      child: ParentChildSelector(
        children: _children,
        selectedIndex: _activeChildIndex,
        onSelected: (index) {
          setState(() => _activeChildIndex = index);
          ParentChildSelectionService.saveIndex(_children, index);
        },
      ),
    );
  }

  Widget _buildSummaryBar() {
    final tokens = Theme.of(context).schoolDesk;
    final horizontal = SchoolDeskResponsive.contentHorizontalPaddingForWidth(
      MediaQuery.sizeOf(context).width,
      tokens.spacing,
    );
    return Container(
      color: context.appTheme.surface,
      padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 12),
      child: Row(
        children: [
          _summaryChip(
            '${_pending.length} Pending',
            context.appTheme.warning,
            context.appTheme.warningContainer,
            Icons.pending_actions_rounded,
          ),
          const SizedBox(width: 8),
          _summaryChip(
            '${_submitted.length} Submitted',
            context.appTheme.success,
            context.appTheme.successContainer,
            Icons.check_circle_outline_rounded,
          ),
          const SizedBox(width: 8),
          _summaryChip(
            '${_homework.length} Total',
            context.appTheme.primary,
            context.appTheme.primaryContainer,
            Icons.assignment_rounded,
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, Color color, Color bg, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
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
      itemBuilder: (_, i) => FadeInCard(
        delay: Duration(milliseconds: 60 * i),
        child: _homeworkCard(list[i]),
      ),
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
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (subject.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    SubjectChips(subjectString: subject),
                  ],
                  if (deadline.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Due: $deadline',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: context.appTheme.muted,
                        ),
                      ),
                    ),
                ],
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
          if (hw['attachments'] != null &&
              (hw['attachments'] as List).isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Homework Attachments:',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (hw['attachments'] as List).map((url) {
                final urlStr = url.toString();
                final item = EventPostMediaItem.fromUrl(urlStr);
                final isPdf = item.isPdf;
                return OutlinedButton.icon(
                  onPressed: () => openEventPostMediaPreview(context, item),
                  icon: Icon(
                    isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                    size: 14,
                    color: isPdf ? Colors.red : context.appTheme.primary,
                  ),
                  label: Text(
                    isPdf ? 'View PDF' : 'View Image',
                    style: GoogleFonts.dmSans(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    side: BorderSide(color: context.appTheme.primary),
                  ),
                );
              }).toList(),
            ),
          ],
          if ('${hw['submission_status'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 10),
            _submissionStatusChip(hw),
          ],
          if ('${hw['submission_remarks'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.appTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _text(hw['submission_status']) == 'needs_revision'
                      ? context.appTheme.warning.withAlpha(100)
                      : context.appTheme.success.withAlpha(80),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.rate_review_rounded,
                        size: 14,
                        color:
                            _text(hw['submission_status']) == 'needs_revision'
                            ? context.appTheme.warning
                            : context.appTheme.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Teacher Feedback',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color:
                              _text(hw['submission_status']) == 'needs_revision'
                              ? context.appTheme.warning
                              : context.appTheme.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${hw['submission_remarks']}',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: context.appTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isPending ||
              _text(hw['submission_status']) == 'needs_revision') ...[
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
    final homeworkId = _homeworkId(row);
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
        'submission_attachment_url': _text(submission['attachment_url']),
        'submission_attachment_urls': submission['attachment_urls'] ?? const [],
        'status': submissionStatus == 'needs_revision'
            ? 'pending'
            : 'submitted',
      };
    } on Object catch (_) {
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

  String _homeworkId(Map<String, dynamic> row) =>
      _text(row['homework_id'] ?? row['id']);
}
