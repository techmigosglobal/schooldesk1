import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';

class ParentReportCardsScreen extends StatefulWidget {
  const ParentReportCardsScreen({super.key});

  @override
  State<ParentReportCardsScreen> createState() => _ParentReportCardsScreenState();
}

class _ParentReportCardsScreenState extends State<ParentReportCardsScreen> {
  int _selectedNavIndex = 1; // Academics
  int _activeChildIndex = 0;
  static const _headerColor = Color(0xFF1A6B4A);

  List<dynamic> _children = [];
  List<dynamic> _reportCards = [];
  List<dynamic> _exports = [];
  bool _loading = true;
  bool _exportLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final children = await BackendApiClient.instance.getMyStudents();
      setState(() {
        _children = children;
      });
      if (children.isNotEmpty) {
        await _loadChildReportCards(0);
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
      _showErrorSnackBar('Failed to load child list: $e');
    }
  }

  Future<void> _loadChildReportCards(int childIndex) async {
    if (childIndex >= _children.length) return;
    setState(() => _loading = true);
    try {
      final studentId = (_children[childIndex]['id'] ?? '').toString();
      final cards = await BackendApiClient.instance.getRawList(
        '/exams/report-cards',
        queryParameters: {'student_id': studentId},
      );
      final exports = await BackendApiClient.instance.getReportExports(
        '/exams/report-cards/exports',
      );

      setState(() {
        _reportCards = cards;
        _exports = exports.where((exp) {
          final params = exp['parameters'] ?? {};
          return params['student_id']?.toString() == studentId;
        }).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _showErrorSnackBar('Failed to load report cards: $e');
    }
  }

  Future<void> _triggerExport(Map<String, dynamic> card) async {
    if (_activeStudentId.isEmpty) return;
    setState(() => _exportLoading = true);
    try {
      final term = card['exam']?['exam_name'] ?? card['exam_id'] ?? 'Report Card';
      final export = await BackendApiClient.instance.createReportExport(
        '/exams/report-cards/exports',
        reportTitle: 'Report card $term'.trim(),
        format: 'pdf',
        reportType: 'report_card',
        scope: 'parent',
        parameters: {
          'student_id': _activeStudentId,
          'term': term,
        },
      );

      _showSuccessSnackBar('Report card export initiated: ${export['status'] ?? 'pending'}');
      // Refresh exports list
      final exports = await BackendApiClient.instance.getReportExports(
        '/exams/report-cards/exports',
      );
      setState(() {
        _exports = exports.where((exp) {
          final params = exp['parameters'] ?? {};
          return params['student_id']?.toString() == _activeStudentId;
        }).toList();
      });
    } catch (e) {
      _showErrorSnackBar('Failed to initiate download: $e');
    } finally {
      setState(() => _exportLoading = false);
    }
  }

  String get _activeStudentId {
    if (_children.isEmpty || _activeChildIndex >= _children.length) return '';
    return (_children[_activeChildIndex]['id'] ?? '').toString();
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
    final drawer = ParentDrawer(
      selectedIndex: _selectedNavIndex,
      onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
    );

    return SchoolDeskModuleScaffold(
      title: 'Report Cards',
      subtitle: 'View and download student term report cards',
      drawer: drawer,
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () {
            if (_children.isNotEmpty) {
              _loadChildReportCards(_activeChildIndex);
            } else {
              _loadData();
            }
          },
          tooltip: 'Refresh reports',
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
                  if (_exportLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: LinearProgressIndicator(),
                    ),
                  Expanded(
                    child: _reportCards.isEmpty
                        ? _buildEmptyState()
                        : _buildReportCardsList(),
                  ),
                  if (_exports.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Download Progress / History',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildExportsHistoryList(),
                  ],
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
          final c = _children[i];
          final first = (c['first_name'] ?? '').toString();
          final last = (c['last_name'] ?? '').toString();
          final name = [first, last].where((e) => e.isNotEmpty).join(' ').trim();
          final grade = (c['grade_name'] ?? '').toString();
          final section = (c['section_name'] ?? '').toString();
          final classLabel = [grade, section].where((e) => e.isNotEmpty).join('-');
          final label = classLabel.isEmpty ? name : '$name ($classLabel)';

          return GestureDetector(
            onTap: () {
              setState(() {
                _activeChildIndex = i;
              });
              _loadChildReportCards(i);
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
                label.split(' ').first,
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
          Icon(Icons.contact_page_rounded, size: 48, color: AppTheme.muted),
          const SizedBox(height: 12),
          Text(
            'No report cards found',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Report cards will appear here once published by teachers.',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCardsList() {
    return ListView.builder(
      itemCount: _reportCards.length,
      itemBuilder: (context, index) {
        final card = _reportCards[index];
        final exam = card['exam'] ?? {};
        final term = exam['exam_name'] ?? card['exam_id'] ?? 'Report Card';
        final percentage = card['percentage'] != null
            ? '${(card['percentage'] as num).toStringAsFixed(1)}%'
            : '—';
        final rank = (card['class_rank'] as num?)?.toInt() ?? 0;
        final rankStr = rank > 0 ? '$rank' : '—';
        final published = card['published_at'] != null;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: published ? _headerColor.withAlpha(20) : AppTheme.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  published ? Icons.analytics_rounded : Icons.pending_actions_rounded,
                  color: published ? _headerColor : AppTheme.muted,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      term,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Score: ',
                          style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
                        ),
                        Text(
                          percentage,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Class Rank: ',
                          style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.muted),
                        ),
                        Text(
                          rankStr,
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (published)
                IconButton.filled(
                  onPressed: () => _triggerExport(card),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: _headerColor,
                    foregroundColor: Colors.white,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Upcoming',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.muted,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExportsHistoryList() {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _exports.length,
        itemBuilder: (context, index) {
          final exp = _exports[index];
          final title = exp['report_title'] ?? 'Report card export';
          final status = exp['status']?.toString().toUpperCase() ?? 'PENDING';
          final fileUrl = exp['file_url'] ?? '';

          Color statusColor;
          IconData statusIcon;
          if (status == 'COMPLETED') {
            statusColor = AppTheme.success;
            statusIcon = Icons.check_circle_rounded;
          } else if (status == 'FAILED') {
            statusColor = AppTheme.error;
            statusIcon = Icons.error_rounded;
          } else {
            statusColor = AppTheme.warning;
            statusIcon = Icons.hourglass_empty_rounded;
          }

          return Container(
            width: 220,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      status,
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (status == 'COMPLETED' && fileUrl.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    height: 28,
                    child: OutlinedButton(
                      onPressed: () {
                        // In a real app we'd open or download the URL, show feedback.
                        _showSuccessSnackBar('Downloading file from: $fileUrl');
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: const BorderSide(color: _headerColor),
                      ),
                      child: Text(
                        'Get PDF',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _headerColor,
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    'Format: ${exp['format'] ?? 'PDF'}',
                    style: GoogleFonts.dmSans(fontSize: 10, color: AppTheme.muted),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
