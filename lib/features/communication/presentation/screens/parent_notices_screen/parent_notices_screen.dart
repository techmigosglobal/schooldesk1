import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/parent_navigation.dart';

class ParentNoticesScreen extends StatefulWidget {
  const ParentNoticesScreen({super.key});

  @override
  State<ParentNoticesScreen> createState() => _ParentNoticesScreenState();
}

class _ParentNoticesScreenState extends State<ParentNoticesScreen>
    with SingleTickerProviderStateMixin {
  int _selectedNavIndex = 4;
  late TabController _tabController;
  String _selectedFilter = 'All';
  static const _headerColor = Color(0xFF1A6B4A);
  bool _loading = true;

  final List<String> _filters = [
    'All',
    'Urgent',
    'Events',
    'Holidays',
    'Exams',
    'Finance',
  ];

  List<Map<String, dynamic>> _notices = [];

  List<Map<String, dynamic>> get _filtered {
    final published = _notices.where((n) {
      final status = n['status'] as String? ?? '';
      return status == 'Published' || status == 'Sent' || status.isEmpty;
    }).toList();
    if (_selectedFilter == 'All') return published;
    if (_selectedFilter == 'Urgent') {
      return published.where((n) => n['urgent'] == true).toList();
    }
    return published.where((n) => n['type'] == _selectedFilter).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final stored = await BackendApiClient.instance.getAnnouncements();
    final acknowledgements = await BackendApiClient.instance.getRawList(
      '/notice-acknowledgements',
    );
    final acknowledgedIds = acknowledgements
        .map((ack) => ack['notice_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    setState(() {
      _notices = stored
          .map(
            (notice) => {
              'id': notice.id,
              'title': notice.title,
              'body': notice.content,
              'type': _noticeCategory(
                title: notice.title,
                body: notice.content,
                audience: notice.targetAudience,
                urgent: notice.isUrgent,
              ),
              'audience': notice.targetAudience,
              'date': notice.publishedAt,
              'status': 'Published',
              'urgent': notice.isUrgent,
              'acknowledged': acknowledgedIds.contains(notice.id),
            },
          )
          .toList();
      _loading = false;
    });
  }

  String _noticeCategory({
    required String title,
    required String body,
    required String audience,
    required bool urgent,
  }) {
    if (urgent) return 'Urgent';
    final haystack = '$title $body $audience'.toLowerCase();
    if (haystack.contains('fee') ||
        haystack.contains('payment') ||
        haystack.contains('finance')) {
      return 'Finance';
    }
    if (haystack.contains('exam') ||
        haystack.contains('test') ||
        haystack.contains('assessment')) {
      return 'Exams';
    }
    if (haystack.contains('holiday') || haystack.contains('vacation')) {
      return 'Holidays';
    }
    if (haystack.contains('event') ||
        haystack.contains('meeting') ||
        haystack.contains('ptm')) {
      return 'Events';
    }
    return 'General';
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drawer = ParentDrawer(
      selectedIndex: _selectedNavIndex,
      onDestinationSelected: (i) => setState(() => _selectedNavIndex = i),
    );
    if (_loading) {
      return SchoolDeskModuleScaffold(
        title: 'School Notices',
        subtitle: 'Read and filter notices shared by the school',
        drawer: drawer,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return SchoolDeskModuleScaffold(
      title: 'School Notices',
      subtitle: 'Read and filter notices shared by the school',
      drawer: drawer,
      floatingActionButton: const DashboardFabWidget(
        role: DashboardRole.parent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadData,
          tooltip: 'Refresh notices',
        ),
      ],
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      'No notices found',
                      style: GoogleFonts.dmSans(color: AppTheme.muted),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: _headerColor,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _noticeCard(_filtered[i], i),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((f) {
            final isSelected = _selectedFilter == f;
            return GestureDetector(
              onTap: () => setState(() => _selectedFilter = f),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? _headerColor : AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  f,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppTheme.onSurface,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _noticeCard(Map<String, dynamic> n, int index) {
    final isUrgent = n['urgent'] as bool? ?? false;
    final isAcknowledged = n['acknowledged'] as bool? ?? false;
    final title = n['title'] as String? ?? '';
    final body = n['body'] as String? ?? '';
    final type = n['type'] as String? ?? 'General';
    final date = n['date'] as String? ?? '';

    final typeColors = {
      'Events': const Color(0xFF1E8449),
      'Finance': const Color(0xFFD4850A),
      'Holidays': const Color(0xFF6C3483),
      'Exams': const Color(0xFF1565C0),
      'Urgent': AppTheme.error,
    };
    final typeIcons = {
      'Events': Icons.emoji_events_rounded,
      'Finance': Icons.account_balance_wallet_rounded,
      'Holidays': Icons.celebration_rounded,
      'Exams': Icons.quiz_rounded,
      'Meeting': Icons.people_rounded,
    };
    final color = typeColors[type] ?? AppTheme.primary;
    final icon = typeIcons[type] ?? Icons.notifications_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUrgent
              ? AppTheme.error.withAlpha(80)
              : AppTheme.outlineVariant,
          width: isUrgent ? 1.5 : 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Row(
            children: [
              if (isUrgent)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.errorContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'URGENT',
                    style: GoogleFonts.dmSans(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.error,
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Text(
            '$type • $date',
            style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  Text(
                    body,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!isAcknowledged)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final idx = _notices.indexWhere(
                            (x) => x['id'] == n['id'],
                          );
                          if (idx >= 0) {
                            setState(
                              () => _notices[idx]['acknowledged'] = true,
                            );
                            await BackendApiClient.instance
                                .createRaw('/notice-acknowledgements', {
                                  'notice_id': n['id'],
                                  'acknowledged_at': DateTime.now()
                                      .toUtc()
                                      .toIso8601String(),
                                });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Notice acknowledged'),
                                backgroundColor: AppTheme.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: Text(
                          'Acknowledge',
                          style: GoogleFonts.dmSans(fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _headerColor,
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.success,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Acknowledged',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: AppTheme.success,
                          ),
                        ),
                      ],
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
