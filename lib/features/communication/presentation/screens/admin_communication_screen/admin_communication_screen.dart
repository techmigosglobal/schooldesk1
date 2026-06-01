import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/theme/app_theme.dart';
import 'package:schooldesk1/core/widgets/admin_navigation.dart';
import 'package:schooldesk1/core/widgets/dashboard_fab_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';

class AdminCommunicationScreen extends StatefulWidget {
  const AdminCommunicationScreen({super.key});

  @override
  State<AdminCommunicationScreen> createState() =>
      _AdminCommunicationScreenState();
}

class _AdminCommunicationScreenState extends State<AdminCommunicationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  String _audienceFilter = 'All';
  String _statusFilter = 'All';

  List<Map<String, dynamic>> _notices = [];

  static const _audienceOptions = [
    'All',
    'Everyone',
    'Parents',
    'Teachers',
    'Students',
    'Admin',
    'Principal',
  ];

  static const _statusOptions = ['All', 'Normal', 'Urgent'];

  final List<Map<String, dynamic>> _templates = [
    {
      'name': 'Fee Reminder',
      'audience': 'Parents',
      'icon': Icons.account_balance_wallet_rounded,
      'color': AppTheme.warning,
    },
    {
      'name': 'Holiday Notice',
      'audience': 'Everyone',
      'icon': Icons.beach_access_rounded,
      'color': AppTheme.success,
    },
    {
      'name': 'Exam Notice',
      'audience': 'Students',
      'icon': Icons.quiz_rounded,
      'color': AppTheme.primary,
    },
    {
      'name': 'Staff Meeting',
      'audience': 'Teachers',
      'icon': Icons.groups_rounded,
      'color': AppTheme.secondary,
    },
    {
      'name': 'Principal Update',
      'audience': 'Principal',
      'icon': Icons.admin_panel_settings_rounded,
      'color': AppTheme.info,
    },
    {
      'name': 'Emergency Alert',
      'audience': 'Everyone',
      'icon': Icons.warning_rounded,
      'color': AppTheme.error,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() => setState(() {}));
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stored = await BackendApiClient.instance.getAnnouncements();
      stored.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
      if (!mounted) return;
      setState(() {
        _notices = stored
            .map(
              (notice) => {
                'id': notice.id,
                'title': notice.title,
                'body': notice.content,
                'audience': notice.targetAudience,
                'audienceLabel': _audienceLabel(notice.targetAudience),
                'date': notice.publishedAt,
                'dateLabel': _formatDate(notice.publishedAt),
                'status': 'Published',
                'urgent': notice.isUrgent,
                'publishedBy': notice.createdBy,
              },
            )
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load communication records: $e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredNotices {
    final query = _searchController.text.trim().toLowerCase();
    return _notices.where((notice) {
      final audience = _audienceLabel(_text(notice['audience']));
      final matchesAudience =
          _audienceFilter == 'All' || audience == _audienceFilter;
      final urgent = notice['urgent'] == true;
      final matchesStatus =
          _statusFilter == 'All' ||
          (_statusFilter == 'Urgent' && urgent) ||
          (_statusFilter == 'Normal' && !urgent);
      final haystack = [
        notice['title'],
        notice['body'],
        audience,
        notice['publishedBy'],
      ].map((value) => _text(value).toLowerCase()).join(' ');
      final matchesQuery = query.isEmpty || haystack.contains(query);
      return matchesAudience && matchesStatus && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final drawer = AdminDrawer(selectedIndex: 7, onDestinationSelected: (_) {});
    return SchoolDeskModuleScaffold(
      title: 'Communication Management',
      subtitle: 'Publish role-wise notices and review delivery history',
      drawer: drawer,
      floatingActionButton: const DashboardFabWidget(role: DashboardRole.admin),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      actions: [
        IconButton(
          tooltip: 'Refresh communication',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadData,
        ),
        IconButton(
          tooltip: 'Compose notice',
          icon: const Icon(Icons.add_rounded),
          onPressed: () => _openComposePage(),
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Notices'),
          Tab(text: 'Templates'),
          Tab(text: 'History'),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _emptyState(_error!, actionLabel: 'Retry', onAction: _loadData);
    }
    return TabBarView(
      controller: _tabController,
      children: [_buildNotices(), _buildTemplates(), _buildSentHistory()],
    );
  }

  Widget _buildNotices() {
    final filtered = _filteredNotices;
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primary,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildFilters(),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            SizedBox(
              height: 360,
              child: _emptyState('No notices match the selected filters.'),
            )
          else
            ...filtered.map(_noticeCard),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 680;
        final search = TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            labelText: 'Search notices',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        );
        final audience = DropdownButtonFormField<String>(
          initialValue: _audienceFilter,
          decoration: const InputDecoration(labelText: 'Audience'),
          items: _audienceOptions
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: (value) =>
              setState(() => _audienceFilter = value ?? _audienceFilter),
        );
        final status = DropdownButtonFormField<String>(
          initialValue: _statusFilter,
          decoration: const InputDecoration(labelText: 'Status'),
          items: _statusOptions
              .map(
                (value) => DropdownMenuItem(value: value, child: Text(value)),
              )
              .toList(),
          onChanged: (value) =>
              setState(() => _statusFilter = value ?? _statusFilter),
        );
        if (wide) {
          return Row(
            children: [
              Expanded(flex: 2, child: search),
              const SizedBox(width: 10),
              Expanded(child: audience),
              const SizedBox(width: 10),
              Expanded(child: status),
            ],
          );
        }
        return Column(
          children: [
            search,
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: audience),
                const SizedBox(width: 10),
                Expanded(child: status),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _noticeCard(Map<String, dynamic> notice) {
    final isUrgent = notice['urgent'] == true;
    final color = isUrgent ? AppTheme.error : AppTheme.success;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUrgent ? AppTheme.errorContainer : AppTheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isUrgent) _pill('URGENT', AppTheme.error),
              if (isUrgent) const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _text(notice['title']),
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _pill(_text(notice['status'], fallback: 'Published'), color),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _meta(Icons.group_rounded, _text(notice['audienceLabel'])),
              _meta(Icons.schedule_rounded, _text(notice['dateLabel'])),
              if (_text(notice['publishedBy']).isNotEmpty)
                _meta(Icons.person_rounded, _text(notice['publishedBy'])),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _text(notice['body']),
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _deleteNotice(notice),
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: const Text('Delete'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.error,
                side: const BorderSide(color: AppTheme.error),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplates() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = width >= 980
            ? 4
            : width >= 680
            ? 3
            : 2;
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: width < 420 ? 1.1 : 1.35,
          ),
          itemCount: _templates.length,
          itemBuilder: (_, i) {
            final template = _templates[i];
            final color = template['color'] as Color;
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _openComposePage(
                templateName: _text(template['name']),
                audience: _text(template['audience'], fallback: 'Everyone'),
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withAlpha(60)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(template['icon'] as IconData, color: color, size: 30),
                    const SizedBox(height: 8),
                    Text(
                      _text(template['name']),
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _text(template['audience']),
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppTheme.muted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSentHistory() {
    final sent = _filteredNotices;
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildFilters(),
          const SizedBox(height: 12),
          if (sent.isEmpty)
            SizedBox(height: 360, child: _emptyState('No sent notices found.'))
          else
            ...sent.map(
              (notice) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.success,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _text(notice['title']),
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${_text(notice['audienceLabel'])} · ${_text(notice['dateLabel'])}',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteNotice(Map<String, dynamic> notice) async {
    final id = _text(notice['id']);
    if (id.isEmpty) return;
    await BackendApiClient.instance.deleteRaw('/notices/$id');
    await _loadData();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notice deleted'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  Future<void> _openComposePage({
    String? templateName,
    String? audience,
  }) async {
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AdminComposeNoticePage(
          templateName: templateName,
          initialAudience: audience,
          onSubmit:
              ({
                required String title,
                required String body,
                required String audience,
                required bool isUrgent,
              }) async {
                await BackendApiClient.instance.createAnnouncement(
                  title: title,
                  content: body,
                  targetAudience: _audienceValue(audience),
                  isUrgent: isUrgent,
                );
              },
        ),
      ),
    );
    if (sent != true || !mounted) return;
    await _loadData();
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.muted),
        const SizedBox(width: 3),
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
        ),
      ],
    );
  }

  Widget _emptyState(
    String message, {
    String? actionLabel,
    Future<void> Function()? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.campaign_outlined,
              size: 44,
              color: AppTheme.muted,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.muted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 14),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }

  String _audienceLabel(String value) {
    switch (_audienceValue(value)) {
      case 'parents':
        return 'Parents';
      case 'teachers':
        return 'Teachers';
      case 'students':
        return 'Students';
      case 'admin':
        return 'Admin';
      case 'principal':
        return 'Principal';
      default:
        return 'Everyone';
    }
  }

  String _audienceValue(String label) {
    switch (label.trim().toLowerCase()) {
      case 'parents':
      case 'all parents':
        return 'parents';
      case 'teachers':
      case 'all teachers':
      case 'staff':
        return 'teachers';
      case 'students':
        return 'students';
      case 'admin':
      case 'admins':
        return 'admin';
      case 'principal':
      case 'principals':
        return 'principal';
      default:
        return 'all';
    }
  }

  String _formatDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final local = parsed.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
  }

  String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty || text == 'null' ? fallback : text;
  }
}

class _AdminComposeNoticePage extends StatefulWidget {
  const _AdminComposeNoticePage({
    required this.onSubmit,
    this.templateName,
    this.initialAudience,
  });

  final String? templateName;
  final String? initialAudience;
  final Future<void> Function({
    required String title,
    required String body,
    required String audience,
    required bool isUrgent,
  })
  onSubmit;

  @override
  State<_AdminComposeNoticePage> createState() =>
      _AdminComposeNoticePageState();
}

class _AdminComposeNoticePageState extends State<_AdminComposeNoticePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  final _bodyCtrl = TextEditingController();
  late String _audience;
  bool _isUrgent = false;
  bool _saving = false;
  String? _error;

  static const _audiences = [
    'Everyone',
    'Parents',
    'Teachers',
    'Students',
    'Admin',
    'Principal',
  ];

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(
      text: widget.templateName != null ? '${widget.templateName}: ' : '',
    );
    _audience = _audiences.contains(widget.initialAudience)
        ? widget.initialAudience!
        : 'Everyone';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        audience: _audience,
        isUrgent: _isUrgent,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notice published'),
          backgroundColor: AppTheme.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Notice publish failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compose Notice')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _titleCtrl,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Title'),
                textInputAction: TextInputAction.next,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Title is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bodyCtrl,
                enabled: !_saving,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Message body'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Message body is required'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _audience,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Audience'),
                items: _audiences
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _audience = value ?? _audience),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _isUrgent,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _isUrgent = value ?? false),
                title: Text(
                  'Mark as urgent',
                  style: GoogleFonts.dmSans(fontSize: 13),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: AppTheme.error)),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_saving ? 'Publishing...' : 'Publish Now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
