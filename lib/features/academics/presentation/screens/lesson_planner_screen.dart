import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';

import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';

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

  String? _attachmentUrl;
  String? _attachmentName;
  bool _uploading = false;

  bool _loading = false;
  String? _error;
  List<dynamic> _planners = [];
  List<Map<String, dynamic>> _classes = const [];
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

  // ── File picker ─────────────────────────────────────────────────────────────

  Future<void> _pickAttachment() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    await _uploadFile(path, result.files.single.name);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (xfile == null) return;
    await _uploadFile(xfile.path, xfile.name);
  }

  Future<void> _uploadFile(String path, String name) async {
    setState(() => _uploading = true);
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(path, filename: name),
      });
      final response = await BackendApiClient.instance.dio.post(
        '/uploads',
        data: formData,
      );
      final url = response.data['url']?.toString() ?? '';
      if (url.isNotEmpty && mounted) {
        setState(() {
          _attachmentUrl = url;
          _attachmentName = name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ── Data ─────────────────────────────────────────────────────────────────────

  Future<void> _loadPlanners() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await RoleAccessService.initialize();
      final response = await BackendApiClient.instance.dio.get(
        '/lesson-planners/teacher',
      );
      if (!mounted) return;
      final classes = RoleAccessService.teacherAssignedClasses
          .where(
            (row) => _sectionId(row).isNotEmpty && _gradeId(row).isNotEmpty,
          )
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      setState(() {
        _classes = classes;
        _selectedSectionId = classes.isNotEmpty
            ? _sectionId(classes.first)
            : null;
        _planners = response.data['data'] ?? [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load lesson planners: $e';
      });
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await BackendApiClient.instance.dio.post(
        '/lesson-planners',
        data: {
          'grade_id': gradeId,
          'section_id': sectionId,
          'week_start_date': _startDateController.text.trim().isEmpty
              ? DateTime.now().toIso8601String()
              : '${_startDateController.text.trim()}T00:00:00Z',
          'week_end_date': _endDateController.text.trim().isEmpty
              ? DateTime.now().add(const Duration(days: 6)).toIso8601String()
              : '${_endDateController.text.trim()}T23:59:59Z',
          'attachment_url': _attachmentUrl ?? '',
          'note': _noteController.text.trim(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lesson Plan uploaded!')));
      _startDateController.clear();
      _endDateController.clear();
      _noteController.clear();
      setState(() {
        _attachmentUrl = null;
        _attachmentName = null;
      });
      await _loadPlanners();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to upload: $e';
      });
    }
  }

  Future<void> _markComplete(String id) async {
    setState(() => _loading = true);
    try {
      await BackendApiClient.instance.dio.post('/lesson-planners/$id/complete');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Marked as completed!')));
      await _loadPlanners();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed: $e';
      });
    }
  }

  Map<String, dynamic> get _selectedClass => _classes.firstWhere(
    (row) => _sectionId(row) == _selectedSectionId,
    orElse: () => _classes.isNotEmpty ? _classes.first : const {},
  );

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Lesson Planner',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Upload form ───────────────────────────────────────────
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Upload Weekly Lesson Plan',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    // Class selector
                    DropdownButtonFormField<String>(
                      value: _selectedSectionId,
                      decoration: const InputDecoration(
                        labelText: 'Assigned Class / Section',
                        border: OutlineInputBorder(),
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
                      onChanged: _classes.length > 1
                          ? (v) => setState(() => _selectedSectionId = v)
                          : null,
                    ),
                    const SizedBox(height: 14),
                    // Week start date
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
                    // Week end date
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
                    // ── Attachment ───────────────────────────────────
                    Text(
                      'Lesson Plan Attachment',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _uploading ? null : _pickImage,
                          icon: const Icon(Icons.photo_outlined, size: 18),
                          label: const Text('Image'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: _uploading ? null : _pickAttachment,
                          icon: const Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 18,
                          ),
                          label: const Text('PDF / Doc'),
                        ),
                        if (_uploading) ...[
                          const SizedBox(width: 10),
                          const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),
                    if (_attachmentUrl != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _attachmentName ?? 'Uploaded',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => setState(() {
                              _attachmentUrl = null;
                              _attachmentName = null;
                            }),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
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
                      onPressed: _loading ? null : _submit,
                      child: const Text('Save Lesson Plan'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Uploaded Plans',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            if (_loading && _planners.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (_planners.isEmpty)
              const Center(child: Text('No lesson plans yet.'))
            else
              ..._planners.map((p) {
                final isCompleted = (p['status'] ?? '') == 'completed';
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(
                      'Week: ${_shortDate(p['week_start_date'])} → ${_shortDate(p['week_end_date'])}',
                    ),
                    subtitle: Text(
                      '${_plannerClassLabel(p)}${(p['note'] ?? '').isNotEmpty ? '\n${p['note']}' : ''}',
                    ),
                    isThreeLine: (p['note'] ?? '').isNotEmpty,
                    trailing: isCompleted
                        ? const Chip(
                            label: Text('Completed'),
                            backgroundColor: Colors.green,
                            labelStyle: TextStyle(color: Colors.white),
                          )
                        : FilledButton.icon(
                            onPressed: () => _markComplete(p['id'].toString()),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Complete'),
                          ),
                  ),
                );
              }),
          ],
        ),
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

  String _plannerClassLabel(dynamic planner) {
    if (planner is! Map) return '';
    final sectionID = planner['section_id']?.toString() ?? '';
    final match = _classes.where((row) => _sectionId(row) == sectionID);
    return match.isEmpty ? sectionID : _classLabel(match.first);
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

String _sectionId(Map<String, dynamic> row) =>
    (row['section_id'] ?? row['id'] ?? '').toString().trim();

String _gradeId(Map<String, dynamic> row) =>
    (row['grade_id'] ?? row['class_id'] ?? '').toString().trim();

String _classLabel(Map<String, dynamic> row) {
  final label = (row['label'] ?? '').toString().trim();
  if (label.isNotEmpty) return label;
  final grade =
      (row['grade_name'] ?? row['class_name'] ?? row['name'] ?? 'Class')
          .toString();
  final section = (row['section_name'] ?? row['section'] ?? '').toString();
  return section.trim().isEmpty ? grade : '$grade - $section';
}
