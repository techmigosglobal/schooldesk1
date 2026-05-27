import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend_api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/parent_navigation.dart';

class ParentDiaryScreen extends StatefulWidget {
  const ParentDiaryScreen({super.key});

  @override
  State<ParentDiaryScreen> createState() => _ParentDiaryScreenState();
}

class _ParentDiaryScreenState extends State<ParentDiaryScreen>
    with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedNavIndex = 13;
  late TabController _tabController;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _entries = [];
  int _activeChildIndex = 0;
  String _filterSubject = 'All';

  // Pagination for All Entries tab
  static const int _diaryPageSize = 10;
  int _diaryPage = 0;
  bool _diaryLoadingMore = false;
  bool _diaryHasMore = true;
  List<Map<String, dynamic>> _displayedEntries = [];
  final ScrollController _allEntriesScrollCtrl = ScrollController();

  static const _headerColor = Color(0xFF1A6B4A);

  List<Map<String, dynamic>> _children = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _allEntriesScrollCtrl.addListener(_onAllEntriesScroll);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _allEntriesScrollCtrl.dispose();
    super.dispose();
  }

  void _onAllEntriesScroll() {
    if (_allEntriesScrollCtrl.position.pixels >=
        _allEntriesScrollCtrl.position.maxScrollExtent - 200) {
      _loadMoreDiaryEntries();
    }
  }

  void _loadMoreDiaryEntries() {
    if (_diaryLoadingMore || !_diaryHasMore) return;
    final allFiltered = _filteredEntries;
    final start = (_diaryPage + 1) * _diaryPageSize;
    if (start >= allFiltered.length) {
      setState(() => _diaryHasMore = false);
      return;
    }
    setState(() => _diaryLoadingMore = true);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final end = (start + _diaryPageSize).clamp(0, allFiltered.length);
      setState(() {
        _displayedEntries.addAll(allFiltered.sublist(start, end));
        _diaryPage++;
        _diaryLoadingMore = false;
        _diaryHasMore = end < allFiltered.length;
      });
    });
  }

  void _resetDiaryPagination() {
    final allFiltered = _filteredEntries;
    _diaryPage = 0;
    _diaryLoadingMore = false;
    _diaryHasMore = allFiltered.length > _diaryPageSize;
    _displayedEntries = allFiltered.take(_diaryPageSize).toList();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final children = await BackendApiClient.instance.getMyStudents();
      if (_activeChildIndex >= children.length) _activeChildIndex = 0;
      final rows = <Map<String, dynamic>>[];
      for (final child in children) {
        final studentId = '${child['id'] ?? child['student_id'] ?? ''}';
        if (studentId.isEmpty) continue;
        final childRows = await BackendApiClient.instance.getRawList(
          '/diary-entries',
          queryParameters: {'student_id': studentId},
        );
        rows.addAll(childRows.map((row) => {...row, 'student_id': studentId}));
      }
      if (!mounted) return;
      setState(() {
        _children = children;
        _entries = rows.map(_mapDiaryEntryFromApi).toList();
        _resetDiaryPagination();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load diary entries from the server.';
        _loading = false;
      });
    }
  }

  Map<String, dynamic> _mapDiaryEntryFromApi(Map<String, dynamic> e) {
    final entryDate = DateTime.tryParse('${e['date'] ?? ''}');
    final date = entryDate == null
        ? '${e['date'] ?? ''}'
        : '${entryDate.year}-${entryDate.month.toString().padLeft(2, '0')}-${entryDate.day.toString().padLeft(2, '0')}';
    return {
      'id': e['id'],
      'date': date,
      'class': e['class'] ?? e['class_name'] ?? '',
      'subject': e['subject'] ?? '',
      'title': e['title'] ?? '',
      'classwork': e['classwork'] ?? '',
      'homework': e['homework'] ?? '',
      'notes': e['notes'] ?? '',
      'schedule': e['schedule'] ?? '',
      'type': e['type'] ?? 'regular',
      // Backend integration: show the author only when the diary API provides it.
      'createdBy': e['created_by'] ?? e['teacher_name'] ?? '',
      'student_id': e['student_id'] ?? '',
    };
  }

  List<String> get _subjects {
    if (_children.isEmpty) return const ['All'];
    final studentId = '${_children[_activeChildIndex]['id'] ?? ''}';
    final subs = _entries
        .where((e) => e['student_id'] == studentId)
        .map((e) => e['subject'] as String? ?? '')
        .toSet()
        .toList();
    subs.sort();
    return ['All', ...subs];
  }

  List<Map<String, dynamic>> get _filteredEntries {
    if (_children.isEmpty) return const [];
    final studentId = '${_children[_activeChildIndex]['id'] ?? ''}';
    return _entries.where((e) {
        final matchClass = e['student_id'] == studentId;
        final matchSubject =
            _filterSubject == 'All' || e['subject'] == _filterSubject;
        return matchClass && matchSubject;
      }).toList()
      ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
  }

  List<Map<String, dynamic>> get _todayEntries {
    final today = DateTime.now();
    final fmt =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return _filteredEntries.where((e) => e['date'] == fmt).toList();
  }

  List<Map<String, dynamic>> get _pendingHomework {
    return _filteredEntries
        .where((e) => (e['homework'] as String? ?? '').isNotEmpty)
        .take(5)
        .toList();
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'exam':
        return AppTheme.error;
      case 'event':
        return AppTheme.secondary;
      case 'holiday':
        return AppTheme.accent;
      default:
        return AppTheme.primary;
    }
  }

  Color _typeBg(String type) {
    switch (type) {
      case 'exam':
        return AppTheme.errorContainer;
      case 'event':
        return AppTheme.secondaryContainer;
      case 'holiday':
        return AppTheme.successContainer;
      default:
        return AppTheme.primaryContainer;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Class Diary')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_children.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Class Diary')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No linked students. Ask the school admin to link students to this parent account.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.background,
      drawer: ParentDrawer(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      appBar: AppBar(
        backgroundColor: _headerColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          'Class Diary',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: "Today's Diary"),
            Tab(text: 'All Entries'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Child selector
          Container(
            color: _headerColor,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: List.generate(_children.length, (i) {
                final sel = _activeChildIndex == i;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _activeChildIndex = i;
                      _filterSubject = 'All';
                      _resetDiaryPagination();
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: sel ? Colors.white : Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: sel
                              ? Colors.white
                              : Colors.white.withAlpha(60),
                        ),
                      ),
                      child: Text(
                        _childLabel(_children[i]),
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: sel ? _headerColor : Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          // Subject filter
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.subject_rounded,
                  size: 16,
                  color: AppTheme.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _subjects.map((s) {
                        final sel = _filterSubject == s;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _filterSubject = s;
                              _resetDiaryPagination();
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: sel
                                    ? _headerColor
                                    : AppTheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                s,
                                style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: sel
                                      ? Colors.white
                                      : AppTheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildTodayTab(), _buildAllEntriesTab()],
            ),
          ),
        ],
      ),
    );
  }

  String _childLabel(Map<String, dynamic> child) {
    final explicitName = '${child['name'] ?? ''}'.trim();
    final name = explicitName.isNotEmpty
        ? explicitName
        : '${child['first_name'] ?? ''} ${child['last_name'] ?? ''}'.trim();
    final className =
        '${child['class'] ?? child['class_name'] ?? child['current_section_id'] ?? ''}'
            .trim();
    return className.isEmpty ? name : '$name ($className)';
  }

  Widget _buildTodayTab() {
    final todayEntries = _todayEntries;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A6B4A), Color(0xFF27AE60)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.menu_book_rounded,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Class Diary",
                        style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${todayEntries.length} subject${todayEntries.length != 1 ? 's' : ''} updated by teachers',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _childLabel(_children[_activeChildIndex]).split(' ').first,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (todayEntries.isEmpty)
            _emptyState(
              "No diary entries for today yet",
              "Check back after school hours",
            )
          else ...[
            Text(
              "Today's Entries",
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            ...todayEntries.map((e) => _buildEntryCard(e)),
          ],
          // Pending homework section
          if (_pendingHomework.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.assignment_late_outlined,
                  size: 18,
                  color: AppTheme.error,
                ),
                const SizedBox(width: 6),
                Text(
                  'Recent Homework',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._pendingHomework.map((e) => _buildHomeworkCard(e)),
          ],
        ],
      ),
    );
  }

  Widget _buildAllEntriesTab() {
    if (_displayedEntries.isEmpty && _filteredEntries.isEmpty) {
      return _emptyState(
        'No diary entries found',
        'Entries will appear here once teachers add them',
      );
    }

    // Group displayed entries by date
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final e in _displayedEntries) {
      final d = e['date'] as String? ?? '';
      grouped.putIfAbsent(d, () => []).add(e);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final totalItems =
        sortedDates.length + (_diaryHasMore || _diaryLoadingMore ? 1 : 0);

    return ListView.builder(
      controller: _allEntriesScrollCtrl,
      padding: const EdgeInsets.all(16),
      itemCount: totalItems,
      itemBuilder: (ctx, i) {
        if (i == sortedDates.length) {
          return _diaryLoadingMore
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _diaryHasMore
              ? TextButton(
                  onPressed: _loadMoreDiaryEntries,
                  child: const Text('Load more entries'),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'All ${_filteredEntries.length} entries loaded',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppTheme.muted,
                      ),
                    ),
                  ),
                );
        }

        final date = sortedDates[i];
        final dayEntries = grouped[date]!;
        final parsedDate = DateTime.tryParse(date);
        final today = DateTime.now();
        final isToday =
            parsedDate != null &&
            parsedDate.year == today.year &&
            parsedDate.month == today.month &&
            parsedDate.day == today.day;
        final dateLabel = parsedDate != null
            ? '${_weekday(parsedDate.weekday)}, ${parsedDate.day} ${_month(parsedDate.month)} ${parsedDate.year}'
            : date;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isToday ? _headerColor : AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isToday ? 'Today — $dateLabel' : dateLabel,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isToday ? Colors.white : AppTheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            ...dayEntries.map((entry) => _buildEntryCard(entry)),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildEntryCard(Map<String, dynamic> entry) {
    final type = entry['type'] as String? ?? 'regular';
    final subject = (entry['subject'] as String? ?? '').trim();
    final title = (entry['title'] as String? ?? '').trim();
    final createdBy = (entry['createdBy'] as String? ?? '').trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _typeBg(type),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _subjectIcon(entry['subject'] as String? ?? ''),
                  size: 18,
                  color: _typeColor(type),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    subject.isEmpty ? 'Diary entry' : subject,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _typeColor(type),
                    ),
                  ),
                ),
                if (type != 'regular')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _typeColor(type),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      type[0].toUpperCase() + type.substring(1),
                      style: GoogleFonts.dmSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface,
                    ),
                  ),
                if ((entry['classwork'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _infoRow(
                    Icons.class_outlined,
                    'Classwork',
                    entry['classwork'] as String,
                  ),
                ],
                if ((entry['homework'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _infoRow(
                    Icons.assignment_outlined,
                    'Homework',
                    entry['homework'] as String,
                    color: AppTheme.error,
                  ),
                ],
                if ((entry['schedule'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _infoRow(
                    Icons.event_outlined,
                    'Schedule',
                    entry['schedule'] as String,
                    color: AppTheme.secondary,
                  ),
                ],
                if ((entry['notes'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _infoRow(
                    Icons.sticky_note_2_outlined,
                    'Teacher Note',
                    entry['notes'] as String,
                    color: AppTheme.muted,
                  ),
                ],
                if (createdBy.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 13,
                        color: AppTheme.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        createdBy,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeworkCard(Map<String, dynamic> entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.error.withAlpha(40)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.assignment_outlined,
            size: 18,
            color: AppTheme.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry['subject'] as String? ?? '',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.error,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry['homework'] as String? ?? '',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Color color = AppTheme.primary,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 56,
              color: AppTheme.muted.withAlpha(100),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.muted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.muted),
            ),
          ],
        ),
      ),
    );
  }

  IconData _subjectIcon(String subject) {
    switch (subject.toLowerCase()) {
      case 'mathematics':
        return Icons.calculate_outlined;
      case 'science':
        return Icons.science_outlined;
      case 'english':
        return Icons.menu_book_outlined;
      case 'hindi':
        return Icons.translate_outlined;
      case 'social studies':
        return Icons.public_outlined;
      case 'computer':
        return Icons.computer_outlined;
      case 'art':
        return Icons.palette_outlined;
      case 'physical education':
        return Icons.sports_outlined;
      default:
        return Icons.book_outlined;
    }
  }

  String _weekday(int d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(d - 1).clamp(0, 6)];
  }

  String _month(int m) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[(m - 1).clamp(0, 11)];
  }
}
