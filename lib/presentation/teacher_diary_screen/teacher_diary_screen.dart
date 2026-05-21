import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend_api_client.dart';
import '../../services/role_access_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/teacher_navigation.dart';

class TeacherDiaryScreen extends StatefulWidget {
  const TeacherDiaryScreen({super.key});

  @override
  State<TeacherDiaryScreen> createState() => _TeacherDiaryScreenState();
}

class _TeacherDiaryScreenState extends State<TeacherDiaryScreen>
    with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedNavIndex = 13;
  late TabController _tabController;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _entries = [];
  String _filterClass = 'All';

  static const _headerColor = Color(0xFF1A5276);
  // Teacher diary only shows entries for their assigned class
  late final List<String> _classes;
  late final String _assignedClass;

  @override
  void initState() {
    super.initState();
    _assignedClass = RoleAccessService.teacherClassName;
    _classes = ['All', _assignedClass];
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await BackendApiClient.instance.getRawList('/diary-entries');
      if (!mounted) return;
      setState(() {
        _entries = rows.map(_mapDiaryEntryFromApi).toList();
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
      'class': e['class'] ?? e['class_name'] ?? _assignedClass,
      'subject': e['subject'] ?? RoleAccessService.teacherSubject,
      'title': e['title'] ?? '',
      'classwork': e['classwork'] ?? '',
      'homework': e['homework'] ?? '',
      'notes': e['notes'] ?? '',
      'schedule': e['schedule'] ?? '',
      'type': e['type'] ?? 'regular',
      'createdBy': e['created_by'] ?? RoleAccessService.teacherName,
    };
  }

  Future<void> _persistEntry(Map<String, dynamic> entry, bool isEdit) async {
    final entryDate = DateTime.tryParse('${entry['date']}') ?? DateTime.now();
    final payload = {
      'date': entryDate.toUtc().toIso8601String(),
      'class': entry['class'],
      'subject': entry['subject'],
      'title': entry['title'],
      'classwork': entry['classwork'],
      'homework': entry['homework'],
      'notes': entry['notes'],
      'schedule': entry['schedule'],
      'type': entry['type'],
      'teacher_id': RoleAccessService.teacherStaffId,
      'created_by': RoleAccessService.teacherName,
    };
    if (isEdit && entry['id'] != null) {
      await BackendApiClient.instance.updateRaw(
        '/diary-entries/${entry['id']}',
        payload,
      );
    } else {
      await BackendApiClient.instance.createRaw('/diary-entries', payload);
    }
    await _loadData();
  }

  List<Map<String, dynamic>> get _filteredEntries {
    return _entries.where((e) {
        final matchClass = _filterClass == 'All' || e['class'] == _filterClass;
        return matchClass;
      }).toList()
      ..sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
  }

  Future<void> _showAddEntrySheet({Map<String, dynamic>? existing}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _DiaryEntryInputPage(
          existing: existing,
          assignedClass: _assignedClass,
          onSave: _persistEntry,
        ),
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existing == null ? 'Diary entry saved' : 'Diary entry updated',
        ),
        backgroundColor: AppTheme.success,
      ),
    );
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

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.background,
      drawer: TeacherDrawer(
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
      ),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.white),
            tooltip: 'New Entry',
            onPressed: () => _showAddEntrySheet(),
          ),
        ],
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
            Tab(text: 'All Entries'),
            Tab(text: 'Today'),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DashboardFabWidget(role: DashboardRole.teacher),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.edit_note_rounded),
            label: Text(
              'New Entry',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
            ),
            onPressed: () => _showAddEntrySheet(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter bar
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.filter_list_rounded,
                  size: 18,
                  color: AppTheme.muted,
                ),
                const SizedBox(width: 8),
                Text(
                  'Class:',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppTheme.muted,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _classes.map((c) {
                        final sel = _filterClass == c;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: GestureDetector(
                            onTap: () => setState(() => _filterClass = c),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppTheme.primary
                                    : AppTheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                c,
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
              children: [
                _buildEntriesList(_filteredEntries),
                _buildEntriesList(
                  _filteredEntries.where((e) {
                    final today = DateTime.now();
                    final fmt =
                        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
                    return e['date'] == fmt;
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntriesList(List<Map<String, dynamic>> entries) {
    if (entries.isEmpty) {
      return Center(
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
              'No diary entries found',
              style: GoogleFonts.dmSans(fontSize: 15, color: AppTheme.muted),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap + to create a new entry',
              style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.muted),
            ),
          ],
        ),
      );
    }

    // Group by date
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final e in entries) {
      final d = e['date'] as String? ?? '';
      grouped.putIfAbsent(d, () => []).add(e);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDates.length,
      itemBuilder: (ctx, i) {
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
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppTheme.primary
                          : AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isToday ? 'Today — $dateLabel' : dateLabel,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isToday
                            ? Colors.white
                            : AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
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
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _typeBg(type),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _typeColor(type).withAlpha(30),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _typeColor(type).withAlpha(80)),
                  ),
                  child: Text(
                    (entry['class'] as String? ?? ''),
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _typeColor(type),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(60),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    entry['subject'] as String? ?? '',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _typeColor(type),
                    ),
                  ),
                ),
                const Spacer(),
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
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: _typeColor(type),
                  ),
                  onSelected: (v) {
                    if (v == 'edit') _showAddEntrySheet(existing: entry);
                    if (v == 'delete') _deleteEntry(entry['id'] as String);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry['title'] as String? ?? '',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
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
                    'Notes',
                    entry['notes'] as String,
                    color: AppTheme.muted,
                  ),
                ],
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
        Icon(icon, size: 15, color: color),
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

  Future<void> _deleteEntry(String id) async {
    await BackendApiClient.instance.deleteRaw('/diary-entries/$id');
    await _loadData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Entry deleted'),
        backgroundColor: AppTheme.error,
      ),
    );
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

class _DiaryEntryInputPage extends StatefulWidget {
  const _DiaryEntryInputPage({
    required this.existing,
    required this.assignedClass,
    required this.onSave,
  });

  final Map<String, dynamic>? existing;
  final String assignedClass;
  final Future<void> Function(Map<String, dynamic> entry, bool isEdit) onSave;

  @override
  State<_DiaryEntryInputPage> createState() => _DiaryEntryInputPageState();
}

class _DiaryEntryInputPageState extends State<_DiaryEntryInputPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _classworkCtrl;
  late final TextEditingController _homeworkCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _scheduleCtrl;
  late String _selectedClass;
  late String _selectedSubject;
  late String _selectedType;
  late DateTime _entryDate;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    _classworkCtrl = TextEditingController(text: existing?['classwork'] ?? '');
    _homeworkCtrl = TextEditingController(text: existing?['homework'] ?? '');
    _notesCtrl = TextEditingController(text: existing?['notes'] ?? '');
    _scheduleCtrl = TextEditingController(text: existing?['schedule'] ?? '');
    _selectedClass = existing?['class'] ?? widget.assignedClass;
    _selectedSubject = existing?['subject'] ?? RoleAccessService.teacherSubject;
    _selectedType = existing?['type'] ?? 'regular';
    _entryDate = _isEdit
        ? DateTime.tryParse(existing?['date'] ?? '') ?? DateTime.now()
        : DateTime.now();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _classworkCtrl.dispose();
    _homeworkCtrl.dispose();
    _notesCtrl.dispose();
    _scheduleCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_classworkCtrl.text.trim().isEmpty &&
        _homeworkCtrl.text.trim().isEmpty &&
        _notesCtrl.text.trim().isEmpty &&
        _scheduleCtrl.text.trim().isEmpty) {
      setState(() {
        _error = 'Add classwork, homework, notes, or schedule details.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final entryId = _isEdit
        ? widget.existing!['id']
        : DateTime.now().millisecondsSinceEpoch.toString();
    final entry = {
      'id': entryId,
      'date': fmt(_entryDate),
      'class': _selectedClass,
      'subject': _selectedSubject,
      'title': _titleCtrl.text.trim(),
      'classwork': _classworkCtrl.text.trim(),
      'homework': _homeworkCtrl.text.trim(),
      'notes': _notesCtrl.text.trim(),
      'schedule': _scheduleCtrl.text.trim(),
      'type': _selectedType,
      'createdBy': RoleAccessService.teacherName,
    };
    try {
      await widget.onSave(entry, _isEdit);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Unable to save diary entry: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final subjects = RoleAccessService.teacherClassSubjects;
    final types = ['regular', 'exam', 'event', 'holiday'];
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Diary Entry' : 'New Diary Entry'),
        backgroundColor: _TeacherDiaryScreenState._headerColor,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _sectionLabel('Date'),
            InkWell(
              onTap: _saving
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _entryDate,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => _entryDate = picked);
                      }
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.outline),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${_entryDate.day}/${_entryDate.month}/${_entryDate.year}',
                      style: GoogleFonts.dmSans(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedClass,
                    decoration: _inputDecoration('Class'),
                    items: [widget.assignedClass]
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _selectedClass = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSubject,
                    decoration: _inputDecoration('Subject'),
                    items: subjects
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _selectedSubject = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _sectionLabel('Entry Title'),
            _textField(
              _titleCtrl,
              'e.g. Chapter 5 - Fractions',
              required: true,
            ),
            const SizedBox(height: 14),
            _sectionLabel('Entry Type'),
            Wrap(
              spacing: 8,
              children: types.map((t) {
                final selected = _selectedType == t;
                return ChoiceChip(
                  label: Text(t[0].toUpperCase() + t.substring(1)),
                  selected: selected,
                  selectedColor: AppTheme.primaryContainer,
                  labelStyle: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: selected
                        ? AppTheme.primary
                        : AppTheme.onSurfaceVariant,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  onSelected: _saving
                      ? null
                      : (_) => setState(() => _selectedType = t),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            _sectionLabel('Classwork Done'),
            _textField(
              _classworkCtrl,
              'What was covered in class today...',
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            _sectionLabel('Homework Assigned'),
            _textField(
              _homeworkCtrl,
              'Homework details and due date...',
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            _sectionLabel('Teacher Notes'),
            _textField(
              _notesCtrl,
              'Observations, student performance notes...',
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            _sectionLabel('Schedule / Upcoming'),
            _textField(
              _scheduleCtrl,
              'Tests, events, extra classes scheduled...',
              maxLines: 2,
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: GoogleFonts.dmSans(color: AppTheme.error, fontSize: 13),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? 'Update Entry' : 'Save Entry'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    labelText: hint,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
  );

  Widget _textField(
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
    bool required = false,
  }) => TextFormField(
    controller: ctrl,
    enabled: !_saving,
    maxLines: maxLines,
    style: GoogleFonts.dmSans(fontSize: 14),
    decoration: _inputDecoration(hint),
    validator: required
        ? (value) => (value == null || value.trim().isEmpty) ? 'Required' : null
        : null,
  );

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      label,
      style: GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.onSurface,
      ),
    ),
  );
}
