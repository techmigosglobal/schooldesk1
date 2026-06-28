import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/utils/attachment_url_resolver.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';

class ParentLessonPlannerScreen extends StatefulWidget {
  const ParentLessonPlannerScreen({super.key});

  @override
  State<ParentLessonPlannerScreen> createState() =>
      _ParentLessonPlannerScreenState();
}

class _ParentLessonPlannerScreenState extends State<ParentLessonPlannerScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _planners = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final planners = await BackendApiClient.instance
          .getParentLessonPlanners();
      if (!mounted) return;
      setState(() {
        _planners = planners;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load lesson planners.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Lesson Planner',
      subtitle: 'Weekly plans from your child\'s teacher',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _load,
        ),
      ],
      body: _loading
          ? const SchoolDeskStatusPanel.loading(
              message: 'Loading lesson planners',
            )
          : _error != null
          ? SchoolDeskStatusPanel.error(
              title: 'Unavailable',
              message: _error!,
              onAction: _load,
            )
          : _planners.isEmpty
          ? SchoolDeskStatusPanel.empty(
              title: 'No lesson planners yet',
              message:
                  'Your child\'s teacher has not uploaded any lesson plans yet.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _planners.length,
              itemBuilder: (context, index) {
                final p = _planners[index];
                return _PlannerCard(planner: p);
              },
            ),
    );
  }
}

class _PlannerCard extends StatelessWidget {
  final dynamic planner;

  const _PlannerCard({required this.planner});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = planner['status'] ?? 'uploaded';
    final isCompleted = status == 'completed';
    final grade =
        _nested(planner['grade'], 'grade_name') ??
        planner['grade_id']?.toString() ??
        '';
    final section =
        _nested(planner['section'], 'section_name') ??
        planner['section_id']?.toString() ??
        '';
    final classLabel = [grade, section].where((s) => s.isNotEmpty).join(' – ');
    String teacher = 'Teacher';
    if (planner['teacher'] is Map) {
      final t = Map<String, dynamic>.from(planner['teacher']);
      final first = t['first_name']?.toString() ?? t['firstName']?.toString() ?? '';
      final last = t['last_name']?.toString() ?? t['lastName']?.toString() ?? '';
      final full = '$first $last'.trim();
      if (full.isNotEmpty) {
        teacher = full;
      } else {
        teacher = t['full_name']?.toString() ?? t['name']?.toString() ?? 'Teacher';
      }
    }
    final weekStart = _shortDate(planner['week_start_date']);
    final weekEnd = _shortDate(planner['week_end_date']);
    final note = planner['note']?.toString() ?? '';
    final attachmentUrl = planner['attachment_url']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    classLabel.isEmpty ? 'Lesson Plan' : classLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    isCompleted ? 'Completed' : 'Uploaded',
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                  backgroundColor: isCompleted ? Colors.green : Colors.orange,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              text: 'Week: $weekStart – $weekEnd',
            ),
            _InfoRow(icon: Icons.person_outlined, text: 'Teacher: $teacher'),
            if (note.isNotEmpty)
              _InfoRow(icon: Icons.notes_outlined, text: note),
            if (attachmentUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _openAttachment(context, attachmentUrl),
                icon: const Icon(Icons.attach_file_rounded, size: 18),
                label: const Text('View Attachment'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openAttachment(
    BuildContext context,
    String attachmentUrl,
  ) async {
    final uri = resolveAttachmentUrl(attachmentUrl);
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

  String? _nested(dynamic obj, String key) {
    if (obj is Map) return obj[key]?.toString();
    return null;
  }

  String _shortDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString());
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return raw.toString();
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 15,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
