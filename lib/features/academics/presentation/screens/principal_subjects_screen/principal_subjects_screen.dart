import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/empty_state_widget.dart';

/// Read-only subjects overview screen.
///
/// Displays a list of classes, each showing:
/// - Class name
/// - Class Teacher
/// - Co-Teacher
/// - Subjects assigned to that class (names only)
class PrincipalSubjectsScreen extends StatefulWidget {
  const PrincipalSubjectsScreen({super.key});

  @override
  State<PrincipalSubjectsScreen> createState() =>
      _PrincipalSubjectsScreenState();
}

class _PrincipalSubjectsScreenState extends State<PrincipalSubjectsScreen> {
  bool _loading = true;
  String? _error;
  List<_ClassSubjects> _classes = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = BackendApiClient.instance;
      final results = await Future.wait<Object>([
        api.getPrincipalClassesOverview(),
        api.getRawList('/grade-subjects', queryParameters: const {'page_size': 500}),
      ]);

      final payload = results[0] as Map<String, dynamic>;
      final gradeSubjects = results[1] as List<Map<String, dynamic>>;
      final classes = _listMap(payload['classes']);

      if (!mounted) return;

      // Build grade-id to subject-names map from grade_subjects
      final subjectsByGradeId = <String, List<String>>{};
      for (final row in gradeSubjects) {
        final gradeId = _text(row['grade_id']);
        final subjectMap = row['subject'];
        final subjectName = subjectMap is Map
            ? _text(subjectMap['subject_name'] ?? subjectMap['name'])
            : _text(row['subject_name']);
        if (gradeId.isNotEmpty && subjectName.isNotEmpty) {
          subjectsByGradeId.putIfAbsent(gradeId, () => []);
          if (!subjectsByGradeId[gradeId]!.contains(subjectName)) {
            subjectsByGradeId[gradeId]!.add(subjectName);
          }
        }
      }

      // Build the final list
      final result = <_ClassSubjects>[];
      for (final cls in classes) {
        final gradeId = _text(cls['grade_id']);
        final subjects = subjectsByGradeId[gradeId] ?? [];
        result.add(
          _ClassSubjects(
            className: _text(cls['class_name'], fallback: 'Class'),
            gradeName: _text(cls['grade_name']),
            sectionName: _text(cls['section_name']),
            classTeacher: _text(cls['class_teacher'], fallback: 'Not assigned'),
            coTeacher: _text(cls['co_teacher'], fallback: 'Not assigned'),
            subjects: List<String>.from(subjects)..sort(),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _classes = result;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFCFF),
      bottomNavigationBar: const PrincipalShellBottomBar(),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF6C4CFF),
          onRefresh: _loadData,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyStateWidget(
                      icon: Icons.cloud_off_rounded,
                      title: 'Unable to load subjects',
                      description: _error!,
                      actionLabel: 'Retry',
                      onAction: _loadData,
                    ),
                  ),
                )
              else if (_classes.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: EmptyStateWidget(
                      icon: Icons.menu_book_rounded,
                      title: 'No classes found',
                      description: 'Create classes in Class Hub first, then subjects will appear here.',
                      actionLabel: 'Retry',
                      onAction: _loadData,
                    ),
                  ),
                )
              else ...[
                SliverToBoxAdapter(child: _buildSummaryBar()),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 96),
                  sliver: SliverList.separated(
                    itemCount: _classes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) => _ClassSubjectsCard(
                      data: _classes[index],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final totalClasses = _classes.length;
    final totalSubjects = _classes.fold<int>(
      0,
      (sum, cls) => sum + cls.subjects.length,
    );
    final totalTeachers = <String>{};
    for (final cls in _classes) {
      if (cls.classTeacher != 'Not assigned') totalTeachers.add(cls.classTeacher);
      if (cls.coTeacher != 'Not assigned') totalTeachers.add(cls.coTeacher);
    }
    final subtitle = _loading
        ? 'Loading...'
        : '$totalClasses ${totalClasses == 1 ? 'class' : 'classes'} '
            '$totalSubjects ${totalSubjects == 1 ? 'subject' : 'subjects'} '
            '${totalTeachers.length} ${totalTeachers.length == 1 ? 'teacher' : 'teachers'}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Subjects',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 20,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF101828),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF5F6F89),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar() {
    if (_classes.isEmpty) return const SizedBox.shrink();
    final totalSubjects = _classes.fold<int>(
      0,
      (sum, cls) => sum + cls.subjects.length,
    );
    final classesWithSubjects = _classes.where((c) => c.subjects.isNotEmpty).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3EFFF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE3D9FF)),
        ),
        child: Row(
          children: [
            const Icon(Icons.menu_book_outlined, color: Color(0xFF6C4CFF), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$totalSubjects subjects across $classesWithSubjects ${classesWithSubjects == 1 ? 'class' : 'classes'}',
                style: GoogleFonts.dmSans(
                  color: const Color(0xFF6C4CFF),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helpers

  static String _text(Object? value, {String fallback = ''}) {
    if (value == null) return fallback;
    final s = '$value'.trim();
    return (s.isEmpty || s == 'null') ? fallback : s;
  }

  static List<Map<String, dynamic>> _listMap(Object? value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return [];
  }
}

// Data Models

class _ClassSubjects {
  final String className;
  final String gradeName;
  final String sectionName;
  final String classTeacher;
  final String coTeacher;
  final List<String> subjects;

  const _ClassSubjects({
    required this.className,
    required this.gradeName,
    required this.sectionName,
    required this.classTeacher,
    required this.coTeacher,
    required this.subjects,
  });
}

// Widgets

class _ClassSubjectsCard extends StatelessWidget {
  final _ClassSubjects data;

  const _ClassSubjectsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3EAF5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0E1D2440),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Class header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFF),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE8ECF4)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C4CFF).withAlpha(24),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.meeting_room_outlined,
                        color: Color(0xFF6C4CFF),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        data.className,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF101828),
                        ),
                      ),
                    ),
                    _SubjectCountBadge(count: data.subjects.length),
                  ],
                ),
                const SizedBox(height: 12),
                // Teachers row
                Row(
                  children: [
                    _TeacherChip(
                      label: 'Class Teacher',
                      name: data.classTeacher,
                    ),
                    const SizedBox(width: 8),
                    _TeacherChip(
                      label: 'Co-Teacher',
                      name: data.coTeacher,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Subjects list
          if (data.subjects.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Text(
                'No subjects mapped yet',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final subject in data.subjects)
                    _SubjectChip(name: subject),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TeacherChip extends StatelessWidget {
  final String label;
  final String name;

  const _TeacherChip({required this.label, required this.name});

  @override
  Widget build(BuildContext context) {
    final isAssigned = name != 'Not assigned';
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isAssigned ? const Color(0xFFF0F9FF) : const Color(0xFFFFF9F0),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isAssigned ? const Color(0xFFD1E9F8) : const Color(0xFFFFEDD5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 16,
              color: isAssigned ? const Color(0xFF0887F2) : const Color(0xFFF97316),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64727E),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF101828),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectCountBadge extends StatelessWidget {
  final int count;

  const _SubjectCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EFFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3D9FF)),
      ),
      child: Text(
        '$count ${count == 1 ? 'subject' : 'subjects'}',
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF6C4CFF),
        ),
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  final String name;

  const _SubjectChip({required this.name});

  @override
  Widget build(BuildContext context) {
    final colors = _subjectColors(name);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.$2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_subjectIcon(name), size: 15, color: colors.$3),
          const SizedBox(width: 6),
          Text(
            name,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: colors.$3,
            ),
          ),
        ],
      ),
    );
  }

  static IconData _subjectIcon(String label) {
    final v = label.toLowerCase();
    if (v.contains('math')) return Icons.calculate_outlined;
    if (v.contains('english') || v.contains('language')) return Icons.abc_rounded;
    if (v.contains('science') || v.contains('evs')) return Icons.science_outlined;
    if (v.contains('social') || v.contains('history')) return Icons.public_rounded;
    if (v.contains('computer')) return Icons.computer_rounded;
    if (v.contains('music')) return Icons.music_note_rounded;
    if (v.contains('physical') || v.contains('sport')) return Icons.directions_run_rounded;
    if (v.contains('art')) return Icons.palette_outlined;
    if (v.contains('hindi')) return Icons.translate_rounded;
    return Icons.menu_book_outlined;
  }

  static (Color, Color, Color) _subjectColors(String label) {
    final v = label.toLowerCase();
    if (v.contains('math')) return (const Color(0xFFECFDF5), const Color(0xFFA7F3D0), const Color(0xFF059669));
    if (v.contains('science') || v.contains('evs')) return (const Color(0xFFFFFBEB), const Color(0xFFFDE68A), const Color(0xFFD97706));
    if (v.contains('hindi') || v.contains('language')) return (const Color(0xFFF5F3FF), const Color(0xFFDDD6FE), const Color(0xFF7C3AED));
    if (v.contains('english')) return (const Color(0xFFEFF6FF), const Color(0xFFBFDBFE), const Color(0xFF2563EB));
    if (v.contains('art') || v.contains('music')) return (const Color(0xFFFDF2F8), const Color(0xFFFBCFE8), const Color(0xFFDB2777));
    if (v.contains('physical') || v.contains('sport')) return (const Color(0xFFECFEFF), const Color(0xFFA5F3FC), const Color(0xFF0891B2));
    if (v.contains('social') || v.contains('history')) return (const Color(0xFFFFF7ED), const Color(0xFFFED7AA), const Color(0xFFC2410C));
    return (const Color(0xFFF0F9FF), const Color(0xFFBAE6FD), const Color(0xFF0284C7));
  }
}
