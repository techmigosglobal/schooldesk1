import 'package:flutter/material.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/app_navigation.dart';
import 'package:schooldesk1/routes/app_routes.dart';

enum _PrincipalExamView {
  home,
  examinations,
  examDetails,
  schedule,
  results,
  resultDetails,
  subjectResults,
  studentResult,
  gradeSetup,
  reports,
}

enum _ExamStatusFilter { all, upcoming, ongoing, completed }

enum _ResultStatusFilter { all, published, draft, notPublished }

class PrincipalExamReviewScreen extends StatefulWidget {
  final _PrincipalExamView _initialView;

  const PrincipalExamReviewScreen.examsHome({super.key})
    : _initialView = _PrincipalExamView.home;

  const PrincipalExamReviewScreen.results({super.key})
    : _initialView = _PrincipalExamView.results;

  @override
  State<PrincipalExamReviewScreen> createState() =>
      _PrincipalExamReviewScreenState();
}

class _PrincipalExamReviewScreenState extends State<PrincipalExamReviewScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _history = <_PrincipalExamView>[];

  bool _loading = true;
  bool _saving = false;
  bool _studentMarksLoading = false;
  String? _error;
  String? _studentMarksError;
  String _search = '';
  String _scheduleClassFilter = 'All';
  _ExamStatusFilter _examFilter = _ExamStatusFilter.all;
  _ResultStatusFilter _resultFilter = _ResultStatusFilter.all;
  _PrincipalExamView _view = _PrincipalExamView.home;

  Map<String, dynamic> _examData = {};
  Map<String, dynamic> _resultData = {};
  List<Map<String, dynamic>> _gradingScale = [];
  List<Map<String, dynamic>> _reportCards = [];
  List<Map<String, dynamic>> _studentMarks = [];
  Map<String, dynamic>? _selectedExam;
  Map<String, dynamic>? _selectedStudent;
  int _selectedReportIndex = 0;

  @override
  void initState() {
    super.initState();
    _view = widget._initialView;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = BackendApiClient.instance;
      final responses = await Future.wait<Object>([
        api.getPrincipalExamsOverview(),
        api.getPrincipalResultsOverview(),
        api.getRawList('/exams/grading-scale'),
        api.getRawList('/exams/report-cards'),
      ]);
      if (!mounted) return;
      setState(() {
        _examData = _map(responses[0]);
        _resultData = _map(responses[1]);
        _gradingScale = _list(responses[2]);
        _reportCards = _list(responses[3]);
        _selectedExam = _reselectExam(_selectedExam);
        _selectedStudent = _reselectStudent(_selectedStudent);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load exam information from backend. $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF7FAFF),
      drawer: PrincipalDrawer(selectedIndex: 6, onDestinationSelected: (_) {}),
      bottomNavigationBar: const PrincipalShellBottomBar(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.primary,
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return _ExamPage(
        header: _buildHeader('Exams', 'View and manage exam information'),
        children: const [
          SizedBox(height: 220),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_error != null) {
      return _ExamPage(
        header: _buildHeader('Exams', 'View and manage exam information'),
        children: [
          const SizedBox(height: 100),
          _ExamEmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Exams unavailable',
            message: _error!,
            actionLabel: 'Retry',
            onAction: _loadData,
          ),
        ],
      );
    }

    return switch (_view) {
      _PrincipalExamView.home => _buildHomeView(),
      _PrincipalExamView.examinations => _buildExaminationsView(),
      _PrincipalExamView.examDetails => _buildExamDetailsView(),
      _PrincipalExamView.schedule => _buildScheduleView(),
      _PrincipalExamView.results => _buildResultsView(),
      _PrincipalExamView.resultDetails => _buildResultDetailsView(),
      _PrincipalExamView.subjectResults => _buildSubjectResultsView(),
      _PrincipalExamView.studentResult => _buildStudentResultView(),
      _PrincipalExamView.gradeSetup => _buildGradeSetupView(),
      _PrincipalExamView.reports => _buildReportsView(),
    };
  }

  Widget _buildHomeView() {
    return _ExamPage(
      header: _buildHeader(
        'Exams',
        'View and manage exam information',
        trailing: IconButton(
          tooltip: 'Filter exams',
          icon: const Icon(Icons.filter_alt_outlined),
          onPressed: _openExamFilterSheet,
        ),
      ),
      children: [
        _ExamMetricGrid(
          children: [
            _ExamMetricTile(
              label: 'Total Exams',
              value: '${_examRows.length}',
              icon: Icons.assignment_outlined,
              color: const Color(0xFF2563EB),
            ),
            _ExamMetricTile(
              label: 'Upcoming',
              value: '${_int(_examSummary['upcoming_exams'])}',
              icon: Icons.upcoming_outlined,
              color: const Color(0xFF16A34A),
            ),
            _ExamMetricTile(
              label: 'Completed',
              value: '${_int(_examSummary['completed_exams'])}',
              icon: Icons.verified_outlined,
              color: const Color(0xFF10B981),
            ),
            _ExamMetricTile(
              label: 'Total Subjects',
              value: '$_totalSubjects',
              icon: Icons.groups_outlined,
              color: const Color(0xFFF59E0B),
            ),
            _ExamMetricTile(
              label: 'Total Students',
              value: '$_totalStudents',
              icon: Icons.people_alt_outlined,
              color: const Color(0xFFF97316),
            ),
            _ExamMetricTile(
              label: 'Results Published',
              value: '$_publishedResults',
              icon: Icons.workspace_premium_outlined,
              color: const Color(0xFFEC4899),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _ExamSectionTitle('Quick Actions'),
        const SizedBox(height: 8),
        _ExamActionRow(
          icon: Icons.fact_check_outlined,
          iconColor: const Color(0xFF2563EB),
          title: 'Examination List',
          subtitle: 'View all examinations',
          onTap: () => _goTo(_PrincipalExamView.examinations),
        ),
        _ExamActionRow(
          icon: Icons.calendar_month_outlined,
          iconColor: const Color(0xFF2563EB),
          title: 'Exam Schedule',
          subtitle: 'View exam timetable',
          onTap: () => _goTo(_PrincipalExamView.schedule),
        ),
        _ExamActionRow(
          icon: Icons.workspace_premium_outlined,
          iconColor: const Color(0xFF16A34A),
          title: 'Results',
          subtitle: 'View published results',
          onTap: () => _goTo(_PrincipalExamView.results),
        ),
        _ExamActionRow(
          icon: Icons.grading_outlined,
          iconColor: const Color(0xFFEC4899),
          title: 'Grade Setup',
          subtitle: 'View grading system',
          onTap: () => _goTo(_PrincipalExamView.gradeSetup),
        ),
        _ExamActionRow(
          icon: Icons.bar_chart_outlined,
          iconColor: const Color(0xFF7C3AED),
          title: 'Reports',
          subtitle: 'View exam reports and analytics',
          onTap: () => _goTo(_PrincipalExamView.reports),
        ),
        const SizedBox(height: 10),
        const _ExamInfoBanner(
          icon: Icons.info_outline_rounded,
          message:
              'Teachers prepare syllabus, schedules, marks, and report cards. Principal reviews and publishes them for parent visibility.',
        ),
      ],
    );
  }

  Widget _buildExaminationsView() {
    final rows = _filteredExamRows;
    return _ExamPage(
      header: _buildHeader('Examinations', 'View all examinations'),
      children: [
        _ExamSearchBox(
          hint: 'Search examinations',
          onChanged: (value) => setState(() => _search = value),
        ),
        const SizedBox(height: 12),
        _ExamFilterChips(
          labels: const ['All', 'Upcoming', 'Ongoing', 'Completed'],
          selectedIndex: _examFilter.index,
          onSelected: (index) =>
              setState(() => _examFilter = _ExamStatusFilter.values[index]),
        ),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          const _ExamEmptyState(
            icon: Icons.assignment_outlined,
            title: 'No examinations found',
            message:
                'Backend exam rows will appear here once teachers add them.',
          )
        else
          for (final row in rows)
            _ExamListCard(
              exam: row,
              onTap: () {
                _selectedExam = row;
                _goTo(_PrincipalExamView.examDetails);
              },
            ),
      ],
    );
  }

  Widget _buildExamDetailsView() {
    final exam = _currentExam;
    if (exam == null) {
      return _emptyPage(
        title: 'Exam Details',
        subtitle: 'No exam selected',
        icon: Icons.assignment_outlined,
        message: 'Open an examination from the list to review details.',
      );
    }
    final schedules = _list(exam['schedule_details']);
    return _ExamPage(
      header: _buildHeader(
        'Exam Details',
        _examTitle(exam),
        trailing: IconButton(
          tooltip: 'Open Classes Hub',
          icon: const Icon(Icons.edit_outlined),
          onPressed: _openClassesHubForExams,
        ),
      ),
      children: [
        _ExamCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _ExamIconBadge(
                    icon: Icons.fact_check_outlined,
                    color: Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _examTitle(exam),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _ExamStatusPill(
                    label: _examStatusLabel(exam),
                    color: _statusColor(_text(exam['status'])),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ExamMiniMetricGrid(
                children: [
                  _ExamMiniMetric(
                    label: 'Academic Year',
                    value: _text(exam['academic_year'], fallback: '-'),
                    icon: Icons.calendar_today_outlined,
                    color: const Color(0xFF2563EB),
                  ),
                  _ExamMiniMetric(
                    label: 'Total Subjects',
                    value: '${_int(exam['subjects_assigned'])}',
                    icon: Icons.menu_book_outlined,
                    color: const Color(0xFF7C3AED),
                  ),
                  _ExamMiniMetric(
                    label: 'Classes',
                    value: '${_int(exam['classes_assigned'])}',
                    icon: Icons.groups_outlined,
                    color: const Color(0xFFF59E0B),
                  ),
                  _ExamMiniMetric(
                    label: 'Published',
                    value: _isPublished(exam) ? 'Yes' : 'No',
                    icon: Icons.publish_outlined,
                    color: const Color(0xFF16A34A),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ExamKeyValueRow(
                label: 'Date',
                value:
                    '${_displayDate(exam['start_date'])} - ${_displayDate(exam['end_date'])}',
              ),
              _ExamKeyValueRow(
                label: 'Evaluation',
                value:
                    '${_percentText(exam['evaluation_percent'])} | ${_text(exam['evaluation_status'], fallback: 'Pending')}',
              ),
            ],
          ),
        ),
        _ExamSectionHeader(
          title: 'Subjects (${schedules.length})',
          actionLabel: 'View Schedule',
          onAction: () => _goTo(_PrincipalExamView.schedule),
        ),
        if (schedules.isEmpty)
          const _ExamInfoBanner(
            icon: Icons.pending_actions_outlined,
            message:
                'No subject-wise schedule has been submitted yet. Teachers will add syllabus and schedules before Principal review.',
          )
        else
          for (final schedule in schedules.take(12))
            _ExamScheduleTile(schedule: schedule),
        const SizedBox(height: 10),
        _ExamPrimaryButton(
          label: _isPublished(exam)
              ? 'Exam Timetable Published'
              : 'Publish Exam Timetable',
          icon: Icons.publish_outlined,
          onPressed: _isPublished(exam) || _saving
              ? null
              : () => _publishExamTimetable(exam),
        ),
        const SizedBox(height: 10),
        _ExamOutlineButton(
          label: 'Go to Classes Hub',
          icon: Icons.grid_view_outlined,
          onPressed: _openClassesHubForExams,
        ),
      ],
    );
  }

  Widget _buildScheduleView() {
    final exam = _currentExam;
    final rows = _filteredScheduleRows;
    final filters = _scheduleClassFilters;
    return _ExamPage(
      header: _buildHeader(
        'Exam Schedule',
        exam == null ? 'View exam timetable' : _examTitle(exam),
        trailing: IconButton(
          tooltip: 'Export schedule',
          icon: const Icon(Icons.calendar_month_outlined),
          onPressed: exam == null || _saving
              ? null
              : () => _exportSchedule(exam),
        ),
      ),
      children: [
        if (exam != null)
          _ExamCard(
            child: Row(
              children: [
                const _ExamIconBadge(
                  icon: Icons.calendar_month_outlined,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_displayDate(exam['start_date'])} - ${_displayDate(exam['end_date'])}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Duration: ${_durationDays(exam)} Days',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_list(exam['schedule_details']).length}\nTotal Subjects',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        if (filters.length > 1) ...[
          const SizedBox(height: 4),
          _ExamFilterChips(
            labels: filters,
            selectedIndex: filters
                .indexOf(_scheduleClassFilter)
                .clamp(0, filters.length - 1),
            onSelected: (index) {
              setState(() => _scheduleClassFilter = filters[index]);
            },
          ),
          const SizedBox(height: 12),
        ],
        if (rows.isEmpty)
          const _ExamEmptyState(
            icon: Icons.calendar_month_outlined,
            title: 'No schedule rows',
            message: 'Teacher-created schedule rows will appear here.',
          )
        else
          _ExamCard(
            child: Column(
              children: [
                const _ExamScheduleHeaderRow(),
                const Divider(height: 18),
                for (final row in rows) _ExamScheduleTableRow(row: row),
              ],
            ),
          ),
        const _ExamInfoBanner(
          icon: Icons.info_outline_rounded,
          message: 'Timings are shown from backend schedule rows only.',
        ),
        const SizedBox(height: 10),
        _ExamOutlineButton(
          label: 'Export Schedule',
          icon: Icons.download_outlined,
          onPressed: exam == null || _saving
              ? null
              : () => _exportSchedule(exam),
        ),
      ],
    );
  }

  Widget _buildResultsView() {
    final rows = _filteredResultRows;
    return _ExamPage(
      header: _buildHeader(
        'Results',
        'View published results',
        trailing: IconButton(
          tooltip: 'Filter results',
          icon: const Icon(Icons.filter_alt_outlined),
          onPressed: _openResultFilterSheet,
        ),
      ),
      children: [
        _ExamSearchBox(
          hint: 'Search results',
          onChanged: (value) => setState(() => _search = value),
        ),
        const SizedBox(height: 12),
        _ExamFilterChips(
          labels: const ['All', 'Published', 'Draft', 'Not Published'],
          selectedIndex: _resultFilter.index,
          onSelected: (index) =>
              setState(() => _resultFilter = _ResultStatusFilter.values[index]),
        ),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          const _ExamEmptyState(
            icon: Icons.workspace_premium_outlined,
            title: 'No result rows',
            message: 'Published and draft results will appear here.',
          )
        else
          for (final row in rows)
            _ExamResultCard(
              exam: row,
              onTap: () {
                _selectedExam = row;
                _goTo(_PrincipalExamView.resultDetails);
              },
            ),
      ],
    );
  }

  Widget _buildResultDetailsView() {
    final exam = _currentExam;
    if (exam == null) {
      return _emptyPage(
        title: 'Result Details',
        subtitle: 'No exam selected',
        icon: Icons.workspace_premium_outlined,
        message: 'Open a result row to review summary details.',
      );
    }
    final cards = _reportCardsForExam(exam);
    final passed = cards.where((row) => _num(row['percentage']) >= 40).length;
    final failed = cards.length - passed;
    final passPercentage = cards.isEmpty
        ? _num(_resultSummary['pass_percentage'])
        : (passed / cards.length) * 100;
    return _ExamPage(
      header: _buildHeader(
        'Result Details',
        _examTitle(exam),
        trailing: IconButton(
          tooltip: 'Export marksheet',
          icon: const Icon(Icons.file_download_outlined),
          onPressed: _saving ? null : () => _exportResultSummary(exam),
        ),
      ),
      children: [
        _ExamCard(
          child: Column(
            children: [
              Row(
                children: [
                  const _ExamIconBadge(
                    icon: Icons.assignment_turned_in_outlined,
                    color: Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ExamStatusPill(
                          label: _isPublished(exam)
                              ? 'Published'
                              : 'Not Published',
                          color: _isPublished(exam)
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFF59E0B),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _examTitle(exam),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _ExamMiniMetricGrid(
                children: [
                  _ExamMiniMetric(
                    label: 'Total Subjects',
                    value: '${_int(exam['subjects_assigned'])}',
                    icon: Icons.menu_book_outlined,
                    color: const Color(0xFF7C3AED),
                  ),
                  _ExamMiniMetric(
                    label: 'Total Students',
                    value: '${cards.length}',
                    icon: Icons.groups_outlined,
                    color: const Color(0xFF16A34A),
                  ),
                  _ExamMiniMetric(
                    label: 'Pass Percentage',
                    value: '${passPercentage.round()}%',
                    icon: Icons.percent_outlined,
                    color: const Color(0xFF2563EB),
                  ),
                  _ExamMiniMetric(
                    label: 'Students Failed',
                    value: '$failed',
                    icon: Icons.warning_amber_outlined,
                    color: const Color(0xFFF97316),
                  ),
                ],
              ),
            ],
          ),
        ),
        const _ExamSectionTitle('Summary'),
        const SizedBox(height: 8),
        _ExamCard(
          child: Column(
            children: [
              _ExamKeyValueRow(label: 'Students Passed', value: '$passed'),
              _ExamKeyValueRow(label: 'Students Failed', value: '$failed'),
              _ExamKeyValueRow(
                label: 'Pass Percentage',
                value: '${passPercentage.round()}%',
              ),
            ],
          ),
        ),
        _ExamOutlineButton(
          label: 'View Subject Wise Results',
          icon: Icons.bar_chart_outlined,
          onPressed: () => _goTo(_PrincipalExamView.subjectResults),
        ),
        const SizedBox(height: 14),
        _ExamSectionHeader(
          title: 'Student Results',
          actionLabel: 'Publish',
          onAction: _isPublished(exam) || _saving
              ? null
              : () => _publishResults(exam),
        ),
        if (cards.isEmpty)
          const _ExamInfoBanner(
            icon: Icons.pending_actions_outlined,
            message:
                'No report cards are available yet. Teachers will complete marks and reports first.',
          )
        else
          for (final card in cards.take(10))
            _ExamStudentResultTile(
              row: card,
              onTap: () => _openStudentResult(card),
            ),
        if (_isPublished(exam))
          _ExamOutlineButton(
            label: 'Hold Results',
            icon: Icons.pause_circle_outline_rounded,
            onPressed: _saving ? null : () => _holdResults(exam),
          ),
      ],
    );
  }

  Widget _buildSubjectResultsView() {
    final rows = _list(
      _map(_resultData['result_dashboard'])['subject_wise_analysis'],
    );
    return _ExamPage(
      header: _buildHeader(
        'Subject Wise Results',
        _currentExam == null
            ? 'View subject analysis'
            : _examTitle(_currentExam!),
        trailing: IconButton(
          tooltip: 'Filter subjects',
          icon: const Icon(Icons.filter_alt_outlined),
          onPressed: () =>
              _snack('Subject analysis is loaded from backend aggregates.'),
        ),
      ),
      children: [
        const _ExamFilterChips(
          labels: ['All Subjects'],
          selectedIndex: 0,
          onSelected: _noopIndex,
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const _ExamEmptyState(
            icon: Icons.bar_chart_outlined,
            title: 'No subject analysis',
            message:
                'Subject-wise results will appear after marks are entered.',
          )
        else
          for (final row in rows)
            _ExamCard(
              child: Row(
                children: [
                  const _ExamIconBadge(
                    icon: Icons.menu_book_outlined,
                    color: Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _text(row['subject_name'], fallback: 'Subject'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_int(row['marks_recorded'])} marks recorded',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppTheme.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _percentText(row['average_percent']),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _text(row['analysis_status'], fallback: 'Live'),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _buildStudentResultView() {
    final student = _selectedStudent;
    if (student == null) {
      return _emptyPage(
        title: 'Student Result',
        subtitle: 'No student selected',
        icon: Icons.person_search_outlined,
        message: 'Open a student result from Result Details.',
      );
    }
    final exam = _examForStudent(student) ?? _currentExam;
    final totalMax = _totalMaxMarks(exam);
    final obtained = _num(student['total_obtained']);
    final percentage = _num(student['percentage']);
    final passed = percentage >= 40;
    return _ExamPage(
      header: _buildHeader(
        'Student Result',
        '${_studentName(student)} - ${_studentClass(student)}',
        trailing: IconButton(
          tooltip: 'Download marksheet',
          icon: const Icon(Icons.file_download_outlined),
          onPressed: _saving ? null : () => _exportStudentMarksheet(student),
        ),
      ),
      children: [
        _ExamCard(
          child: Column(
            children: [
              Row(
                children: [
                  _ExamAvatar(label: _studentName(student)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _studentName(student),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _studentClass(student),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ExamStatusPill(
                    label: passed ? 'Passed' : 'Needs Review',
                    color: passed
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFF97316),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ExamMiniMetricGrid(
                children: [
                  _ExamMiniMetric(
                    label: 'Total Marks',
                    value: totalMax <= 0 ? '-' : '$totalMax',
                    icon: Icons.assignment_outlined,
                    color: const Color(0xFF2563EB),
                  ),
                  _ExamMiniMetric(
                    label: 'Obtained Marks',
                    value: _numberText(obtained),
                    icon: Icons.fact_check_outlined,
                    color: const Color(0xFF16A34A),
                  ),
                  _ExamMiniMetric(
                    label: 'Percentage',
                    value: '${percentage.toStringAsFixed(1)}%',
                    icon: Icons.percent_outlined,
                    color: const Color(0xFFF59E0B),
                  ),
                  _ExamMiniMetric(
                    label: 'Grade',
                    value: _text(student['overall_grade'], fallback: '-'),
                    icon: Icons.workspace_premium_outlined,
                    color: const Color(0xFF7C3AED),
                  ),
                ],
              ),
            ],
          ),
        ),
        const _ExamSectionTitle('Subject Wise Marks'),
        const SizedBox(height: 8),
        if (_studentMarksLoading)
          const _ExamCard(child: Center(child: CircularProgressIndicator()))
        else if (_studentMarksError != null)
          _ExamEmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Marks unavailable',
            message: _studentMarksError!,
            actionLabel: 'Retry',
            onAction: () => _loadStudentMarks(student),
          )
        else if (_studentMarks.isEmpty)
          const _ExamInfoBanner(
            icon: Icons.pending_actions_outlined,
            message:
                'No subject marks are available yet for this student and exam.',
          )
        else
          _ExamCard(
            child: Column(
              children: [
                const _ExamMarksHeaderRow(),
                const Divider(height: 18),
                for (final mark in _studentMarks) _ExamMarksRow(row: mark),
              ],
            ),
          ),
        const SizedBox(height: 10),
        _ExamOutlineButton(
          label: 'Download Marksheet',
          icon: Icons.download_outlined,
          onPressed: _saving ? null : () => _exportStudentMarksheet(student),
        ),
      ],
    );
  }

  Widget _buildGradeSetupView() {
    return _ExamPage(
      header: _buildHeader(
        'Grade Setup',
        'View grading system',
        trailing: IconButton(
          tooltip: 'Open Classes Hub',
          icon: const Icon(Icons.edit_outlined),
          onPressed: _openClassesHubForExams,
        ),
      ),
      children: [
        const _ExamFilterChips(
          labels: ['Grade Scale', 'Grade Points'],
          selectedIndex: 0,
          onSelected: _noopIndex,
        ),
        const SizedBox(height: 12),
        if (_gradingScale.isEmpty)
          const _ExamEmptyState(
            icon: Icons.grading_outlined,
            title: 'No grade scale',
            message: 'Grade settings will appear here after setup.',
          )
        else
          _ExamCard(
            child: Column(
              children: [
                const _ExamGradeHeaderRow(),
                const Divider(height: 18),
                for (final row in _gradingScale) _ExamGradeRow(row: row),
              ],
            ),
          ),
        const _ExamInfoBanner(
          icon: Icons.info_outline_rounded,
          message:
              'Grade settings are managed from Classes Hub -> Step 5 (Exams).',
        ),
        const SizedBox(height: 10),
        _ExamOutlineButton(
          label: 'Go to Classes Hub',
          icon: Icons.grid_view_outlined,
          onPressed: _openClassesHubForExams,
        ),
      ],
    );
  }

  Widget _buildReportsView() {
    final reports = _reportOptions;
    if (_selectedReportIndex >= reports.length) _selectedReportIndex = 0;
    return _ExamPage(
      header: _buildHeader(
        'Exam Reports',
        'View exam reports and analytics',
        trailing: IconButton(
          tooltip: 'Filter reports',
          icon: const Icon(Icons.filter_alt_outlined),
          onPressed: () =>
              _snack('Report exports use published backend results.'),
        ),
      ),
      children: [
        const _ExamSectionTitle('Select Report Type'),
        const SizedBox(height: 8),
        if (reports.isEmpty)
          const _ExamEmptyState(
            icon: Icons.bar_chart_outlined,
            title: 'No report options',
            message: 'Backend report options will appear here.',
          )
        else
          for (var index = 0; index < reports.length; index++)
            _ExamReportOptionTile(
              row: reports[index],
              selected: index == _selectedReportIndex,
              onTap: () => setState(() => _selectedReportIndex = index),
            ),
        const SizedBox(height: 8),
        const _ExamInfoBanner(
          icon: Icons.info_outline_rounded,
          message: 'Reports are based on published results only.',
        ),
        const SizedBox(height: 10),
        _ExamPrimaryButton(
          label: 'Generate Report',
          icon: Icons.file_download_outlined,
          onPressed: reports.isEmpty || _saving
              ? null
              : _generateSelectedReport,
        ),
      ],
    );
  }

  Widget _emptyPage({
    required String title,
    required String subtitle,
    required IconData icon,
    required String message,
  }) {
    return _ExamPage(
      header: _buildHeader(title, subtitle),
      children: [
        const SizedBox(height: 80),
        _ExamEmptyState(icon: icon, title: title, message: message),
      ],
    );
  }

  _ExamHeader _buildHeader(String title, String subtitle, {Widget? trailing}) {
    final canGoBack = _history.isNotEmpty;
    return _ExamHeader(
      title: title,
      subtitle: subtitle,
      leadingIcon: canGoBack ? Icons.arrow_back_rounded : Icons.menu_rounded,
      onLeading: canGoBack
          ? _goBack
          : () => _scaffoldKey.currentState?.openDrawer(),
      trailing:
          trailing ??
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
    );
  }

  void _goTo(_PrincipalExamView view) {
    if (_view == view) return;
    setState(() {
      _history.add(_view);
      _view = view;
      _search = '';
      if (view != _PrincipalExamView.schedule) _scheduleClassFilter = 'All';
    });
  }

  void _goBack() {
    if (_history.isEmpty) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _view = _history.removeLast();
      _search = '';
    });
  }

  void _openClassesHubForExams() {
    final exam = _currentExam;
    final firstSchedule = _list(exam?['schedule_details']).firstOrNull;
    Navigator.pushNamed(
      context,
      AppRoutes.principalClasses,
      arguments: {
        'class_hub_action': 'exams',
        'action': 'exams',
        'selectedStep': 'exam_setup',
        if (_text(firstSchedule?['grade_id']).isNotEmpty)
          'grade_id': _text(firstSchedule?['grade_id']),
        if (_text(firstSchedule?['grade_id']).isNotEmpty)
          'classId': _text(firstSchedule?['grade_id']),
        if (_text(firstSchedule?['section_id']).isNotEmpty)
          'section_id': _text(firstSchedule?['section_id']),
        if (_text(firstSchedule?['section_id']).isNotEmpty)
          'sectionId': _text(firstSchedule?['section_id']),
        'source': 'principal_exams',
      },
    );
  }

  Future<void> _publishExamTimetable(Map<String, dynamic> exam) async {
    final examId = _text(exam['exam_id'] ?? exam['id']);
    if (examId.isEmpty) {
      _snack('Backend exam ID is missing.');
      return;
    }
    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.createPrincipalExamAction(
        actionType: 'publish_exam_timetable',
        title: 'Publish exam timetable',
        message:
            'Principal reviewed the teacher-prepared exam timetable and approved it for visibility.',
        priority: 'high',
        examId: examId,
      );
      await _loadData();
      if (!mounted) return;
      _snack('Exam timetable published.', success: true);
    } catch (error) {
      if (!mounted) return;
      _snack('Unable to publish exam timetable: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _publishResults(Map<String, dynamic> exam) async {
    final examId = _text(exam['exam_id'] ?? exam['id']);
    if (examId.isEmpty) {
      _snack('Backend exam ID is missing.');
      return;
    }
    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.createPrincipalResultAction(
        actionType: 'publish_results',
        title: 'Publish results',
        message:
            'Principal reviewed teacher-submitted report cards and published results for parent visibility.',
        priority: 'high',
        examId: examId,
      );
      await _loadData();
      if (!mounted) return;
      _snack('Results published.', success: true);
    } catch (error) {
      if (!mounted) return;
      _snack('Unable to publish results: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _holdResults(Map<String, dynamic> exam) async {
    final examId = _text(exam['exam_id'] ?? exam['id']);
    if (examId.isEmpty) {
      _snack('Backend exam ID is missing.');
      return;
    }
    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.createPrincipalResultAction(
        actionType: 'hold_results',
        title: 'Hold results',
        message:
            'Principal held the current result publication pending teacher review.',
        priority: 'high',
        examId: examId,
      );
      await _loadData();
      if (!mounted) return;
      _snack('Results moved to hold.', success: true);
    } catch (error) {
      if (!mounted) return;
      _snack('Unable to hold results: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportSchedule(Map<String, dynamic> exam) async {
    await _createExport(
      path: '/exams/report-cards/exports',
      title: '${_examTitle(exam)} Schedule',
      reportType: 'exam_schedule',
      format: 'pdf',
      parameters: {
        'exam_id': _text(exam['exam_id'] ?? exam['id']),
        'source': 'principal_exams',
      },
      successMessage: 'Exam schedule export queued.',
    );
  }

  Future<void> _exportResultSummary(Map<String, dynamic> exam) async {
    await _createExport(
      path: '/exams/report-cards/exports',
      title: '${_examTitle(exam)} Result Summary',
      reportType: 'result_summary',
      format: 'pdf',
      parameters: {
        'exam_id': _text(exam['exam_id'] ?? exam['id']),
        'source': 'principal_results',
      },
      successMessage: 'Result summary export queued.',
    );
  }

  Future<void> _exportStudentMarksheet(Map<String, dynamic> student) async {
    await _createExport(
      path: '/exams/report-cards/exports',
      title: '${_studentName(student)} Marksheet',
      reportType: 'student_marksheet',
      format: 'pdf',
      parameters: {
        'exam_id': _text(student['exam_id']),
        'student_id': _text(student['student_id']),
        'source': 'principal_student_result',
      },
      successMessage: 'Student marksheet export queued.',
    );
  }

  Future<void> _generateSelectedReport() async {
    final reports = _reportOptions;
    if (reports.isEmpty) return;
    final row = reports[_selectedReportIndex.clamp(0, reports.length - 1)];
    final route = _text(row['route'], fallback: '/exams/report-cards/exports');
    await _createExport(
      path: route.startsWith('/') ? route : '/exams/report-cards/exports',
      title: _text(row['label'], fallback: 'Exam Report'),
      reportType: _text(row['report_type'], fallback: 'exam_report'),
      format: _text(row['format'], fallback: 'pdf'),
      parameters: {'published_only': true, 'source': 'principal_exam_reports'},
      successMessage: '${_text(row['label'], fallback: 'Exam report')} queued.',
    );
  }

  Future<void> _createExport({
    required String path,
    required String title,
    required String reportType,
    required String format,
    required Map<String, dynamic> parameters,
    required String successMessage,
  }) async {
    setState(() => _saving = true);
    try {
      await BackendApiClient.instance.createReportExport(
        path,
        reportTitle: title,
        reportType: reportType,
        format: format,
        scope: 'principal',
        parameters: parameters,
      );
      if (!mounted) return;
      _snack(successMessage, success: true);
    } catch (error) {
      if (!mounted) return;
      _snack('Unable to generate export: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openStudentResult(Map<String, dynamic> row) {
    setState(() {
      _selectedStudent = row;
      _history.add(_view);
      _view = _PrincipalExamView.studentResult;
      _studentMarks = [];
      _studentMarksError = null;
    });
    _loadStudentMarks(row);
  }

  Future<void> _loadStudentMarks(Map<String, dynamic> student) async {
    final studentId = _text(student['student_id']);
    final exam = _examForStudent(student) ?? _currentExam;
    final schedules = _list(exam?['schedule_details']);
    if (studentId.isEmpty || schedules.isEmpty) {
      setState(() {
        _studentMarks = [];
        _studentMarksLoading = false;
        _studentMarksError = null;
      });
      return;
    }
    setState(() {
      _studentMarksLoading = true;
      _studentMarksError = null;
    });
    try {
      final rows = <Map<String, dynamic>>[];
      final api = BackendApiClient.instance;
      for (final schedule in schedules) {
        final scheduleId = _text(schedule['schedule_id'] ?? schedule['id']);
        if (scheduleId.isEmpty) continue;
        final marks = await api.getRawList(
          '/exams/schedules/${Uri.encodeComponent(scheduleId)}/marks',
        );
        final mark = marks.firstWhereOrNull((item) {
          return _text(item['student_id']) == studentId ||
              _text(_map(item['student'])['id']) == studentId;
        });
        rows.add({
          ...schedule,
          if (mark != null) ...mark,
          'subject': _text(schedule['subject'], fallback: 'Subject'),
          'max_marks': _int(schedule['max_marks']),
          'marks_obtained': mark == null ? null : mark['marks_obtained'],
          'grade_label': mark == null
              ? 'Pending'
              : _text(mark['grade_label'], fallback: '-'),
        });
      }
      if (!mounted) return;
      setState(() {
        _studentMarks = rows;
        _studentMarksLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _studentMarksError =
            'Unable to load student marks from backend. $error';
        _studentMarksLoading = false;
      });
    }
  }

  Future<void> _openExamFilterSheet() async {
    final selected = await showModalBottomSheet<_ExamStatusFilter>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ExamFilterSheet<_ExamStatusFilter>(
        title: 'Filter Examinations',
        values: _ExamStatusFilter.values,
        selected: _examFilter,
        labelFor: _examFilterLabel,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _examFilter = selected);
  }

  Future<void> _openResultFilterSheet() async {
    final selected = await showModalBottomSheet<_ResultStatusFilter>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ExamFilterSheet<_ResultStatusFilter>(
        title: 'Filter Results',
        values: _ResultStatusFilter.values,
        selected: _resultFilter,
        labelFor: _resultFilterLabel,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _resultFilter = selected);
  }

  List<Map<String, dynamic>> get _examRows =>
      _list(_examData['exam_dashboard']);

  Map<String, dynamic> get _examSummary => _map(_examData['summary']);

  Map<String, dynamic> get _resultSummary => _map(_resultData['summary']);

  List<Map<String, dynamic>> get _filteredExamRows {
    return _examRows.where((row) {
      if (_examFilter != _ExamStatusFilter.all &&
          _text(row['status']).toLowerCase() !=
              _examFilterLabel(_examFilter).toLowerCase()) {
        return false;
      }
      return _matchesSearch(row);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredResultRows {
    return _examRows.where((row) {
      final published = _isPublished(row);
      switch (_resultFilter) {
        case _ResultStatusFilter.all:
          break;
        case _ResultStatusFilter.published:
          if (!published) return false;
          break;
        case _ResultStatusFilter.draft:
          if (published || _text(row['status']).toLowerCase() == 'completed') {
            return false;
          }
          break;
        case _ResultStatusFilter.notPublished:
          if (published) return false;
          break;
      }
      return _matchesSearch(row);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredScheduleRows {
    final exam = _currentExam;
    final rows = _list(exam?['schedule_details']);
    if (_scheduleClassFilter == 'All') return rows;
    return rows.where((row) {
      return _text(row['class_name'], fallback: 'Class') ==
          _scheduleClassFilter;
    }).toList();
  }

  List<String> get _scheduleClassFilters {
    final values =
        _list(_currentExam?['schedule_details'])
            .map((row) => _text(row['class_name'], fallback: 'Class'))
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['All', ...values];
  }

  List<Map<String, dynamic>> get _reportOptions {
    return _list(_map(_resultData['reports'])['export_options']);
  }

  Map<String, dynamic>? get _currentExam {
    if (_selectedExam != null) return _selectedExam;
    return _examRows.isEmpty ? null : _examRows.first;
  }

  int get _totalSubjects {
    final fromResults = _int(_resultSummary['subject_analysis_count']);
    if (fromResults > 0) return fromResults;
    final subjects = <String>{};
    for (final exam in _examRows) {
      for (final schedule in _list(exam['schedule_details'])) {
        final key = _text(
          schedule['subject_id'],
          fallback: _text(schedule['subject']),
        );
        if (key.isNotEmpty) subjects.add(key);
      }
    }
    return subjects.length;
  }

  int get _totalStudents {
    final studentIds = _reportCards
        .map((row) => _text(row['student_id']))
        .where((value) => value.isNotEmpty)
        .toSet();
    if (studentIds.isNotEmpty) return studentIds.length;
    return _int(_resultSummary['report_cards']);
  }

  int get _publishedResults {
    final published = _examRows.where(_isPublished).length;
    return published > 0 ? published : _int(_examSummary['published_exams']);
  }

  Map<String, dynamic>? _reselectExam(Map<String, dynamic>? current) {
    if (current == null) return null;
    final id = _text(current['exam_id'] ?? current['id']);
    return _examRows.firstWhereOrNull((row) {
      return _text(row['exam_id'] ?? row['id']) == id;
    });
  }

  Map<String, dynamic>? _reselectStudent(Map<String, dynamic>? current) {
    if (current == null) return null;
    final id = _text(current['id']);
    if (id.isNotEmpty) {
      return _reportCards.firstWhereOrNull((row) => _text(row['id']) == id);
    }
    final studentId = _text(current['student_id']);
    final examId = _text(current['exam_id']);
    return _reportCards.firstWhereOrNull((row) {
      return _text(row['student_id']) == studentId &&
          (examId.isEmpty || _text(row['exam_id']) == examId);
    });
  }

  List<Map<String, dynamic>> _reportCardsForExam(Map<String, dynamic> exam) {
    final examId = _text(exam['exam_id'] ?? exam['id']);
    if (examId.isEmpty) return const [];
    return _reportCards.where((row) => _text(row['exam_id']) == examId).toList()
      ..sort((a, b) => _num(b['percentage']).compareTo(_num(a['percentage'])));
  }

  Map<String, dynamic>? _examForStudent(Map<String, dynamic> student) {
    final examId = _text(student['exam_id']);
    if (examId.isEmpty) return null;
    return _examRows.firstWhereOrNull((row) {
      return _text(row['exam_id'] ?? row['id']) == examId;
    });
  }

  bool _matchesSearch(Map<String, dynamic> row) {
    final query = _search.trim().toLowerCase();
    if (query.isEmpty) return true;
    final haystack = [
      _examTitle(row),
      _text(row['status']),
      _text(row['exam_type']),
      _text(row['class_names']),
      _text(row['subject_names']),
      _text(row['evaluation_status']),
    ].join(' ').toLowerCase();
    return haystack.contains(query);
  }

  bool _isPublished(Map<String, dynamic> row) {
    final value = row['is_published'];
    if (value is bool) return value;
    return _text(value).toLowerCase() == 'true';
  }

  String _examTitle(Map<String, dynamic> row) {
    return _text(row['exam_name'] ?? row['name'], fallback: 'Examination');
  }

  String _examStatusLabel(Map<String, dynamic> row) {
    final status = _text(row['status'], fallback: 'Live');
    return status.isEmpty
        ? 'Live'
        : '${status[0].toUpperCase()}${status.substring(1)}';
  }

  String _examFilterLabel(_ExamStatusFilter filter) {
    return switch (filter) {
      _ExamStatusFilter.all => 'All',
      _ExamStatusFilter.upcoming => 'Upcoming',
      _ExamStatusFilter.ongoing => 'Ongoing',
      _ExamStatusFilter.completed => 'Completed',
    };
  }

  String _resultFilterLabel(_ResultStatusFilter filter) {
    return switch (filter) {
      _ResultStatusFilter.all => 'All',
      _ResultStatusFilter.published => 'Published',
      _ResultStatusFilter.draft => 'Draft',
      _ResultStatusFilter.notPublished => 'Not Published',
    };
  }

  int _durationDays(Map<String, dynamic> exam) {
    final start = DateTime.tryParse(_text(exam['start_date']));
    final end = DateTime.tryParse(_text(exam['end_date']));
    if (start == null || end == null) return 0;
    return end.difference(start).inDays.abs() + 1;
  }

  int _totalMaxMarks(Map<String, dynamic>? exam) {
    return _list(
      exam?['schedule_details'],
    ).fold<int>(0, (sum, row) => sum + _int(row['max_marks']));
  }

  String _studentName(Map<String, dynamic> row) {
    final student = _map(row['student']);
    final full = [
      _text(student['first_name']),
      _text(student['last_name']),
    ].where((part) => part.isNotEmpty).join(' ');
    return _text(
      row['student_name'] ?? student['name'],
      fallback: full.isEmpty ? 'Student' : full,
    );
  }

  String _studentClass(Map<String, dynamic> row) {
    final enrollment = _map(row['enrollment']);
    final section = _map(enrollment['section']);
    final grade = _map(section['grade']);
    final label = [
      _text(row['class_name']),
      _text(grade['grade_name']),
      _text(section['section_name']),
    ].where((part) => part.isNotEmpty).join(' - ');
    return label.isEmpty ? 'Class pending' : label;
  }

  Color _statusColor(String status) {
    final lower = status.toLowerCase();
    if (lower.contains('published') ||
        lower.contains('completed') ||
        lower.contains('upcoming')) {
      return const Color(0xFF16A34A);
    }
    if (lower.contains('ongoing') || lower.contains('draft')) {
      return const Color(0xFFF59E0B);
    }
    if (lower.contains('not') || lower.contains('failed')) {
      return const Color(0xFFEF4444);
    }
    return const Color(0xFF2563EB);
  }

  String _displayDate(Object? value) {
    final parsed = DateTime.tryParse(_text(value));
    if (parsed == null) return _text(value, fallback: '-');
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
    return '${parsed.day.toString().padLeft(2, '0')} ${months[parsed.month - 1]} ${parsed.year}';
  }

  String _percentText(Object? value) {
    final number = _num(value);
    return '${number.toStringAsFixed(number.truncateToDouble() == number ? 0 : 1)}%';
  }

  String _numberText(num value) {
    return value.truncateToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  void _snack(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppTheme.success : AppTheme.error,
      ),
    );
  }
}

void _noopIndex(int index) {}

class _ExamPage extends StatelessWidget {
  final Widget header;
  final List<Widget> children;

  const _ExamPage({required this.header, required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 116),
      children: [header, const SizedBox(height: 14), ...children],
    );
  }
}

class _ExamHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData leadingIcon;
  final VoidCallback? onLeading;
  final Widget? trailing;

  const _ExamHeader({
    required this.title,
    required this.subtitle,
    required this.leadingIcon,
    this.onLeading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: leadingIcon == Icons.menu_rounded ? 'Open menu' : 'Back',
          onPressed: onLeading,
          icon: Icon(leadingIcon, size: 22),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.muted,
                ),
              ),
            ],
          ),
        ),
        trailing ?? const SizedBox(width: 48),
      ],
    );
  }
}

class _ExamCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool selected;

  const _ExamCard({required this.child, this.onTap, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? AppTheme.primary : const Color(0xFFE2E8F0),
          width: selected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: card,
    );
  }
}

class _ExamMetricGrid extends StatelessWidget {
  final List<Widget> children;

  const _ExamMetricGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.75,
      children: children,
    );
  }
}

class _ExamMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ExamMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _ExamCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _ExamIconBadge(icon: icon, color: color),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.muted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExamMiniMetricGrid extends StatelessWidget {
  final List<Widget> children;

  const _ExamMiniMetricGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.65,
      children: children,
    );
  }
}

class _ExamMiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ExamMiniMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ExamIconBadge(icon: icon, color: color, compact: true),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 8.5,
              height: 1.05,
              fontWeight: FontWeight.w800,
              color: AppTheme.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ExamActionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ExamCard(
      onTap: onTap,
      child: Row(
        children: [
          _ExamIconBadge(icon: icon, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
        ],
      ),
    );
  }
}

class _ExamSearchBox extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const _ExamSearchBox({required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded),
      ),
    );
  }
}

class _ExamFilterChips extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _ExamFilterChips({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return ChoiceChip(
            label: Text(labels[index]),
            selected: selected,
            onSelected: (_) => onSelected(index),
            showCheckmark: false,
            labelStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: selected ? Colors.white : AppTheme.onSurface,
            ),
            selectedColor: AppTheme.primary,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected ? AppTheme.primary : const Color(0xFFE2E8F0),
            ),
          );
        },
      ),
    );
  }
}

class _ExamSectionTitle extends StatelessWidget {
  final String label;

  const _ExamSectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: AppTheme.onSurface,
      ),
    );
  }
}

class _ExamSectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback? onAction;

  const _ExamSectionHeader({
    required this.title,
    required this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        children: [
          Expanded(child: _ExamSectionTitle(title)),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _ExamListCard extends StatelessWidget {
  final Map<String, dynamic> exam;
  final VoidCallback onTap;

  const _ExamListCard({required this.exam, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _ExamCard(
      onTap: onTap,
      child: Row(
        children: [
          const _ExamIconBadge(
            icon: Icons.assignment_outlined,
            color: Color(0xFF2563EB),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text(exam['exam_name'], fallback: 'Examination'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    _text(exam['class_names']),
                    _text(exam['exam_type']),
                  ].where((part) => part.isNotEmpty).join(' - '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _ExamTinyChip(
                      icon: Icons.calendar_today_outlined,
                      label:
                          '${_displayDateStatic(exam['start_date'])} - ${_displayDateStatic(exam['end_date'])}',
                    ),
                    _ExamTinyChip(
                      icon: Icons.groups_outlined,
                      label: '${_int(exam['schedule_count'])} Subjects',
                    ),
                  ],
                ),
              ],
            ),
          ),
          _ExamStatusPill(
            label: _capitalize(_text(exam['status'], fallback: 'Live')),
            color: _statusColorStatic(_text(exam['status'])),
          ),
        ],
      ),
    );
  }
}

class _ExamResultCard extends StatelessWidget {
  final Map<String, dynamic> exam;
  final VoidCallback onTap;

  const _ExamResultCard({required this.exam, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final published = _bool(exam['is_published']);
    final status = published
        ? 'Published'
        : _text(exam['status']).toLowerCase() == 'completed'
        ? 'Not Published'
        : 'Draft';
    return _ExamCard(
      onTap: onTap,
      child: Row(
        children: [
          const _ExamIconBadge(
            icon: Icons.workspace_premium_outlined,
            color: Color(0xFF7C3AED),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text(exam['exam_name'], fallback: 'Examination'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    _text(exam['class_names']),
                    _text(exam['exam_type']),
                  ].where((part) => part.isNotEmpty).join(' - '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _ExamTinyChip(
                      icon: Icons.publish_outlined,
                      label: published ? 'Published' : 'Not Published',
                    ),
                    _ExamTinyChip(
                      icon: Icons.groups_outlined,
                      label: '${_int(exam['schedule_count'])} Subjects',
                    ),
                  ],
                ),
              ],
            ),
          ),
          _ExamStatusPill(label: status, color: _statusColorStatic(status)),
        ],
      ),
    );
  }
}

class _ExamScheduleTile extends StatelessWidget {
  final Map<String, dynamic> schedule;

  const _ExamScheduleTile({required this.schedule});

  @override
  Widget build(BuildContext context) {
    return _ExamCard(
      child: Row(
        children: [
          const _ExamIconBadge(
            icon: Icons.menu_book_outlined,
            color: Color(0xFF2563EB),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text(schedule['subject'], fallback: 'Subject'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _text(schedule['class_name'], fallback: 'Class'),
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _text(schedule['syllabus'], fallback: 'Syllabus pending'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${_int(schedule['max_marks'])} Marks',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ExamScheduleHeaderRow extends StatelessWidget {
  const _ExamScheduleHeaderRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(width: 58, child: _ExamTableHeader('Date')),
        SizedBox(width: 58, child: _ExamTableHeader('Day')),
        Expanded(child: _ExamTableHeader('Subject')),
        SizedBox(width: 62, child: _ExamTableHeader('Time')),
      ],
    );
  }
}

class _ExamScheduleTableRow extends StatelessWidget {
  final Map<String, dynamic> row;

  const _ExamScheduleTableRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(_text(row['exam_date']));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(
              date == null
                  ? '-'
                  : '${date.day.toString().padLeft(2, '0')} ${_month(date.month)}',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(
            width: 58,
            child: Text(
              date == null ? '-' : _weekday(date.weekday),
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _text(row['subject'], fallback: 'Subject'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(
            width: 62,
            child: Text(
              _text(
                row['start_time'],
                fallback: _text(row['time'], fallback: '-'),
              ),
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamStudentResultTile extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onTap;

  const _ExamStudentResultTile({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = _studentNameStatic(row);
    final pct = _num(row['percentage']);
    return _ExamCard(
      onTap: onTap,
      child: Row(
        children: [
          _ExamAvatar(label: name),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _studentClassStatic(row),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${pct.toStringAsFixed(1)}%',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 8),
          _ExamStatusPill(
            label: pct >= 40 ? 'Passed' : 'Review',
            color: pct >= 40
                ? const Color(0xFF16A34A)
                : const Color(0xFFF97316),
          ),
        ],
      ),
    );
  }
}

class _ExamMarksHeaderRow extends StatelessWidget {
  const _ExamMarksHeaderRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _ExamTableHeader('Subject')),
        SizedBox(width: 58, child: _ExamTableHeader('Max')),
        SizedBox(width: 72, child: _ExamTableHeader('Obtained')),
        SizedBox(width: 52, child: _ExamTableHeader('Grade')),
      ],
    );
  }
}

class _ExamMarksRow extends StatelessWidget {
  final Map<String, dynamic> row;

  const _ExamMarksRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final obtained = row['marks_obtained'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _text(row['subject'], fallback: 'Subject'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(
            width: 58,
            child: Text(
              '${_int(row['max_marks'])}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(
            width: 72,
            child: Text(
              obtained == null ? '-' : _numberTextStatic(_num(obtained)),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              _text(row['grade_label'], fallback: '-'),
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamGradeHeaderRow extends StatelessWidget {
  const _ExamGradeHeaderRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(width: 58, child: _ExamTableHeader('Grade')),
        Expanded(child: _ExamTableHeader('Percentage From')),
        Expanded(child: _ExamTableHeader('Percentage To')),
        SizedBox(width: 70, child: _ExamTableHeader('Grade Point')),
      ],
    );
  }
}

class _ExamGradeRow extends StatelessWidget {
  final Map<String, dynamic> row;

  const _ExamGradeRow({required this.row});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(
              _text(row['grade_label'], fallback: '-'),
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _numberTextStatic(_num(row['min_percent'])),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _numberTextStatic(_num(row['max_percent'])),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              _numberTextStatic(_num(row['gpa_points'])),
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamReportOptionTile extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool selected;
  final VoidCallback onTap;

  const _ExamReportOptionTile({
    required this.row,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ExamCard(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          const _ExamIconBadge(
            icon: Icons.bar_chart_outlined,
            color: Color(0xFF7C3AED),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text(row['label'], fallback: 'Exam Report'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Generate ${_text(row['format'], fallback: 'pdf').toUpperCase()} report',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.muted),
        ],
      ),
    );
  }
}

class _ExamFilterSheet<T> extends StatelessWidget {
  final String title;
  final List<T> values;
  final T selected;
  final String Function(T value) labelFor;

  const _ExamFilterSheet({
    required this.title,
    required this.values,
    required this.selected,
    required this.labelFor,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            for (final value in values)
              RadioListTile<T>(
                contentPadding: EdgeInsets.zero,
                value: value,
                groupValue: selected,
                title: Text(labelFor(value)),
                onChanged: (value) => Navigator.pop(context, value),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExamKeyValueRow extends StatelessWidget {
  final String label;
  final String value;

  const _ExamKeyValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ExamInfoBanner extends StatelessWidget {
  final IconData icon;
  final String message;

  const _ExamInfoBanner({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 11,
                height: 1.35,
                color: AppTheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ExamEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ExamIconBadge(icon: icon, color: AppTheme.primary),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppTheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: AppTheme.muted,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExamPrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _ExamPrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _ExamOutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _ExamOutlineButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _ExamIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool compact;

  const _ExamIconBadge({
    required this.icon,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 28.0 : 38.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: compact ? 16 : 20),
    );
  }
}

class _ExamStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _ExamStatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _ExamTinyChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ExamTinyChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.muted),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 150),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.muted,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExamAvatar extends StatelessWidget {
  final String label;

  const _ExamAvatar({required this.label});

  @override
  Widget build(BuildContext context) {
    final initial = label.trim().isEmpty ? 'S' : label.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: 19,
      backgroundColor: const Color(0xFFE0F2FE),
      child: Text(
        initial,
        style: const TextStyle(
          color: Color(0xFF0369A1),
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ExamTableHeader extends StatelessWidget {
  final String label;

  const _ExamTableHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 9.5,
        color: AppTheme.muted,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

extension _FirstWhereOrNullExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T item) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is List) {
    return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }
  return const [];
}

int _int(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(_text(value)) ?? 0;
}

double _num(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(_text(value)) ?? 0;
}

bool _bool(Object? value) {
  if (value is bool) return value;
  return _text(value).toLowerCase() == 'true';
}

String _text(Object? value, {String fallback = ''}) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty || text == 'null' ? fallback : text;
}

String _capitalize(String value) {
  final text = value.trim();
  if (text.isEmpty) return text;
  return '${text[0].toUpperCase()}${text.substring(1)}';
}

String _month(int month) {
  const labels = [
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
  if (month < 1 || month > 12) return '-';
  return labels[month - 1];
}

String _weekday(int weekday) {
  const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  if (weekday < 1 || weekday > 7) return '-';
  return labels[weekday - 1];
}

String _displayDateStatic(Object? value) {
  final parsed = DateTime.tryParse(_text(value));
  if (parsed == null) return _text(value, fallback: '-');
  return '${parsed.day.toString().padLeft(2, '0')} ${_month(parsed.month)} ${parsed.year}';
}

String _numberTextStatic(num value) {
  return value.truncateToDouble() == value
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

String _studentNameStatic(Map<String, dynamic> row) {
  final student = _map(row['student']);
  final full = [
    _text(student['first_name']),
    _text(student['last_name']),
  ].where((part) => part.isNotEmpty).join(' ');
  return _text(
    row['student_name'] ?? student['name'],
    fallback: full.isEmpty ? 'Student' : full,
  );
}

String _studentClassStatic(Map<String, dynamic> row) {
  final enrollment = _map(row['enrollment']);
  final section = _map(enrollment['section']);
  final grade = _map(section['grade']);
  final label = [
    _text(row['class_name']),
    _text(grade['grade_name']),
    _text(section['section_name']),
  ].where((part) => part.isNotEmpty).join(' - ');
  return label.isEmpty ? 'Class pending' : label;
}

Color _statusColorStatic(String status) {
  final lower = status.toLowerCase();
  if (lower.contains('published') ||
      lower.contains('completed') ||
      lower.contains('upcoming')) {
    return const Color(0xFF16A34A);
  }
  if (lower.contains('ongoing') || lower.contains('draft')) {
    return const Color(0xFFF59E0B);
  }
  if (lower.contains('not') || lower.contains('failed')) {
    return const Color(0xFFEF4444);
  }
  return const Color(0xFF2563EB);
}
