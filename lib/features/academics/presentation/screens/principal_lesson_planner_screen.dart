import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/utils/attachment_url_resolver.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/status_badge_widget.dart';

class PrincipalLessonPlannerScreen extends StatefulWidget {
  const PrincipalLessonPlannerScreen({super.key});

  @override
  State<PrincipalLessonPlannerScreen> createState() =>
      _PrincipalLessonPlannerScreenState();
}

class _PrincipalLessonPlannerScreenState
    extends State<PrincipalLessonPlannerScreen> {
  bool _loading = true;
  String? _error;
  String _query = '';
  String _statusFilter = 'all';
  List<Map<String, dynamic>> _planners = const [];

  @override
  void initState() {
    super.initState();
    _loadPlanners();
  }

  Future<void> _loadPlanners() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await BackendApiClient.instance.getPrincipalLessonPlanners();
      if (!mounted) return;
      setState(() {
        _planners = rows;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredPlanners {
    final normalizedQuery = _query.trim().toLowerCase();
    return _planners.where((planner) {
      final status = _text(
        planner['status'],
        fallback: 'uploaded',
      ).trim().toLowerCase();
      if (_statusFilter != 'all' && status != _statusFilter) return false;
      if (normalizedQuery.isEmpty) return true;
      final searchable = [
        _classLabel(planner),
        _teacherName(planner),
        _text(planner['note']),
        _text(planner['subject_name']),
      ].join(' ').toLowerCase();
      return searchable.contains(normalizedQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Lesson Planners',
      subtitle: 'Class-wise lesson planner monitoring',
      drawer: PrincipalDrawer(
        selectedIndex: PrincipalNav.lessonPlanner,
        onDestinationSelected: (_) {},
      ),
      body: RefreshIndicator(
        onRefresh: _loadPlanners,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _LessonPlannerSummary(planners: _planners),
            const SizedBox(height: 16),
            _buildFilters(),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _StatePanel(
                icon: Icons.error_outline_rounded,
                title: 'Lesson planners unavailable',
                message: _error!,
                actionLabel: 'Retry',
                onAction: _loadPlanners,
              )
            else if (_filteredPlanners.isEmpty)
              const _StatePanel(
                icon: Icons.auto_stories_outlined,
                title: 'No lesson planners found',
                message: 'Uploaded or created class teacher plans appear here.',
              )
            else
              ..._filteredPlanners.map(_LessonPlannerCard.new),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            labelText: 'Search class, teacher, subject',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          selected: {_statusFilter},
          onSelectionChanged: (values) =>
              setState(() => _statusFilter = values.first),
          segments: const [
            ButtonSegment(value: 'all', label: Text('All')),
            ButtonSegment(value: 'uploaded', label: Text('Needs review')),
            ButtonSegment(value: 'completed', label: Text('Completed')),
          ],
        ),
      ],
    );
  }
}

class _LessonPlannerSummary extends StatelessWidget {
  final List<Map<String, dynamic>> planners;

  const _LessonPlannerSummary({required this.planners});

  @override
  Widget build(BuildContext context) {
    final completed = planners
        .where(
          (planner) =>
              _text(planner['status'], fallback: 'uploaded').toLowerCase() ==
              'completed',
        )
        .length;
    final needsReview = planners
        .where(
          (planner) =>
              _text(planner['status'], fallback: 'uploaded').toLowerCase() ==
              'uploaded',
        )
        .length;
    final completion = planners.isEmpty
        ? '0%'
        : '${((completed / planners.length) * 100).round()}%';
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            label: 'Plans',
            value: planners.length.toString(),
            icon: Icons.auto_stories_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(
            label: 'Needs review',
            value: needsReview.toString(),
            icon: Icons.rate_review_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(
            label: 'Completion',
            value: completion,
            icon: Icons.task_alt_rounded,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _LessonPlannerCard extends StatelessWidget {
  final Map<String, dynamic> planner;

  const _LessonPlannerCard(this.planner);

  @override
  Widget build(BuildContext context) {
    final status = _text(planner['status'], fallback: 'uploaded');
    final note = _text(planner['note']);
    final attachment = _text(planner['attachment_url']);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _classLabel(planner),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StatusBadgeWidget(
                  status: status.toLowerCase() == 'completed'
                      ? BadgeStatus.approved
                      : BadgeStatus.pending,
                  customLabel: status,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Teacher: ${_teacherName(planner)}'),
            Text(
              'Week: ${_shortDate(planner['week_start_date'])} to ${_shortDate(planner['week_end_date'])}',
            ),
            if (note.isNotEmpty) ...[const SizedBox(height: 8), Text(note)],
            if (attachment.isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _openAttachment(context, attachment),
                icon: const Icon(Icons.attach_file_rounded, size: 18),
                label: const Text('Open attachment'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openAttachment(BuildContext context, String attachment) async {
    final uri = resolveAttachmentUrl(attachment);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attachment link is not available.')),
      );
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open attachment.')),
      );
    }
  }
}

class _StatePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StatePanel({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

String _classLabel(Map<String, dynamic> planner) {
  final grade = _text(
    planner['grade_name'] ?? planner['class_name'] ?? planner['grade'],
    fallback: 'Class',
  );
  final section = _text(planner['section_name'] ?? planner['section']);
  if (section.isEmpty) return grade;
  return '$grade - $section';
}

String _teacherName(Map<String, dynamic> planner) => _text(
  planner['teacher_name'] ?? planner['staff_name'],
  fallback: 'Teacher',
);

String _shortDate(Object? raw) {
  if (raw == null) return '-';
  try {
    final dt = DateTime.parse(raw.toString());
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  } catch (_) {
    return raw.toString();
  }
}

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
