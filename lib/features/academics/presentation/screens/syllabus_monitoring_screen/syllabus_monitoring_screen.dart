import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/backend_data_service.dart';

class SyllabusMonitoringScreen extends StatefulWidget {
  const SyllabusMonitoringScreen({super.key});

  @override
  State<SyllabusMonitoringScreen> createState() =>
      _SyllabusMonitoringScreenState();
}

class _SyllabusMonitoringScreenState extends State<SyllabusMonitoringScreen>
    with SingleTickerProviderStateMixin {
  int _selectedDrawerIndex = 5;
  late TabController _tabController;
  String _selectedClass = 'All';
  bool _isLoading = true;
  String? _loadError;

  List<Map<String, dynamic>> _syllabusData = [];
  BackendDataService? _storage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      _storage = await BackendDataService.getInstance();
      final syllabusData = await _storage!.getList(
        BackendDataService.kSyllabusData,
      );
      if (!mounted) return;
      setState(() {
        _syllabusData = syllabusData;
        _loadError = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Unable to load syllabus records';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredData {
    if (_selectedClass == 'All') return _syllabusData;
    return _syllabusData
        .where(
          (d) =>
              _textValue(d['class'], fallback: 'Unassigned') == _selectedClass,
        )
        .toList();
  }

  List<String> get _classFilters {
    const preferred = [
      '1-A',
      '1-B',
      '2-A',
      '2-B',
      '3-A',
      '3-B',
      '4-A',
      '4-B',
      '5-A',
      '5-B',
      '6-A',
      '6-B',
      '7-A',
      '7-B',
      '8-A',
      '8-B',
      '9-A',
      '9-B',
      '10-A',
      '10-B',
    ];
    final runtimeClasses = _syllabusData
        .map((d) => _textValue(d['class'], fallback: 'Unassigned'))
        .where((value) => value.trim().isNotEmpty)
        .toSet();
    final ordered = [
      'All',
      ...preferred,
      ...runtimeClasses.where((value) => !preferred.contains(value)).toList()
        ..sort(),
    ];
    return ordered;
  }

  @override
  Widget build(BuildContext context) {
    return SchoolDeskModuleScaffold(
      title: 'Syllabus Records',
      subtitle: 'Track completion, alerts, and class-wise curriculum readiness',
      drawer: PrincipalDrawer(
        selectedIndex: _selectedDrawerIndex,
        onDestinationSelected: (i) => setState(() => _selectedDrawerIndex = i),
      ),
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.principal,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      bottom: _buildTopTabs(),
      body: MediaQuery.of(context).size.width >= 840
          ? _buildTabletLayout(context)
          : _buildPhoneLayout(context),
    );
  }

  Widget _buildPhoneLayout(BuildContext context) {
    return TabBarView(
      controller: _tabController,
      children: [_buildProgressTab(), _buildAlertsTab(), _buildReportsTab()],
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return TabBarView(
      controller: _tabController,
      children: [_buildProgressTab(), _buildAlertsTab(), _buildReportsTab()],
    );
  }

  PreferredSizeWidget _buildTopTabs() {
    return TabBar(
      controller: _tabController,
      tabs: const [
        Tab(text: 'Progress'),
        Tab(text: 'Alerts'),
        Tab(text: 'Reports'),
      ],
    );
  }

  Widget _buildProgressTab() {
    return Column(
      children: [
        _buildClassFilterBar(),
        Expanded(child: _buildProgressContent()),
      ],
    );
  }

  Widget _buildClassFilterBar() {
    final classes = _classFilters;
    return Material(
      color: AppTheme.surface,
      elevation: 1,
      shadowColor: AppTheme.outlineVariant.withAlpha(80),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppTheme.outlineVariant, width: 1),
          ),
        ),
        child: SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: classes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => _buildClassChip(classes[i]),
          ),
        ),
      ),
    );
  }

  Widget _buildClassChip(String classValue) {
    final selected = _selectedClass == classValue;
    return FilterChip(
      label: Text(classValue),
      selected: selected,
      showCheckmark: selected,
      checkmarkColor: AppTheme.onPrimary,
      selectedColor: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      side: BorderSide(
        color: selected ? AppTheme.primary : AppTheme.outlineVariant,
        width: 1.2,
      ),
      labelStyle: GoogleFonts.dmSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: selected ? AppTheme.onPrimary : AppTheme.onSurfaceVariant,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onSelected: (_) => setState(() => _selectedClass = classValue),
    );
  }

  Widget _buildProgressContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return _buildStateMessage(
        icon: Icons.cloud_off_rounded,
        title: _loadError!,
        body: 'Check the backend connection, then retry this module.',
      );
    }
    if (_syllabusData.isEmpty) {
      return _buildStateMessage(
        icon: Icons.menu_book_outlined,
        title: 'No syllabus records yet',
        body:
            'Curriculum records from the backend will appear here with progress, alerts, and reports.',
      );
    }
    if (_filteredData.isEmpty) {
      return _buildStateMessage(
        icon: Icons.filter_alt_off_rounded,
        title: 'No records for $_selectedClass',
        body: 'Choose another class filter or add curriculum for this class.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: _filteredData.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _buildSyllabusCard(_filteredData[i], i),
    );
  }

  Widget _buildSyllabusCard(Map<String, dynamic> d, int dataIndex) {
    Color statusColor;
    String statusLabel;
    final status = _statusValue(d);
    switch (status) {
      case 'on_track':
        statusColor = AppTheme.success;
        statusLabel = 'On Track';
        break;
      case 'delayed':
        statusColor = AppTheme.warning;
        statusLabel = 'Delayed';
        break;
      default:
        statusColor = AppTheme.error;
        statusLabel = 'Critical';
    }

    final totalTopics = _totalTopics(d);
    final completed = _completedTopics(d);
    final inProgress = _inProgressTopics(d);
    final pending = _pendingTopics(d);
    final completion = totalTopics <= 0 ? 0.0 : completed / totalTopics;
    final subject = _subjectLabel(d);
    final className = _textValue(d['class'], fallback: 'Unassigned');
    final teacher = _textValue(d['teacher'], fallback: 'Teacher not assigned');
    final targetDate = _dateLabel(
      d['targetDate'] ?? d['target_date'] ?? d['updated_at'],
    );

    return GestureDetector(
      onTap: () => _showTopicDetails(d, dataIndex),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: d['status'] == 'critical'
                ? AppTheme.error.withAlpha(80)
                : AppTheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$subject — Class $className',
                        style: GoogleFonts.dmSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      Text(
                        teacher,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: completion,
                minHeight: 8,
                backgroundColor: AppTheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildTopicChip('Done: $completed', AppTheme.success),
                const SizedBox(width: 8),
                _buildTopicChip('Active: $inProgress', AppTheme.info),
                const SizedBox(width: 8),
                _buildTopicChip('Pending: $pending', AppTheme.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Target: $targetDate',
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      color: AppTheme.muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showTopicDetails(d, dataIndex),
                  icon: const Icon(Icons.list_alt_rounded, size: 14),
                  label: const Text('View Topics'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ),
                if (d['status'] != 'on_track') ...[
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: () => _sendReminder(d),
                    icon: const Icon(Icons.notifications_outlined, size: 14),
                    label: const Text('Remind'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      foregroundColor: statusColor,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  void _sendReminder(Map<String, dynamic> d) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Reminder sent to ${_textValue(d['teacher'], fallback: 'the assigned teacher')} for ${_subjectLabel(d)} — Class ${_textValue(d['class'], fallback: 'Unassigned')}',
        ),
        backgroundColor: AppTheme.warning,
      ),
    );
  }

  Widget _buildAlertsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return _buildStateMessage(
        icon: Icons.cloud_off_rounded,
        title: _loadError!,
        body: 'Alerts need live syllabus data from the backend.',
      );
    }
    final delayed = _syllabusData
        .where((d) => _statusValue(d) == 'delayed')
        .toList();
    final critical = _syllabusData
        .where((d) => _statusValue(d) == 'critical')
        .toList();
    final onTrack = _syllabusData
        .where((d) => _statusValue(d) == 'on_track')
        .toList();

    if (_syllabusData.isEmpty) {
      return _buildStateMessage(
        icon: Icons.notifications_none_rounded,
        title: 'No syllabus alerts',
        body:
            'Alerts will appear when curriculum progress records are present.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        if (critical.isNotEmpty) ...[
          _buildAlertHeader(
            '🔴 Critical — Immediate Action Required',
            AppTheme.error,
          ),
          const SizedBox(height: 8),
          ...critical.asMap().entries.map(
            (e) => _buildAlertItem(
              e.value,
              AppTheme.error,
              AppTheme.errorContainer,
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (delayed.isNotEmpty) ...[
          _buildAlertHeader('🟡 Delayed — Needs Attention', AppTheme.warning),
          const SizedBox(height: 8),
          ...delayed.asMap().entries.map(
            (e) => _buildAlertItem(
              e.value,
              AppTheme.warning,
              AppTheme.warningContainer,
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (onTrack.isNotEmpty) ...[
          _buildAlertHeader('On Track', AppTheme.success),
          const SizedBox(height: 8),
          ...onTrack.map(
            (d) =>
                _buildAlertItem(d, AppTheme.success, AppTheme.successContainer),
          ),
        ],
      ],
    );
  }

  Widget _buildAlertHeader(String title, Color color) {
    return Text(
      title,
      style: GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }

  Widget _buildAlertItem(Map<String, dynamic> d, Color color, Color bgColor) {
    final totalTopics = _totalTopics(d);
    final completion = totalTopics <= 0
        ? '0'
        : ((_completedTopics(d) / totalTopics) * 100).toStringAsFixed(0);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_subjectLabel(d)} — Class ${_textValue(d['class'], fallback: 'Unassigned')}',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${_textValue(d['teacher'], fallback: 'Teacher not assigned')} · $completion% done · Target: ${_dateLabel(d['targetDate'] ?? d['target_date'] ?? d['updated_at'])}',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          if (d['status'] != 'on_track')
            TextButton(
              onPressed: () => _sendReminder(d),
              child: Text(
                'Remind',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReportsTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return _buildStateMessage(
        icon: Icons.cloud_off_rounded,
        title: _loadError!,
        body: 'Reports need live syllabus data from the backend.',
      );
    }
    final teacherRows = _syllabusData.map((d) {
      final total = _totalTopics(d).toDouble();
      final completed = _completedTopics(d).toDouble();
      final percent = total <= 0 ? 0 : ((completed / total) * 100).round();
      return {
        'teacher': _textValue(d['teacher'], fallback: 'Teacher not assigned'),
        'subject': _subjectLabel(d),
        'percent': percent,
        'class': _textValue(d['class'], fallback: 'Unassigned'),
      };
    }).toList();
    final avg = teacherRows.isEmpty
        ? 0
        : (teacherRows.fold<int>(
                    0,
                    (sum, row) => sum + (row['percent'] as int),
                  ) /
                  teacherRows.length)
              .round();
    final onTrack = teacherRows
        .where((row) => (row['percent'] as int) >= 80)
        .length;
    final delayed = teacherRows.where((row) {
      final percent = row['percent'] as int;
      return percent >= 60 && percent < 80;
    }).length;
    final critical = teacherRows
        .where((row) => (row['percent'] as int) < 60)
        .length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Teacher-wise Syllabus Progress',
          style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (teacherRows.isEmpty)
          _buildStateMessage(
            icon: Icons.bar_chart_rounded,
            title: 'No backend syllabus records',
            body: 'Reports will appear after curriculum records are available.',
            compact: true,
          )
        else
          ...teacherRows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildTeacherReport(
                row['teacher'] as String,
                row['subject'] as String,
                row['percent'] as int,
                row['class'] as String,
              ),
            ),
          ),
        const SizedBox(height: 20),
        Text(
          'Overall School Syllabus Completion',
          style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Average Completion',
                    style: GoogleFonts.dmSans(fontSize: 13),
                  ),
                  Text(
                    '$avg%',
                    style: GoogleFonts.dmSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: avg / 100,
                  minHeight: 12,
                  backgroundColor: AppTheme.surfaceVariant,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('On Track', '$onTrack', AppTheme.success),
                  _buildStatItem('Delayed', '$delayed', AppTheme.warning),
                  _buildStatItem('Critical', '$critical', AppTheme.error),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _requestSyllabusReportExport,
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Export Full Report'),
          ),
        ),
      ],
    );
  }

  Future<void> _requestSyllabusReportExport() async {
    try {
      final export = await BackendApiClient.instance.createReportExport(
        '/reports/exports',
        reportTitle: 'Syllabus progress report',
        format: 'pdf',
        reportType: 'syllabus',
        scope: 'principal',
        parameters: {
          'module': 'syllabus',
          'class_filter': _selectedClass,
          'record_count': _filteredData.length,
          'month': DateFormat('yyyy-MM').format(DateTime.now()),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Syllabus progress report export ${export['status'] ?? 'requested'}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Syllabus report export failed: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Widget _buildTeacherReport(
    String name,
    String subject,
    int percent,
    String classes,
  ) {
    Color color = percent >= 80
        ? AppTheme.success
        : percent >= 60
        ? AppTheme.warning
        : AppTheme.error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$percent%',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$subject · $classes',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent / 100,
                minHeight: 6,
                backgroundColor: AppTheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.dmSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
        ),
      ],
    );
  }

  void _showTopicDetails(Map<String, dynamic> d, int dataIndex) {
    final topics = _topicsFor(d);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          builder: (_, ctrl) => SingleChildScrollView(
            controller: ctrl,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${_subjectLabel(d)} — Class ${_textValue(d['class'], fallback: 'Unassigned')}',
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _textValue(d['teacher'], fallback: 'Teacher not assigned'),
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppTheme.muted,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Topic-wise Progress',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                if (topics.isEmpty)
                  _buildStateMessage(
                    icon: Icons.playlist_add_check_rounded,
                    title: 'Topic details not available',
                    body:
                        'This backend curriculum record has subjects but no topic-level progress yet.',
                    compact: true,
                  )
                else
                  ...topics.asMap().entries.map(
                    (e) => _buildTopicRow(
                      e.value,
                      e.key,
                      d,
                      dataIndex,
                      setModalState,
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _sendReminder(d);
                    },
                    icon: const Icon(Icons.notifications_outlined, size: 16),
                    label: const Text('Send Reminder to Teacher'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopicRow(
    Map<String, dynamic> t,
    int topicIndex,
    Map<String, dynamic> d,
    int dataIndex,
    StateSetter setModalState,
  ) {
    Color color;
    IconData icon;
    switch (t['status']) {
      case 'completed':
        color = AppTheme.success;
        icon = Icons.check_circle_rounded;
        break;
      case 'in_progress':
        color = AppTheme.info;
        icon = Icons.pending_rounded;
        break;
      default:
        color = AppTheme.muted;
        icon = Icons.radio_button_unchecked_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              final topics = _topicsFor(d);
              if (topics.isEmpty || topicIndex >= topics.length) return;
              final currentStatus = topics[topicIndex]['status'];
              String nextStatus;
              if (currentStatus == 'pending') {
                nextStatus = 'in_progress';
              } else if (currentStatus == 'in_progress') {
                nextStatus = 'completed';
              } else {
                nextStatus = 'pending';
              }

              setModalState(() => topics[topicIndex]['status'] = nextStatus);
              setState(() {
                final idx = _syllabusData.indexWhere(
                  (s) =>
                      s['class'] == d['class'] && s['subject'] == d['subject'],
                );
                if (idx >= 0) {
                  final allTopics = _topicsFor(_syllabusData[idx]);
                  if (allTopics.isEmpty || topicIndex >= allTopics.length) {
                    return;
                  }
                  allTopics[topicIndex]['status'] = nextStatus;
                  _syllabusData[idx]['topics'] = allTopics;
                  _syllabusData[idx]['completed'] = allTopics
                      .where((t) => t['status'] == 'completed')
                      .length;
                  _syllabusData[idx]['inProgress'] = allTopics
                      .where((t) => t['status'] == 'in_progress')
                      .length;
                  _syllabusData[idx]['pending'] = allTopics
                      .where((t) => t['status'] == 'pending')
                      .length;
                }
              });
            },
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _textValue(t['name'], fallback: 'Untitled topic'),
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: AppTheme.onSurface,
              ),
            ),
          ),
          Text(
            _textValue(t['date'], fallback: ''),
            style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildStateMessage({
    required IconData icon,
    required String title,
    required String body,
    bool compact = false,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 12 : 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 44 : 56,
                height: compact ? 44 : 56,
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primary,
                  size: compact ? 22 : 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: compact ? 13 : 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: compact ? 11 : 13,
                  color: AppTheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusValue(Map<String, dynamic> row) {
    final explicit = _textValue(row['status']).toLowerCase();
    if (explicit == 'on_track' ||
        explicit == 'delayed' ||
        explicit == 'critical') {
      return explicit;
    }
    final total = _totalTopics(row);
    if (total <= 0) return 'critical';
    final ratio = _completedTopics(row) / total;
    if (ratio >= 0.8) return 'on_track';
    if (ratio >= 0.6) return 'delayed';
    return 'critical';
  }

  int _totalTopics(Map<String, dynamic> row) {
    final explicit = _intValue(row['totalTopics'] ?? row['total_topics']);
    if (explicit > 0) return explicit;
    final topics = _topicsFor(row);
    if (topics.isNotEmpty) return topics.length;
    final subjects = row['subjects'];
    if (subjects is List && subjects.isNotEmpty) return subjects.length;
    return 0;
  }

  int _completedTopics(Map<String, dynamic> row) {
    final explicit = _intValue(row['completed']);
    if (explicit > 0) return explicit;
    return _topicsFor(row).where((t) => t['status'] == 'completed').length;
  }

  int _inProgressTopics(Map<String, dynamic> row) {
    final explicit = _intValue(row['inProgress'] ?? row['in_progress']);
    if (explicit > 0) return explicit;
    return _topicsFor(row).where((t) => t['status'] == 'in_progress').length;
  }

  int _pendingTopics(Map<String, dynamic> row) {
    final explicit = _intValue(row['pending']);
    if (explicit > 0) return explicit;
    final total = _totalTopics(row);
    final pending = total - _completedTopics(row) - _inProgressTopics(row);
    return pending < 0 ? 0 : pending;
  }

  List<Map<String, dynamic>> _topicsFor(Map<String, dynamic> row) {
    final topics = row['topics'];
    if (topics is List) {
      return topics
          .whereType<Map>()
          .map((topic) => Map<String, dynamic>.from(topic))
          .toList();
    }
    return const [];
  }

  String _subjectLabel(Map<String, dynamic> row) {
    final subject = _textValue(row['subject']);
    if (subject.isNotEmpty) return subject;
    final subjects = row['subjects'];
    if (subjects is List && subjects.isNotEmpty) {
      return subjects.map((value) => '$value').join(', ');
    }
    return 'Subject not set';
  }

  String _dateLabel(Object? value) {
    final raw = _textValue(value);
    if (raw.isEmpty) return 'Not scheduled';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('d MMM yyyy').format(parsed.toLocal());
  }

  int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _textValue(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}
