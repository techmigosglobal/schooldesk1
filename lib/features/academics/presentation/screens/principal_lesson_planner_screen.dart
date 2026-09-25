import 'package:flutter/material.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/event_post_media_preview.dart';
import 'package:schooldesk1/core/widgets/status_badge_widget.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';
import 'package:schooldesk1/roles/principal/data/api_principal_lesson_planner_repository.dart';
import 'package:schooldesk1/roles/principal/domain/principal_lesson_planner_repository.dart';

final class _PrincipalLessonPlannerSnapshot {
  const _PrincipalLessonPlannerSnapshot({
    required this.planners,
    required this.classes,
  });

  final List<Map<String, dynamic>> planners;
  final List<Map<String, dynamic>> classes;
}

class PrincipalLessonPlannerScreen extends StatefulWidget {
  const PrincipalLessonPlannerScreen({super.key, this.repository});

  final PrincipalLessonPlannerRepository? repository;

  @override
  State<PrincipalLessonPlannerScreen> createState() =>
      _PrincipalLessonPlannerScreenState();
}

class _PrincipalLessonPlannerScreenState
    extends State<PrincipalLessonPlannerScreen> {
  PrincipalLessonPlannerRepository get _repository =>
      widget.repository ?? ApiPrincipalLessonPlannerRepository.legacyDefault;

  RepositoryState<_PrincipalLessonPlannerSnapshot> _repositoryState =
      const RepositoryState.loading();
  String _query = '';
  String _statusFilter = 'all';
  List<Map<String, dynamic>> _planners = const [];
  List<Map<String, dynamic>> _classes = const [];
  String _selectedSectionId = '';

  @override
  void initState() {
    super.initState();
    _loadPlanners();
  }

  Future<void> _loadPlanners() async {
    final previous = _repositoryState;
    setState(() {
      _repositoryState = RepositoryState.loading(
        data: previous.data,
        source: previous.source,
        isStale: previous.isStale,
        isRefreshing: previous.hasData,
        lastUpdated: previous.lastUpdated,
      );
    });
    try {
      final plannerFuture = _repository.loadLessonPlanners();
      final sectionFuture = _repository.loadSections();
      final rows = await plannerFuture;
      final sections = await sectionFuture;
      if (!mounted) return;
      final classes = sections
          .map(
            (section) => {
              'id': section['id'],
              'label': [section['grade_name'], section['section_name']]
                  .whereType<String>()
                  .where((value) => value.trim().isNotEmpty)
                  .join(' - '),
            },
          )
          .where((row) => _text(row['id']).isNotEmpty)
          .toList();
      setState(() {
        _planners = rows;
        _classes = classes;
        if (_selectedSectionId.isNotEmpty &&
            !_classes.any((row) => row['id'] == _selectedSectionId)) {
          _selectedSectionId = '';
        }
        _repositoryState = RepositoryState(
          data: _PrincipalLessonPlannerSnapshot(
            planners: List.unmodifiable(rows),
            classes: List.unmodifiable(classes),
          ),
          source: RepositorySource.remote,
          phase: rows.isEmpty ? RepositoryPhase.empty : RepositoryPhase.ready,
          lastUpdated: DateTime.now().toUtc(),
        );
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _repositoryState = previous.hasData
            ? RepositoryState(
                data: previous.data,
                source: RepositorySource.cache,
                isStale: true,
                error: error,
                lastUpdated: previous.lastUpdated,
              )
            : RepositoryState.error(error: error);
      });
    }
  }

  List<Map<String, dynamic>> get _filteredPlanners {
    final normalizedQuery = _query.trim().toLowerCase();
    return _planners.where((planner) {
      if (_selectedSectionId.isNotEmpty &&
          _text(planner['section_id']) != _selectedSectionId) {
        return false;
      }
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

  List<Map<String, dynamic>> get _classScopedPlanners => _planners
      .where(
        (planner) =>
            _selectedSectionId.isEmpty ||
            _text(planner['section_id']) == _selectedSectionId,
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    final filteredPlanners = _filteredPlanners;
    return SchoolDeskModuleScaffold(
      title: 'Lesson Planners',
      subtitle: 'Class-wise lesson planner monitoring',
      drawer: PrincipalDrawer(
        selectedIndex: PrincipalNav.lessonPlanner,
        onDestinationSelected: (_) {},
      ),
      body: SchoolDeskRepositoryStateView<_PrincipalLessonPlannerSnapshot>(
        state: _repositoryState,
        onRetry: _loadPlanners,
        emptyTitle: 'No lesson planners found',
        emptyMessage: 'Uploaded or created class teacher plans appear here.',
        errorTitle: 'Lesson planners unavailable',
        data: (_) => RefreshIndicator(
          onRefresh: _loadPlanners,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _LessonPlannerSummary(planners: _classScopedPlanners),
              const SizedBox(height: 16),
              _buildFilters(),
              const SizedBox(height: 16),
              ...filteredPlanners.map(_LessonPlannerCard.new),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          value: _selectedSectionId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Class / Section',
            helperText: 'Show lesson planners for the selected class only.',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: '', child: Text('All classes')),
            ..._classes.map(
              (row) => DropdownMenuItem(
                value: _text(row['id']),
                child: Text(_text(row['label'], fallback: 'Class')),
              ),
            ),
          ],
          onChanged: (value) =>
              setState(() => _selectedSectionId = value ?? ''),
        ),
        const SizedBox(height: 10),
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
            ButtonSegment(value: 'uploaded', label: Text('Current plans')),
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
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
              label: 'Current plans',
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
      ),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
    final attachments = _lessonPlannerAttachments(planner);
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
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final attachment in attachments)
                    SizedBox(
                      width: 132,
                      child: EventPostMediaPreview(
                        item: EventPostMediaItem(
                          url: _text(attachment['url']),
                          name: _text(attachment['name']),
                          mimeType: _text(attachment['mime_type']),
                          kind: EventPostMediaItem.fromUrl(
                            _text(attachment['url']),
                          ).kind,
                        ),
                        height: 92,
                        compact: true,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

List<Map<String, dynamic>> _lessonPlannerAttachments(
  Map<String, dynamic> planner,
) {
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
    {'url': url, 'name': 'Open attachment'},
  ];
}

String _classLabel(Map<String, dynamic> planner) {
  final displayName = _classDisplayName(planner);
  return 'Class Name: $displayName';
}

String _classDisplayName(Map<String, dynamic> planner) {
  final className = _readDisplayText(planner['class_name']);
  final gradeName = _gradeDisplayName(planner);
  final sectionName = _sectionDisplayName(planner);

  if (className.isNotEmpty && sectionName.isNotEmpty) {
    return className.contains(sectionName)
        ? className
        : '$className - $sectionName';
  }
  if (className.isNotEmpty) return className;
  if (sectionName.isEmpty) return gradeName.isEmpty ? 'Class' : gradeName;
  return '${gradeName.isEmpty ? 'Class' : gradeName} - $sectionName';
}

String _gradeDisplayName(Map<String, dynamic> planner) {
  String gradeName = '';
  final grade = planner['grade'];
  if (grade is Map) {
    gradeName = _readDisplayText(
      grade['grade_name'] ?? grade['name'] ?? grade['gradeName'],
    );
  }
  if (gradeName.isEmpty) {
    gradeName = _readDisplayText(planner['grade_name']);
  }
  return gradeName;
}

String _sectionDisplayName(Map<String, dynamic> planner) {
  String sectionName = '';
  final section = planner['section'];
  if (section is Map) {
    sectionName = _readDisplayText(
      section['section_name'] ?? section['name'] ?? section['sectionName'],
    );
  }
  if (sectionName.isEmpty) {
    sectionName = _readDisplayText(
      planner['section_name'] ?? planner['section'],
    );
  }
  return sectionName;
}

String _teacherName(Map<String, dynamic> planner) {
  final teacher = planner['teacher'];
  if (teacher is Map) {
    final teacherMap = Map<String, dynamic>.from(teacher);
    final first = _text(teacherMap['first_name'] ?? teacherMap['firstName']);
    final last = _text(teacherMap['last_name'] ?? teacherMap['lastName']);
    final full = '$first $last'.trim();
    if (full.isNotEmpty && !_isGenericTeacherName(full)) return full;
    final explicit = _text(
      teacherMap['full_name'] ?? teacherMap['name'] ?? teacherMap['fullName'],
    );
    if (explicit.isNotEmpty && !_isGenericTeacherName(explicit)) {
      return explicit;
    }
  }
  final explicit = _text(planner['teacher_name'] ?? planner['staff_name']);
  if (explicit.isNotEmpty && !_isGenericTeacherName(explicit)) return explicit;
  return 'Teacher';
}

String _shortDate(Object? raw) {
  if (raw == null) return '-';
  try {
    final dt = DateTime.parse(raw.toString());
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  } on Object catch (_) {
    return raw.toString();
  }
}

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _readDisplayText(Object? value) {
  final display = _text(value);
  return _isUuidLike(display) ? '' : display;
}

bool _isUuidLike(String value) {
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(value.trim());
}

bool _isGenericTeacherName(String value) {
  return value.trim().toLowerCase() == 'teacher';
}
