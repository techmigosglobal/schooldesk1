import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';

class ParentExamScheduleScreen extends StatefulWidget {
  const ParentExamScheduleScreen({super.key});

  @override
  State<ParentExamScheduleScreen> createState() => _ParentExamScheduleScreenState();
}

class _ParentExamScheduleScreenState extends State<ParentExamScheduleScreen> {
  int _selectedNavIndex = 1; // Academics
  int _activeChildIndex = 0;
  static const _headerColor = Color(0xFF1A6B4A);

  List<String> _children = [];
  List<String> _childIds = [];
  List<dynamic> _schedules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final childrenResponse = await BackendApiClient.instance.getMyStudents();
      setState(() {
        _children = childrenResponse.map((c) {
          final first = (c['first_name'] ?? '').toString();
          final last = (c['last_name'] ?? '').toString();
          final name = [first, last].where((e) => e.isNotEmpty).join(' ').trim();
          final grade = (c['grade_name'] ?? '').toString();
          final section = (c['section_name'] ?? '').toString();
          final classLabel = [grade, section].where((e) => e.isNotEmpty).join('-');
          return classLabel.isEmpty ? name : '$name ($classLabel)';
        }).toList();
        _childIds = childrenResponse
            .map((c) => (c['id'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toList();

        if (_children.isNotEmpty && _childIds.isNotEmpty) {
          _loadChildExams(_activeChildIndex);
        } else {
          _loading = false;
        }
      });
    } catch (e) {
      setState(() => _loading = false);
      _showErrorSnackBar('Failed to load child list: $e');
    }
  }

  Future<void> _loadChildExams(int childIndex) async {
    if (childIndex >= _childIds.length) return;
    setState(() => _loading = true);
    try {
      final studentId = _childIds[childIndex];
      final response = await BackendApiClient.instance.getRawList('/me/exam-schedule?student_id=$studentId');
      setState(() {
        _schedules = response;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showErrorSnackBar('Failed to load exam schedules: $e');
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

  Map<String, List<dynamic>> get _groupedExams {
    final Map<String, List<dynamic>> groups = {};
    for (final schedule in _schedules) {
      final examName = schedule['exam']?['exam_name'] ?? 'General Exam';
      if (!groups.containsKey(examName)) {
        groups[examName] = [];
      }
      groups[examName]!.add(schedule);
    }
    // Sort schedules inside each group by date
    groups.forEach((key, list) {
      list.sort((a, b) {
        final dA = DateTime.tryParse('${a['exam_date'] ?? ''}') ?? DateTime.now();
        final dB = DateTime.tryParse('${b['exam_date'] ?? ''}') ?? DateTime.now();
        return dA.compareTo(dB);
      });
    });
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final drawer = ParentDrawer(
      selectedIndex: _selectedNavIndex,
      onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
    );

    return SchoolDeskModuleScaffold(
      title: 'Exam Schedule',
      subtitle: 'View upcoming exams and class-wise schedules',
      drawer: drawer,
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () {
            if (_childIds.isNotEmpty) {
              _loadChildExams(_activeChildIndex);
            } else {
              _loadData();
            }
          },
          tooltip: 'Refresh exams',
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildChildSelector(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _schedules.isEmpty
                        ? _buildEmptyState()
                        : _buildExamsList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildChildSelector() {
    if (_children.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_children.length, (i) {
          final isActive = i == _activeChildIndex;
          return GestureDetector(
            onTap: () {
              setState(() {
                _activeChildIndex = i;
              });
              _loadChildExams(i);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isActive ? _headerColor : AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? _headerColor : AppTheme.outlineVariant,
                ),
              ),
              child: Text(
                _children[i].split(' ').first,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : AppTheme.onSurface,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_rounded, size: 48, color: AppTheme.muted),
          const SizedBox(height: 12),
          Text(
            'No published exams found',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Keep checking here for future schedules.',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildExamsList() {
    final groups = _groupedExams;
    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, examIndex) {
        final examName = groups.keys.elementAt(examIndex);
        final list = groups[examName]!;

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: _headerColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.quiz_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        examName,
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...list.map((schedule) {
                final subject = schedule['subject']?['subject_name'] ?? 'Subject';
                final dateStr = schedule['exam_date'] as String? ?? '';
                final parsedDate = DateTime.tryParse(dateStr);
                final formattedDate = parsedDate != null
                    ? DateFormat('EEEE, d MMMM yyyy').format(parsedDate)
                    : dateStr.split('T').first;

                final startTime = schedule['start_time'] ?? '—';
                final endTime = schedule['end_time'] ?? '—';
                final room = schedule['room']?['room_number'] ?? '—';
                final maxMarks = schedule['max_marks'] ?? 0;
                final passMarks = schedule['pass_marks'] ?? 0;
                final syllabus = (schedule['syllabus'] as String? ?? '').trim();

                return Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text(
                      subject,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.calendar_month_rounded, size: 12, color: AppTheme.muted),
                            const SizedBox(width: 4),
                            Text(
                              formattedDate,
                              style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 12, color: AppTheme.muted),
                            const SizedBox(width: 4),
                            Text(
                              '$startTime - $endTime',
                              style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.room_rounded, size: 12, color: _headerColor),
                            const SizedBox(width: 4),
                            Text(
                              'Room $room',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: _headerColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Text(
                      'Max: $maxMarks / Pass: $passMarks',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceVariant.withAlpha(40),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.outlineVariant),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Exam Syllabus',
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _headerColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                syllabus.isEmpty ? 'Syllabus details not published yet.' : syllabus,
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: AppTheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
