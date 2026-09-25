import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/network/models/backend_models.dart';
import 'package:schooldesk1/modules/communication/domain/entities/notice.dart';
import 'package:schooldesk1/modules/communication/data/repositories/api_notice_repository.dart';
import 'package:schooldesk1/modules/communication/domain/repositories/notice_repository.dart';
import 'package:schooldesk1/modules/people/data/api_staff_directory_repository.dart';
import 'package:schooldesk1/modules/people/data/api_student_directory_repository.dart';
import 'package:schooldesk1/modules/people/domain/staff_directory_repository.dart';
import 'package:schooldesk1/modules/people/domain/student_directory_repository.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';

class GlobalSearchScreen extends StatefulWidget {
  final StudentDirectoryRepository? studentRepository;
  final StaffDirectoryRepository? staffRepository;
  final NoticeRepository? noticeRepository;

  const GlobalSearchScreen({
    super.key,
    this.studentRepository,
    this.staffRepository,
    this.noticeRepository,
  });

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  late TabController _tabController;
  RepositoryState<Object> _state = const RepositoryState(
    data: Object(),
    source: RepositorySource.localMutation,
  );

  List<_SearchResult> _studentResults = [];
  List<_SearchResult> _staffResults = [];
  List<_SearchResult> _noticeResults = [];

  List<Map<String, dynamic>> _allNotices = [];
  Timer? _searchDebounce;
  int _searchGeneration = 0;

  StudentDirectoryRepository get _studentRepository =>
      widget.studentRepository ?? ApiStudentDirectoryRepository.legacyDefault;

  StaffDirectoryRepository get _staffRepository =>
      widget.staffRepository ?? ApiStaffDirectoryRepository.legacyDefault;

  NoticeRepository get _noticeRepository =>
      widget.noticeRepository ?? ApiNoticeRepository.legacyDefault;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initData();
  }

  Future<void> _initData() async {
    final result = await _try(() => _noticeRepository.getNotices());
    final notices = result?.dataOrNull ?? const <Notice>[];
    _allNotices = notices
        .map(
          (notice) => {
            'id': notice.id,
            'title': notice.title,
            'content': notice.content,
            'category': notice.targetAudience,
          },
        )
        .toList();
  }

  Future<T?> _try<T>(Future<T> Function() loader) async {
    try {
      return await loader();
    } on Object catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _search(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _searchServer(query),
    );
  }

  Future<void> _searchServer(String query) async {
    if (query.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _studentResults = [];
        _staffResults = [];
        _noticeResults = [];
      });
      return;
    }

    setState(() {
      _state = RepositoryState.loading(
        data: _state.data,
        source: _state.source,
        isRefreshing: true,
      );
    });
    final generation = ++_searchGeneration;
    try {
      final results = await Future.wait([
        _studentRepository.loadStudents(
          search: query.trim(),
          page: 1,
          pageSize: 20,
        ),
        _staffRepository.loadStaff(
          search: query.trim(),
          page: 1,
          pageSize: 20,
        ),
      ]);
      if (!mounted || generation != _searchGeneration) return;
      final students = results[0] as PaginatedList<StudentModel>;
      final staff = results[1] as PaginatedList<StaffModel>;
      setState(() {
        _studentResults = students.data
            .map(
              (student) => _SearchResult(
                type: 'student',
                title: student.fullName,
                subtitle:
                    'Class ${student.currentSectionId ?? ''} • Roll ${student.studentCode}',
                icon: Icons.school_rounded,
                color: context.appTheme.primary,
                data: {
                  'id': student.id,
                  'name': student.fullName,
                  'rollNo': student.studentCode,
                  'className': student.currentSectionId ?? '',
                  'admissionNo': student.admissionNumber,
                },
              ),
            )
            .toList();
        _staffResults = staff.data
            .map(
              (member) => _SearchResult(
                type: 'staff',
                title: member.fullName,
                subtitle:
                    '${member.designation ?? 'Teacher'} • ${member.email ?? ''}',
                icon: Icons.person_rounded,
                color: const Color(0xFF1A5276),
                data: {
                  'id': member.id,
                  'name': member.fullName,
                  'subject': member.designation ?? '',
                  'employeeId': member.staffCode,
                  'designation': member.designation ?? '',
                },
              ),
            )
            .toList();
        _noticeResults = _allNotices
            .where(
              (n) =>
                  (n['title'] as String? ?? '').toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  (n['content'] as String? ?? '').toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  (n['category'] as String? ?? '').toLowerCase().contains(
                    query.toLowerCase(),
                  ),
            )
            .map(
              (n) => _SearchResult(
                type: 'notice',
                title: n['title'] as String? ?? 'Notice',
                subtitle: n['category'] as String? ?? 'General',
                icon: Icons.campaign_rounded,
                color: context.appTheme.secondary,
                data: n,
              ),
            )
            .toList();
        _state = const RepositoryState(
          data: Object(),
          source: RepositorySource.remote,
        );
      });
    } on Object catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _state = RepositoryState.error(error: 'Search failed. Please retry.');
        _studentResults = [];
        _staffResults = [];
        _noticeResults = [];
      });
    }
  }

  int get _totalResults =>
      _studentResults.length + _staffResults.length + _noticeResults.length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? const Color(0xFF151C26)
        : context.appTheme.background;
    final surfaceColor = isDark
        ? const Color(0xFF1E2530)
        : context.appTheme.surface;
    final onSurfaceColor = isDark
        ? const Color(0xFFE8EDF2)
        : context.appTheme.onSurface;
    final mutedColor = isDark
        ? const Color(0xFF90A4AE)
        : context.appTheme.muted;
    final outlineColor = isDark
        ? const Color(0xFF2D3748)
        : context.appTheme.outlineVariant;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        titleSpacing: 0,
        iconTheme: IconThemeData(color: onSurfaceColor),
        title: TextField(
          controller: _searchCtrl,
          autofocus: true,
          onChanged: _search,
          style: GoogleFonts.dmSans(fontSize: 15, color: onSurfaceColor),
          decoration: InputDecoration(
            hintText: 'Search students, staff, notices...',
            hintStyle: GoogleFonts.dmSans(fontSize: 15, color: mutedColor),
            border: InputBorder.none,
            filled: false,
          ),
        ),
        actions: [
          if (_searchCtrl.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close_rounded, color: onSurfaceColor),
              onPressed: () {
                _searchCtrl.clear();
                _search('');
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelStyle: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 12),
          labelColor: context.appTheme.primary,
          unselectedLabelColor: mutedColor,
          indicatorColor: context.appTheme.primary,
          tabs: [
            Tab(text: 'All${_totalResults > 0 ? ' ($_totalResults)' : ''}'),
            Tab(
              text:
                  'Students${_studentResults.isNotEmpty ? ' (${_studentResults.length})' : ''}',
            ),
            Tab(
              text:
                  'Staff${_staffResults.isNotEmpty ? ' (${_staffResults.length})' : ''}',
            ),
            Tab(
              text:
                  'Notices${_noticeResults.isNotEmpty ? ' (${_noticeResults.length})' : ''}',
            ),
          ],
        ),
      ),
      body: SchoolDeskRepositoryStateView<Object>(
        state: _state,
        onRetry: () => _searchServer(_searchCtrl.text),
        data: (_) => _searchCtrl.text.isEmpty
            ? _buildEmptyState(onSurfaceColor, mutedColor, outlineColor)
            : _state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildAllResults(
                    surfaceColor,
                    onSurfaceColor,
                    mutedColor,
                    outlineColor,
                  ),
                  _buildResultList(
                    _studentResults,
                    surfaceColor,
                    onSurfaceColor,
                    mutedColor,
                    outlineColor,
                  ),
                  _buildResultList(
                    _staffResults,
                    surfaceColor,
                    onSurfaceColor,
                    mutedColor,
                    outlineColor,
                  ),
                  _buildResultList(
                    _noticeResults,
                    surfaceColor,
                    onSurfaceColor,
                    mutedColor,
                    outlineColor,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState(
    Color onSurfaceColor,
    Color mutedColor,
    Color outlineColor,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, size: 64, color: outlineColor),
          const SizedBox(height: 16),
          Text(
            'Search across your school',
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: onSurfaceColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Find students, staff, and notices instantly',
            style: GoogleFonts.dmSans(fontSize: 13, color: mutedColor),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildSuggestionChip('Class 5A'),
              _buildSuggestionChip('Mathematics'),
              _buildSuggestionChip('Annual Day'),
              _buildSuggestionChip('Fee Notice'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String label) {
    return GestureDetector(
      onTap: () {
        _searchCtrl.text = label;
        _search(label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: context.appTheme.primaryContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: context.appTheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildAllResults(
    Color surfaceColor,
    Color onSurfaceColor,
    Color mutedColor,
    Color outlineColor,
  ) {
    if (_totalResults == 0) {
      return _buildNoResults(mutedColor);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_studentResults.isNotEmpty) ...[
          _buildCategoryHeader('Students', _studentResults.length, mutedColor),
          ..._studentResults
              .take(3)
              .map(
                (r) => _buildResultCard(
                  r,
                  surfaceColor,
                  onSurfaceColor,
                  mutedColor,
                  outlineColor,
                ),
              ),
          if (_studentResults.length > 3)
            _buildShowMoreButton('students', _studentResults.length),
          const SizedBox(height: 16),
        ],
        if (_staffResults.isNotEmpty) ...[
          _buildCategoryHeader('Staff', _staffResults.length, mutedColor),
          ..._staffResults
              .take(3)
              .map(
                (r) => _buildResultCard(
                  r,
                  surfaceColor,
                  onSurfaceColor,
                  mutedColor,
                  outlineColor,
                ),
              ),
          if (_staffResults.length > 3)
            _buildShowMoreButton('staff', _staffResults.length),
          const SizedBox(height: 16),
        ],
        if (_noticeResults.isNotEmpty) ...[
          _buildCategoryHeader('Notices', _noticeResults.length, mutedColor),
          ..._noticeResults
              .take(3)
              .map(
                (r) => _buildResultCard(
                  r,
                  surfaceColor,
                  onSurfaceColor,
                  mutedColor,
                  outlineColor,
                ),
              ),
          if (_noticeResults.length > 3)
            _buildShowMoreButton('notices', _noticeResults.length),
        ],
      ],
    );
  }

  Widget _buildResultList(
    List<_SearchResult> results,
    Color surfaceColor,
    Color onSurfaceColor,
    Color mutedColor,
    Color outlineColor,
  ) {
    if (results.isEmpty) return _buildNoResults(mutedColor);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildResultCard(
        results[i],
        surfaceColor,
        onSurfaceColor,
        mutedColor,
        outlineColor,
      ),
    );
  }

  Widget _buildResultCard(
    _SearchResult result,
    Color surfaceColor,
    Color onSurfaceColor,
    Color mutedColor,
    Color outlineColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: outlineColor),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: result.color.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(result.icon, color: result.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.title,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: onSurfaceColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  result.subtitle,
                  style: GoogleFonts.dmSans(fontSize: 12, color: mutedColor),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: result.color.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              result.type[0].toUpperCase() + result.type.substring(1),
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: result.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title, int count, Color mutedColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: mutedColor,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: context.appTheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: context.appTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShowMoreButton(String type, int total) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: TextButton(
        onPressed: () {
          final tabIndex = type == 'students'
              ? 1
              : type == 'staff'
              ? 2
              : 3;
          _tabController.animateTo(tabIndex);
        },
        child: Text(
          'View all $total $type →',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            color: context.appTheme.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildNoResults(Color mutedColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: mutedColor),
          const SizedBox(height: 12),
          Text(
            'No results found',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: mutedColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different search term',
            style: GoogleFonts.dmSans(fontSize: 13, color: mutedColor),
          ),
        ],
      ),
    );
  }
}

class _SearchResult {
  final String type;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Map<String, dynamic> data;

  const _SearchResult({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.data,
  });
}
