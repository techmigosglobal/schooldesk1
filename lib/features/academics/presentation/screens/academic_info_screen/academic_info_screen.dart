import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/services/backend_data_service.dart';

import 'package:schooldesk1/core/utils/extensions.dart';

/// Read-only Academic Info screen — shows Principal-published academic year,
/// subjects, classes, and curriculum. Used by Teacher, Admin, and Parent modules.
class AcademicInfoScreen extends StatefulWidget {
  final String role; // 'teacher', 'admin', 'parent'
  final Widget drawer;
  final int drawerIndex;

  const AcademicInfoScreen({
    super.key,
    required this.role,
    required this.drawer,
    required this.drawerIndex,
  });

  @override
  State<AcademicInfoScreen> createState() => _AcademicInfoScreenState();
}

class _AcademicInfoScreenState extends State<AcademicInfoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  BackendDataService? _storage;
  bool _loading = true;

  Map<String, dynamic>? _activeYear;
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _curriculum = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _storage = await BackendDataService.getInstance();
    await _storage!.ensureAcademicManagementLoaded();
    final activeYear = await _storage!.getMap(
      BackendDataService.kActiveAcademicYear,
    );
    final subjects = await _storage!.getList(
      BackendDataService.kAcademicSubjects,
    );
    final classes = await _storage!.getList(
      BackendDataService.kAcademicClasses,
    );
    final curriculum = await _storage!.getList(
      BackendDataService.kSharedCurriculum,
    );
    setState(() {
      _activeYear = activeYear;
      _subjects = subjects;
      _classes = classes;
      _curriculum = curriculum;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 840;
    return Scaffold(
      backgroundColor: context.appTheme.background,
      drawer: isTablet ? null : widget.drawer,
      body: isTablet
          ? Row(
              children: [
                widget.drawer,
                Expanded(child: _buildContent(context)),
              ],
            )
          : _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverAppBar(
          pinned: true,
          floating: true,
          backgroundColor: context.appTheme.surface,
          elevation: 0,
          scrolledUnderElevation: 1,
          title: Text(
            'Academic Information',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.appTheme.onSurface,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.refresh_rounded,
                color: context.appTheme.primary,
              ),
              onPressed: () {
                setState(() => _loading = true);
                _loadData();
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 13),
            labelColor: context.appTheme.primary,
            unselectedLabelColor: context.appTheme.muted,
            indicatorColor: context.appTheme.primary,
            indicatorWeight: 2.5,
            tabs: const [
              Tab(text: 'Curriculum'),
              Tab(text: 'Subjects'),
              Tab(text: 'Classes'),
            ],
          ),
        ),
      ],
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: context.appTheme.primary),
            )
          : Column(
              children: [
                if (_activeYear != null) _buildActiveYearBanner(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCurriculumTab(),
                      _buildSubjectsTab(),
                      _buildClassesTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildActiveYearBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: context.appTheme.primaryContainer,
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 16,
            color: context.appTheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Active Academic Year: ${_activeYear!['name'] ?? ''}  ·  ${_activeYear!['start'] ?? ''} – ${_activeYear!['end'] ?? ''}',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.appTheme.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurriculumTab() {
    if (_curriculum.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 48,
              color: context.appTheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'No curriculum published yet',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: context.appTheme.muted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Principal will publish curriculum soon',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: context.appTheme.muted,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: context.appTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _curriculum.length,
        itemBuilder: (_, i) {
          final item = _curriculum[i];
          final subjects =
              (item['subjects'] as List?)?.map((s) => s.toString()).toList() ??
              [];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.appTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.appTheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['class'] as String? ?? '',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: context.appTheme.successContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item['term'] as String? ?? '',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: context.appTheme.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: subjects
                      .map(
                        (s) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: context.appTheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            s,
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: context.appTheme.primary,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubjectsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: context.appTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${_subjects.length} Subjects',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.appTheme.muted,
            ),
          ),
          const SizedBox(height: 12),
          ..._subjects.map((s) => _SubjectInfoTile(subject: s)),
          if (_subjects.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text(
                  'No subjects configured',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: context.appTheme.muted,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildClassesTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: context.appTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${_classes.length} Classes',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.appTheme.muted,
            ),
          ),
          const SizedBox(height: 12),
          ..._classes.map((c) => _ClassInfoTile(classData: c)),
          if (_classes.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text(
                  'No classes configured',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: context.appTheme.muted,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _SubjectInfoTile extends StatelessWidget {
  final Map<String, dynamic> subject;

  const _SubjectInfoTile({required this.subject});

  Color _typeColor(BuildContext context, String type) {
    switch (type) {
      case 'Core':
        return context.appTheme.primary;
      case 'Elective':
        return context.appTheme.secondary;
      case 'Co-curricular':
        return context.appTheme.success;
      default:
        return context.appTheme.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = subject['type'] as String? ?? 'Core';
    final color = _typeColor(context, type);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.book_outlined, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject['name'] as String? ?? '',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Code: ${subject['code'] ?? '—'}  ·  ${subject['periodsPerWeek'] ?? 5} periods/week',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: context.appTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              type,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassInfoTile extends StatelessWidget {
  final Map<String, dynamic> classData;

  const _ClassInfoTile({required this.classData});

  @override
  Widget build(BuildContext context) {
    final sections =
        (classData['sections'] as List?)?.map((s) => s.toString()).toList() ??
        [];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.appTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.appTheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.class_rounded,
              size: 18,
              color: context.appTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  classData['name'] as String? ?? '',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Sections: ${sections.join(', ')}  ·  Strength: ${classData['strength'] ?? 40}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: context.appTheme.muted,
                  ),
                ),
                if ((classData['classTeacher'] as String? ?? '').isNotEmpty)
                  Text(
                    'Class Teacher: ${classData['classTeacher']}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: context.appTheme.muted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
