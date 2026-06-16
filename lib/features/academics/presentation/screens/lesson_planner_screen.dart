import 'package:flutter/material.dart';

import 'package:schooldesk1/core/widgets/erp_components.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';

class TeacherLessonPlannerScreen extends StatefulWidget {
  const TeacherLessonPlannerScreen({super.key});

  @override
  State<TeacherLessonPlannerScreen> createState() => _TeacherLessonPlannerScreenState();
}

class _TeacherLessonPlannerScreenState extends State<TeacherLessonPlannerScreen> {
  final _gradeController = TextEditingController();
  final _sectionController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _attachmentController = TextEditingController();
  final _noteController = TextEditingController();
  
  bool _loading = false;
  String? _error;
  List<dynamic> _planners = [];

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
      final response = await BackendApiClient.instance.dio.get('/api/v1/lesson-planners/teacher');
      if (!mounted) return;
      setState(() {
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
    if (_gradeController.text.trim().isEmpty || _sectionController.text.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await BackendApiClient.instance.dio.post('/api/v1/lesson-planners', data: {
        'grade_id': _gradeController.text.trim(),
        'section_id': _sectionController.text.trim(),
        'week_start_date': _startDateController.text.trim().isEmpty ? DateTime.now().toIso8601String() : '${_startDateController.text.trim()}T00:00:00Z',
        'week_end_date': _endDateController.text.trim().isEmpty ? DateTime.now().add(const Duration(days: 7)).toIso8601String() : '${_endDateController.text.trim()}T23:59:59Z',
        'attachment_url': _attachmentController.text.trim(),
        'note': _noteController.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lesson Plan uploaded successfully!')),
      );
      _gradeController.clear();
      _sectionController.clear();
      _startDateController.clear();
      _endDateController.clear();
      _attachmentController.clear();
      _noteController.clear();
      await _loadPlanners();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to upload lesson planner: $e';
      });
    }
  }

  Future<void> _markComplete(String id) async {
    setState(() => _loading = true);
    try {
      await BackendApiClient.instance.dio.post('/api/v1/lesson-planners/$id/complete');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lesson Plan marked as completed!')),
      );
      await _loadPlanners();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to complete: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Lesson Planner',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Upload New Lesson Plan',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 24),
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    SchoolDeskTextField(
                      controller: _gradeController,
                      label: 'Grade ID',
                      hint: 'e.g. grade-1',
                    ),
                    const SizedBox(height: 16),
                    SchoolDeskTextField(
                      controller: _sectionController,
                      label: 'Section ID',
                      hint: 'e.g. sec-a',
                    ),
                    const SizedBox(height: 16),
                    SchoolDeskTextField(
                      controller: _startDateController,
                      label: 'Start Date (YYYY-MM-DD)',
                      hint: 'Optional',
                    ),
                    const SizedBox(height: 16),
                    SchoolDeskTextField(
                      controller: _endDateController,
                      label: 'End Date (YYYY-MM-DD)',
                      hint: 'Optional',
                    ),
                    const SizedBox(height: 16),
                    SchoolDeskTextField(
                      controller: _attachmentController,
                      label: 'Attachment URL (PDF/Image)',
                      hint: 'https://...',
                    ),
                    const SizedBox(height: 16),
                    SchoolDeskTextField(
                      controller: _noteController,
                      label: 'Note',
                      hint: 'Enter any remarks...',
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: const Text('Save Lesson Plan'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Uploaded Lesson Plans',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 16),
            if (_loading && _planners.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (_planners.isEmpty)
              const Center(child: Text('No lesson plans found.'))
            else
              ..._planners.map((p) {
                final status = p['status'] ?? 'uploaded';
                final isCompleted = status == 'completed';
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text('Week: ${p['week_start_date']} to ${p['week_end_date']}'),
                    subtitle: Text('Grade: ${p['grade_id']} | Sec: ${p['section_id']}\nNote: ${p['note'] ?? ''}'),
                    trailing: isCompleted 
                      ? const Chip(label: Text('Completed'), backgroundColor: Colors.greenAccent)
                      : FilledButton.icon(
                          onPressed: () => _markComplete(p['id']),
                          icon: const Icon(Icons.check),
                          label: const Text('Mark Complete'),
                        ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
