import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';

class TeacherSyllabusScreen extends StatefulWidget {
  const TeacherSyllabusScreen({super.key});

  @override
  State<TeacherSyllabusScreen> createState() => _TeacherSyllabusScreenState();
}

class _TeacherSyllabusScreenState extends State<TeacherSyllabusScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<Map<String, dynamic>> _syllabusRecords = [];

  @override
  void initState() {
    super.initState();
    _loadSyllabus();
  }

  Future<void> _loadSyllabus() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await RoleAccessService.initialize();
      final rows = await BackendApiClient.instance.getRawList('/syllabus');
      
      // Filter rows by teacher assignment
      final staffId = RoleAccessService.teacherStaffId;
      final classId = RoleAccessService.teacherClassId;
      final filtered = rows.where((row) {
        final teacherVal = (row['teacher_id'] ?? row['teacher'] ?? '').toString();
        final classVal = (row['section_id'] ?? row['class_id'] ?? row['class'] ?? '').toString();
        if (staffId.isNotEmpty && teacherVal == staffId) return true;
        if (classId.isNotEmpty && classVal == classId) return true;
        return false;
      }).toList();

      setState(() {
        _syllabusRecords = filtered.map((e) => Map<String, dynamic>.from(e)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _updateTopicStatus(Map<String, dynamic> record, int topicIndex, String nextStatus) async {
    final id = (record['id'] ?? '').toString();
    if (id.isEmpty) return;

    final topics = List<Map<String, dynamic>>.from(record['topics'] ?? []);
    if (topicIndex >= topics.length) return;

    setState(() => _saving = true);
    try {
      topics[topicIndex]['status'] = nextStatus;
      
      // Calculate new completion numbers
      final completedCount = topics.where((t) => t['status'] == 'completed').length;
      final inProgressCount = topics.where((t) => t['status'] == 'in_progress').length;
      final pendingCount = topics.where((t) => t['status'] == 'pending' || t['status'] == null).length;

      final payload = {
        ...record,
        'topics': topics,
        'completed': completedCount,
        'inProgress': inProgressCount,
        'pending': pendingCount,
      };

      await BackendApiClient.instance.updateRaw('/syllabus/$id', payload);
      _showSuccessSnackBar('Syllabus updated successfully');
      await _loadSyllabus();
    } catch (e) {
      _showErrorSnackBar('Failed to update syllabus: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _addNewTopic(Map<String, dynamic> record) async {
    final id = (record['id'] ?? '').toString();
    if (id.isEmpty) return;

    final controller = TextEditingController();
    final topicName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Topic'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Topic / Chapter Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (topicName == null || topicName.trim().isEmpty) return;

    setState(() => _saving = true);
    try {
      final topics = List<Map<String, dynamic>>.from(record['topics'] ?? []);
      topics.add({
        'name': topicName.trim(),
        'status': 'pending',
        'date': DateTime.now().toLocal().toString().split(' ').first,
      });

      final completedCount = topics.where((t) => t['status'] == 'completed').length;
      final inProgressCount = topics.where((t) => t['status'] == 'in_progress').length;
      final pendingCount = topics.where((t) => t['status'] == 'pending' || t['status'] == null).length;

      final payload = {
        ...record,
        'topics': topics,
        'completed': completedCount,
        'inProgress': inProgressCount,
        'pending': pendingCount,
      };

      await BackendApiClient.instance.updateRaw('/syllabus/$id', payload);
      _showSuccessSnackBar('Topic added successfully');
      await _loadSyllabus();
    } catch (e) {
      _showErrorSnackBar('Failed to add topic: $e');
    } finally {
      setState(() => _saving = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TeacherFlowScaffold(
      title: 'Syllabus Tracking',
      subtitle: 'Monitor and update curriculum progress',
      selectedIndex: 5, // Academics/Syllabus index
      loading: _loading,
      error: _error,
      onRefresh: _loadSyllabus,
      child: TeacherFlowScrollView(
        children: [
          TeacherCurrentClassCard(
            greeting: 'Curriculum Workflow',
            classLabel: teacherCurrentClassLabel(),
            subject: '${_syllabusRecords.length} syllabus trackers',
            timeLabel: 'Keep track of course progression',
            actions: [
              TeacherFlowAction(
                label: 'Refresh',
                icon: Icons.refresh_rounded,
                onTap: _loadSyllabus,
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(),
            ),
          const TeacherFlowSectionHeader(title: 'Syllabus Records'),
          const SizedBox(height: 10),
          if (_syllabusRecords.isEmpty)
            const TeacherFlowCard(
              icon: Icons.menu_book_rounded,
              title: 'No Syllabus Records',
              subtitle: 'No curriculum trackers are assigned to your profile.',
            )
          else
            ..._syllabusRecords.map(_buildSyllabusRecordCard),
        ],
      ),
    );
  }

  Widget _buildSyllabusRecordCard(Map<String, dynamic> record) {
    final subject = record['subject']?.toString() ?? 'Subject';
    final className = record['class']?.toString() ?? 'Class';
    final topics = List<Map<String, dynamic>>.from(record['topics'] ?? []);

    final total = topics.length;
    final completed = topics.where((t) => t['status'] == 'completed').length;
    final inProgress = topics.where((t) => t['status'] == 'in_progress').length;
    final pending = total - completed - inProgress;
    final completionPct = total > 0 ? completed / total : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(16),
        title: Text(
          '$subject — Class $className',
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: completionPct,
                minHeight: 6,
                backgroundColor: AppTheme.surfaceVariant,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1A6B4A)),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildTopicCountBadge('Done: $completed', Colors.green),
                const SizedBox(width: 8),
                _buildTopicCountBadge('Active: $inProgress', Colors.blue),
                const SizedBox(width: 8),
                _buildTopicCountBadge('Pending: $pending', Colors.orange),
              ],
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: topics.length,
            itemBuilder: (context, idx) {
              final topic = topics[idx];
              final name = topic['name']?.toString() ?? 'Untitled Topic';
              final status = topic['status']?.toString() ?? 'pending';

              Color iconColor = Colors.grey;
              IconData icon = Icons.radio_button_unchecked_rounded;
              if (status == 'completed') {
                iconColor = Colors.green;
                icon = Icons.check_circle_rounded;
              } else if (status == 'in_progress') {
                iconColor = Colors.blue;
                icon = Icons.pending_rounded;
              }

              return ListTile(
                leading: IconButton(
                  icon: Icon(icon, color: iconColor),
                  onPressed: _saving ? null : () {
                    String nextStatus;
                    if (status == 'pending') {
                      nextStatus = 'in_progress';
                    } else if (status == 'in_progress') {
                      nextStatus = 'completed';
                    } else {
                      nextStatus = 'pending';
                    }
                    _updateTopicStatus(record, idx, nextStatus);
                  },
                ),
                title: Text(
                  name,
                  style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.onSurface),
                ),
                trailing: Text(
                  topic['date']?.toString() ?? '',
                  style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : () => _addNewTopic(record),
                icon: const Icon(Icons.add_rounded, color: Color(0xFF1A6B4A)),
                label: Text(
                  'Add New Topic',
                  style: GoogleFonts.dmSans(color: const Color(0xFF1A6B4A)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF1A6B4A)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicCountBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
