import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/teacher_flow_ui.dart';

class TeacherMarkEntryScreen extends StatefulWidget {
  const TeacherMarkEntryScreen({super.key});

  @override
  State<TeacherMarkEntryScreen> createState() => _TeacherMarkEntryScreenState();
}

class _TeacherMarkEntryScreenState extends State<TeacherMarkEntryScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<dynamic> _schedules = [];
  dynamic _selectedSchedule;
  List<_StudentMarkRow> _studentRows = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedSchedule = null;
      _studentRows = [];
    });
    try {
      await RoleAccessService.initialize();
      final schedules = await BackendApiClient.instance.getRawList('/exams/schedules');
      
      // Filter schedules to only show sections/subjects assigned to the teacher
      // or show all if there's no strict assignment metadata.
      final filtered = schedules.where((s) {
        final secId = (s['section_id'] ?? '').toString();
        // If teacher has a class assigned, prioritize it, otherwise allow all
        if (RoleAccessService.teacherClassId.isNotEmpty) {
          return secId == RoleAccessService.teacherClassId;
        }
        return true;
      }).toList();

      setState(() {
        _schedules = filtered.isNotEmpty ? filtered : schedules;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _selectSchedule(dynamic schedule) async {
    setState(() {
      _selectedSchedule = schedule;
      _loading = true;
      _studentRows = [];
    });

    try {
      final scheduleId = (schedule['id'] ?? '').toString();
      final sectionId = (schedule['section_id'] ?? '').toString();

      // Fetch students in this section
      final studentsPage = await BackendApiClient.instance.getStudents(
        sectionId: sectionId,
        page: 1,
        pageSize: 120,
      );

      // Fetch already entered marks
      final enteredMarksResponse = await BackendApiClient.instance.getRawList(
        '/exams/schedules/$scheduleId/marks',
      );

      final List<_StudentMarkRow> rows = [];
      for (final s in studentsPage.data) {
        // Find existing mark
        dynamic existingMark;
        for (final m in enteredMarksResponse) {
          if ((m['student_id'] ?? '').toString() == s.id) {
            existingMark = m;
            break;
          }
        }

        final enrollments = await BackendApiClient.instance.getStudentEnrollments(s.id);
        dynamic activeEnrollment;
        for (final e in enrollments) {
          if ((e['status'] ?? '').toString().toLowerCase() == 'active') {
            activeEnrollment = e;
            break;
          }
        }
        if (activeEnrollment == null && enrollments.isNotEmpty) {
          activeEnrollment = enrollments.first;
        }
        final enrollmentId = activeEnrollment != null ? (activeEnrollment['id'] ?? activeEnrollment['enrollment_id'] ?? '').toString() : '';

        if (existingMark != null) {
          rows.add(_StudentMarkRow(
            studentId: s.id,
            studentName: s.fullName,
            enrollmentId: enrollmentId,
            marksObtained: (existingMark['marks_obtained'] as num?)?.toDouble() ?? 0.0,
            isAbsent: existingMark['is_absent'] == true,
            isExempted: existingMark['is_exempted'] == true,
            controller: TextEditingController(text: (existingMark['marks_obtained'] ?? '0').toString()),
          ));
        } else {
          rows.add(_StudentMarkRow(
            studentId: s.id,
            studentName: s.fullName,
            enrollmentId: enrollmentId,
            marksObtained: 0.0,
            isAbsent: false,
            isExempted: false,
            controller: TextEditingController(text: '0'),
          ));
        }
      }

      setState(() {
        _studentRows = rows;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load schedule marks: $e';
      });
    }
  }

  Future<void> _submitMarks() async {
    if (_selectedSchedule == null) return;
    setState(() => _saving = true);

    final scheduleId = (_selectedSchedule['id'] ?? '').toString();
    try {
      final marksPayload = _studentRows.map((r) {
        final marksObtained = double.tryParse(r.controller.text) ?? 0.0;
        return {
          'student_id': r.studentId,
          'enrollment_id': r.enrollmentId,
          'marks_obtained': r.isAbsent || r.isExempted ? 0.0 : marksObtained,
          'is_absent': r.isAbsent,
          'is_exempted': r.isExempted,
        };
      }).toList();

      await BackendApiClient.instance.createRaw(
        '/exams/schedules/$scheduleId/marks',
        {'marks': marksPayload},
      );

      _showSuccessSnackBar('Marks submitted successfully!');
      setState(() => _selectedSchedule = null);
      await _loadData();
    } catch (e) {
      _showErrorSnackBar('Failed to submit marks: $e');
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
      title: 'Exam Marks Entry',
      subtitle: 'Manage and submit student exam results',
      selectedIndex: 2, // Marks/Attendance index
      loading: _loading,
      error: _error,
      onRefresh: _selectedSchedule != null ? () => _selectSchedule(_selectedSchedule) : _loadData,
      child: TeacherFlowScrollView(
        children: [
          if (_selectedSchedule == null) ...[
            const TeacherFlowSectionHeader(title: 'Select Exam Schedule'),
            const SizedBox(height: 10),
            if (_schedules.isEmpty)
              const TeacherFlowCard(
                icon: Icons.assignment_rounded,
                title: 'No Exam Schedules',
                subtitle: 'There are no active exam schedules for your classes.',
              )
            else
              ..._schedules.map((s) {
                final examName = s['exam']?['exam_name'] ?? s['exam_id'] ?? 'Term Exam';
                final subject = s['subject']?['subject_name'] ?? 'Subject';
                final maxMarks = s['max_marks'] ?? 100;
                final passMarks = s['pass_marks'] ?? 40;
                final dateStr = s['exam_date']?.toString().split('T').first ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: TeacherFlowCard(
                    icon: Icons.quiz_rounded,
                    title: '$examName — $subject',
                    subtitle: 'Max: $maxMarks | Pass: $passMarks | Date: $dateStr',
                    body: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _selectSchedule(s),
                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                          label: const Text('Enter Marks'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1A6B4A),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ] else ...[
            _buildMarkEntryGrid(),
          ],
        ],
      ),
    );
  }

  Widget _buildMarkEntryGrid() {
    final examName = _selectedSchedule['exam']?['exam_name'] ?? _selectedSchedule['exam_id'] ?? 'Term Exam';
    final subject = _selectedSchedule['subject']?['subject_name'] ?? 'Subject';
    final maxMarks = _selectedSchedule['max_marks'] ?? 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TeacherCurrentClassCard(
          greeting: 'Mark Entry Portal',
          classLabel: '$examName — $subject',
          subject: 'Max Marks: $maxMarks',
          timeLabel: '${_studentRows.length} students enrolled',
          actions: [
            TeacherFlowAction(
              label: 'Back',
              icon: Icons.arrow_back_rounded,
              onTap: () => setState(() => _selectedSchedule = null),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ...List.generate(_studentRows.length, (index) {
          final row = _studentRows[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.studentName,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Absent'),
                            selected: row.isAbsent,
                            onSelected: (val) {
                              setState(() {
                                row.isAbsent = val;
                                if (val) row.isExempted = false;
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Exempted'),
                            selected: row.isExempted,
                            onSelected: (val) {
                              setState(() {
                                row.isExempted = val;
                                if (val) row.isAbsent = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (!row.isAbsent && !row.isExempted)
                  SizedBox(
                    width: 72,
                    child: TextField(
                      controller: row.controller,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: 'Marks',
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      row.isAbsent ? 'ABSENT' : 'EXEMPTED',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.muted,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _saving ? null : _submitMarks,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.cloud_done_rounded),
            label: Text(_saving ? 'Saving...' : 'Submit All Marks'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A6B4A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }
}

class _StudentMarkRow {
  final String studentId;
  final String studentName;
  final String enrollmentId;
  double marksObtained;
  bool isAbsent;
  bool isExempted;
  final TextEditingController controller;

  _StudentMarkRow({
    required this.studentId,
    required this.studentName,
    required this.enrollmentId,
    required this.marksObtained,
    required this.isAbsent,
    required this.isExempted,
    required this.controller,
  });
}
