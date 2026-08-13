import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:schooldesk1/core/navigation/role_nav_indices.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/utils/event_post_media_parser.dart';
import 'package:schooldesk1/core/utils/image_upload_optimizer.dart';
import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/event_post_media_preview.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';

class TeacherLessonPlannerScreen extends StatefulWidget {
  const TeacherLessonPlannerScreen({super.key});

  @override
  State<TeacherLessonPlannerScreen> createState() =>
      _TeacherLessonPlannerScreenState();
}

class _TeacherLessonPlannerScreenState
    extends State<TeacherLessonPlannerScreen> {
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _noteController = TextEditingController();

  bool _loading = false;
  bool _uploading = false;
  String? _error;
  List<Map<String, dynamic>> _planners = const [];
  List<Map<String, dynamic>> _classes = const [];
  List<_LessonPlannerAttachment> _attachments = const [];
  String? _selectedSectionId;

  @override
  void initState() {
    super.initState();
    _loadPlanners();
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadPlanners() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await RoleAccessService.initialize();
      final results = await Future.wait([
        BackendApiClient.instance.getTeacherLessonPlanners(),
        _loadAssignedClasses(),
      ]);
      if (!mounted) return;
      final planners = results[0];
      final classes = results[1];
      setState(() {
        _classes = classes;
        _selectedSectionId = _resolveSelectedSectionId(classes);
        _planners = planners;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load lesson planners: $error';
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadAssignedClasses() async {
    final assigned = RoleAccessService.teacherAssignedClasses
        .where((row) => _sectionId(row).isNotEmpty)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    if (assigned.isEmpty) return assigned;

    final needsGradeId = assigned.any((row) => _gradeId(row).isEmpty);
    if (!needsGradeId) return assigned;

    try {
      final sections = await BackendApiClient.instance.getSections();
      final bySectionId = {for (final section in sections) section.id: section};
      return assigned.map((row) {
        final sectionId = _sectionId(row);
        final section = bySectionId[sectionId];
        if (section == null) return row;
        return {
          ...row,
          if (_gradeId(row).isEmpty) 'grade_id': section.gradeId,
          if (_text(row['grade_name']).isEmpty) 'grade_name': section.gradeName,
          if (_text(row['section_name']).isEmpty)
            'section_name': section.sectionName,
        };
      }).toList();
    } on Object catch (_) {
      return assigned;
    }
  }

  String? _resolveSelectedSectionId(List<Map<String, dynamic>> classes) {
    if (classes.isEmpty) return null;
    final current = _selectedSectionId;
    if (current != null && classes.any((row) => _sectionId(row) == current)) {
      return current;
    }
    return _sectionId(classes.first);
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    for (final file in result.files) {
      final path = file.path ?? '';
      final isImage = ImageUploadOptimizer.isImage(
        file.name,
        _mimeTypeForName(file.name),
      );
      final optimized = isImage
          ? (file.bytes != null
                ? ImageUploadOptimizer.fromBytes(
                    file.bytes!,
                    filename: file.name,
                    mimeType: _mimeTypeForName(file.name),
                    preset: ImageUploadPreset.content,
                  )
                : await ImageUploadOptimizer.fromPath(
                    path,
                    filename: file.name,
                    mimeType: _mimeTypeForName(file.name),
                    preset: ImageUploadPreset.content,
                  ))
          : null;
      if (path.isEmpty && file.bytes == null) continue;
      await _uploadFile(
        path,
        optimized?.filename ?? file.name,
        size: optimized?.optimizedSize ?? file.size,
        mimeType: optimized?.mimeType ?? _mimeTypeForName(file.name),
        fileBytes: optimized?.bytes ?? file.bytes,
      );
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (image == null) return;
    final optimized = await ImageUploadOptimizer.fromXFile(
      image,
      preset: ImageUploadPreset.content,
    );
    await _uploadFile(
      image.path,
      optimized.filename,
      size: optimized.optimizedSize,
      mimeType: optimized.mimeType,
      fileBytes: optimized.bytes,
    );
  }

  Future<void> _uploadFile(
    String path,
    String name, {
    int size = 0,
    String mimeType = '',
    Uint8List? fileBytes,
  }) async {
    setState(() => _uploading = true);
    try {
      final url = await BackendApiClient.instance.uploadFile(
        path,
        filename: name,
        fileBytes: fileBytes,
        mimeType: mimeType,
      );
      if (!mounted || url.isEmpty) return;
      setState(() {
        _attachments = [
          ..._attachments,
          _LessonPlannerAttachment(
            url: url,
            name: name,
            mimeType: mimeType,
            size: size,
          ),
        ];
      });
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $error')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    final selectedClass = _selectedClass;
    final sectionId = _sectionId(selectedClass);
    final gradeId = _gradeId(selectedClass);
    if (sectionId.isEmpty || gradeId.isEmpty) {
      setState(
        () => _error = 'No class assigned. Please contact Admin/Principal.',
      );
      return;
    }
    if (_attachments.isEmpty) {
      setState(() => _error = 'At least one lesson plan file is required.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await BackendApiClient.instance.createLessonPlanner(
        gradeId: gradeId,
        sectionId: sectionId,
        weekStartDate: _startDateController.text.trim().isEmpty
            ? DateTime.now().toIso8601String()
            : '${_startDateController.text.trim()}T00:00:00Z',
        weekEndDate: _endDateController.text.trim().isEmpty
            ? DateTime.now().add(const Duration(days: 6)).toIso8601String()
            : '${_endDateController.text.trim()}T23:59:59Z',
        attachmentUrl: _attachments.first.url,
        attachments: _attachments.map((item) => item.toJson()).toList(),
        note: _noteController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lesson plan uploaded.')));
      _startDateController.clear();
      _endDateController.clear();
      _noteController.clear();
      setState(() => _attachments = const []);
      await _loadPlanners();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to upload: $error';
      });
    }
  }

  Map<String, dynamic> get _selectedClass => _classes.firstWhere(
    (row) => _sectionId(row) == _selectedSectionId,
    orElse: () => _classes.isNotEmpty ? _classes.first : const {},
  );

  @override
  Widget build(BuildContext context) {
    final selectedClassPlanners = _selectedClassPlanners;
    final uploaded = selectedClassPlanners
        .where((planner) => _text(planner['status']) != 'completed')
        .toList();
    final completed = selectedClassPlanners
        .where((planner) => _text(planner['status']) == 'completed')
        .toList();
    return TeacherFlowScaffold(
      title: 'Lesson Planner',
      subtitle: 'Weekly class plans',
      selectedIndex: TeacherNav.lessonPlanner,
      loading: _loading && _planners.isEmpty,
      error: _error != null && _planners.isEmpty ? _error : null,
      onRefresh: _loadPlanners,
      child: TeacherFlowScrollView(
        children: [
          _uploadCard(context),
          const SizedBox(height: 28),
          Text(
            'Uploaded Plans',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          if (selectedClassPlanners.isEmpty)
            const TeacherFlowCard(
              icon: Icons.auto_stories_outlined,
              title: 'No lesson plans yet',
              subtitle: 'Waiting for weekly uploads',
              body: Text('Upload next week plans for your assigned class.'),
            )
          else ...[
            ...uploaded.map(_plannerCard),
            if (completed.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Completed Plans',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              ...completed.map(_plannerCard),
            ],
          ],
        ],
      ),
    );
  }

  Widget _uploadCard(BuildContext context) {
    return TeacherFlowCard(
      icon: Icons.upload_file_rounded,
      title: 'Upload Weekly Lesson Plan',
      subtitle: 'Share PDFs or images for the selected week',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null && _planners.isNotEmpty) ...[
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
          ],
          DropdownButtonFormField<String>(
            value: _selectedSectionId,
            decoration: InputDecoration(
              labelText: 'Class / Section',
              border: const OutlineInputBorder(),
              helperText: _classes.isEmpty
                  ? 'No assigned classes found. Contact Admin/Principal.'
                  : 'Uploads and displayed plans are limited to this class.',
            ),
            items: _classes
                .map(
                  (row) => DropdownMenuItem<String>(
                    value: _sectionId(row),
                    child: Text(_classLabel(row)),
                  ),
                )
                .where((item) => item.value?.isNotEmpty == true)
                .toList(),
            onChanged: _classes.isEmpty
                ? null
                : (value) => setState(() => _selectedSectionId = value),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _startDateController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Week Start Date',
              hintText: 'Tap to pick',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today_outlined),
            ),
            onTap: () => _pickDate(_startDateController),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _endDateController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Week End Date',
              hintText: 'Tap to pick',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today_outlined),
            ),
            onTap: () => _pickDate(_endDateController),
          ),
          const SizedBox(height: 20),
          Text(
            'Lesson Plan Attachments',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _uploading ? null : _pickImage,
                icon: const Icon(Icons.photo_outlined, size: 18),
                label: const Text('Image'),
              ),
              OutlinedButton.icon(
                onPressed: _uploading ? null : _pickAttachment,
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('PDF / Images'),
              ),
              if (_uploading)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (_attachments.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final attachment in _attachments)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        attachment.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => setState(() {
                        _attachments = _attachments
                            .where((item) => item.url != attachment.url)
                            .toList();
                      }),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 14),
          SchoolDeskTextField(
            controller: _noteController,
            label: 'Note (optional)',
            hint: 'Any remarks...',
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading || _uploading ? null : _submit,
            child: const Text('Save Lesson Plan'),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _selectedClassPlanners {
    final sectionId = _selectedSectionId?.trim() ?? '';
    if (sectionId.isEmpty) return _planners;
    return _planners
        .where((planner) => _text(planner['section_id']) == sectionId)
        .toList();
  }

  Widget _plannerCard(Map<String, dynamic> planner) {
    final isCompleted = _text(planner['status']) == 'completed';
    final attachments = _lessonPlannerAttachments(planner);
    return TeacherFlowCard(
      icon: Icons.event_note_rounded,
      title:
          'Week: ${_shortDate(planner['week_start_date'])} -> ${_shortDate(planner['week_end_date'])}',
      subtitle: _plannerClassLabel(planner),
      trailing: isCompleted
          ? const TeacherStatusPill(label: 'Completed', color: Colors.green)
          : const TeacherStatusPill(label: 'Current week', color: Colors.blue),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_plannerClassLabel(planner)),
          if (_text(planner['note']).isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(_text(planner['note'])),
          ],
          if (isCompleted && _text(planner['completed_at']).isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Completed: ${_shortDate(planner['completed_at'])}'),
          ],
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
    );
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      controller.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  String _plannerClassLabel(Map<String, dynamic> planner) {
    final sectionId = _text(planner['section_id']);
    final match = _classes.where((row) => _sectionId(row) == sectionId);
    if (match.isNotEmpty) return _classLabel(match.first);
    final grade = _text(planner['grade_name']);
    final section = _text(planner['section_name']);
    if (grade.isEmpty && section.isEmpty) return sectionId;
    return section.isEmpty ? grade : '$grade - $section';
  }

  String _shortDate(Object? raw) {
    if (raw == null) return '';
    try {
      final date = DateTime.parse(raw.toString());
      return '${date.day}/${date.month}/${date.year}';
    } on Object catch (_) {
      return raw.toString();
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
}

class _LessonPlannerAttachment {
  final String url;
  final String name;
  final String mimeType;
  final int size;

  const _LessonPlannerAttachment({
    required this.url,
    required this.name,
    this.mimeType = '',
    this.size = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'name': name,
      if (mimeType.trim().isNotEmpty) 'mime_type': mimeType.trim(),
      if (size > 0) 'size': size,
    };
  }
}

String _sectionId(Map<String, dynamic> row) =>
    (row['section_id'] ?? row['id'] ?? '').toString().trim();

String _gradeId(Map<String, dynamic> row) =>
    (row['grade_id'] ?? row['class_id'] ?? '').toString().trim();

String _classLabel(Map<String, dynamic> row) {
  final label = _text(row['label']);
  if (label.isNotEmpty) return label;
  final grade = _text(
    row['grade_name'] ?? row['class_name'] ?? row['name'],
    fallback: 'Class',
  );
  final section = _text(row['section_name'] ?? row['section']);
  return section.isEmpty ? grade : '$grade - $section';
}

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _mimeTypeForName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.pdf')) return 'application/pdf';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  return '';
}
