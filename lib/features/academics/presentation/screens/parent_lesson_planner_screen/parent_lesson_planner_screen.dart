import 'package:flutter/material.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/event_post_media_preview.dart';

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
      final first =
          t['first_name']?.toString() ?? t['firstName']?.toString() ?? '';
      final last =
          t['last_name']?.toString() ?? t['lastName']?.toString() ?? '';
      final full = '$first $last'.trim();
      if (full.isNotEmpty) {
        teacher = full;
      } else {
        teacher =
            t['full_name']?.toString() ?? t['name']?.toString() ?? 'Teacher';
      }
    }
    final weekStart = _shortDate(planner['week_start_date']);
    final weekEnd = _shortDate(planner['week_end_date']);
    final note = planner['note']?.toString() ?? '';
    final attachments = _lessonPlannerAttachments(planner);
    final accentColor = isCompleted
        ? const Color(0xFF16A34A)
        : const Color(0xFF0284C7);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withAlpha(50),
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCompleted
                    ? [const Color(0xFF15803D), const Color(0xFF22C55E)]
                    : [const Color(0xFF0369A1), const Color(0xFF0EA5E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    classLabel.isEmpty ? 'Lesson Plan' : classLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCompleted
                            ? Icons.check_circle_rounded
                            : Icons.upload_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isCompleted ? 'Completed' : 'Uploaded',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  text: 'Week: $weekStart – $weekEnd',
                ),
                _InfoRow(
                  icon: Icons.person_outlined,
                  text: 'Teacher: $teacher',
                ),
                if (note.isNotEmpty)
                  _InfoRow(icon: Icons.notes_outlined, text: note),
                if (attachments.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final attachment in attachments)
                        OutlinedButton.icon(
                          onPressed: () => _openAttachment(
                            context,
                            _text(attachment['url']),
                            name: _text(attachment['name']),
                          ),
                          icon: const Icon(
                            Icons.attach_file_rounded,
                            size: 16,
                          ),
                          label: Text(
                            _text(
                              attachment['name'],
                              fallback: 'View Attachment',
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: accentColor,
                            side: BorderSide(color: accentColor.withAlpha(80)),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openAttachment(
    BuildContext context,
    String attachmentUrl, {
    String name = '',
  }) {
    final item = EventPostMediaItem.fromUrl(attachmentUrl);
    final namedItem = name.isNotEmpty && item.displayName.isEmpty
        ? EventPostMediaItem(
            url: item.url,
            name: name,
            kind: item.kind,
          )
        : item;
    openEventPostMediaPreview(context, namedItem);
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

List<Map<String, dynamic>> _lessonPlannerAttachments(dynamic planner) {
  if (planner is! Map) return const [];
  final attachments = planner['attachments'];
  if (attachments is List) {
    return attachments
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .where((row) => _text(row['url']).isNotEmpty)
        .toList();
  }
  final url = _text(planner['attachment_url']);
  if (url.isEmpty) return const [];
  return [
    {'url': url, 'name': 'View Attachment'},
  ];
}

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
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
