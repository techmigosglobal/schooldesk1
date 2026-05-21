import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_navigation.dart';
import '../../widgets/empty_state_widget.dart';
import '../../services/backend_api_client.dart';
import '../../services/backend_data_service.dart';
import '../../widgets/erp_module_scaffold.dart';

class ComplaintManagementScreen extends StatefulWidget {
  const ComplaintManagementScreen({super.key});

  @override
  State<ComplaintManagementScreen> createState() =>
      _ComplaintManagementScreenState();
}

class _ComplaintManagementScreenState extends State<ComplaintManagementScreen>
    with SingleTickerProviderStateMixin {
  int _selectedDrawerIndex = 9;
  late TabController _tabController;
  String _selectedCategory = 'All';
  List<Map<String, dynamic>> _complaints = [];
  BackendDataService? _storage;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      _storage = await BackendDataService.getInstance();
      final data = await _storage!.getList(BackendDataService.kComplaints);
      if (!mounted) return;
      setState(() {
        _complaints = data;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<bool> _saveComplaint(Map<String, dynamic> complaint) async {
    try {
      final id = '${complaint['id'] ?? ''}';
      final persisted =
          complaint.containsKey('resource') ||
          complaint.containsKey('created_at');
      if (id.isEmpty ||
          (!persisted && (id.startsWith('cp') || id.startsWith('disc_')))) {
        final saved = await BackendApiClient.instance.createRaw(
          '/complaints',
          complaint,
        );
        if (!mounted || '${saved['id'] ?? ''}'.isEmpty) return false;
        final localIndex = _complaints.indexWhere((c) => c['id'] == id);
        if (localIndex != -1) {
          setState(() => _complaints[localIndex] = saved);
        }
        return true;
      }
      final saved = await BackendApiClient.instance.updateRaw(
        '/complaints/$id',
        complaint,
      );
      if (!mounted || '${saved['id'] ?? ''}'.isEmpty) return false;
      final localIndex = _complaints.indexWhere((c) => c['id'] == id);
      if (localIndex != -1) {
        setState(() => _complaints[localIndex] = saved);
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Complaint save failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      await _loadData();
      return false;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredComplaints {
    if (_selectedCategory == 'All') return _complaints;
    return _complaints
        .where((c) => c['category'] == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final drawer = PrincipalDrawer(
      selectedIndex: _selectedDrawerIndex,
      onDestinationSelected: (i) => setState(() => _selectedDrawerIndex = i),
    );
    if (_loading) {
      return SchoolDeskModuleScaffold(
        title: 'Complaints',
        subtitle: 'Monitor support tickets, escalations, and resolution status',
        drawer: drawer,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SchoolDeskModuleScaffold(
        title: 'Complaints',
        subtitle: 'Monitor support tickets, escalations, and resolution status',
        drawer: drawer,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    setState(() => _loading = true);
                    _loadData();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SchoolDeskModuleScaffold(
      title: 'Complaints',
      subtitle: 'Monitor support tickets, escalations, and resolution status',
      drawer: drawer,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewComplaintDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Ticket'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'All Tickets'),
          Tab(text: 'In Progress'),
          Tab(text: 'Resolved'),
        ],
      ),
      body: MediaQuery.of(context).size.width >= 840
          ? _buildTabletLayout(context)
          : _buildPhoneLayout(context),
    );
  }

  Widget _buildPhoneLayout(BuildContext context) {
    return TabBarView(
      controller: _tabController,
      children: [_buildAllTab(), _buildInProgressTab(), _buildResolvedTab()],
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return TabBarView(
      controller: _tabController,
      children: [_buildAllTab(), _buildInProgressTab(), _buildResolvedTab()],
    );
  }

  Widget _buildAllTab() {
    return Column(
      children: [
        _buildCategoryFilter(),
        Expanded(
          child: _filteredComplaints.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.inbox_rounded,
                  title: 'No complaints found',
                  description: 'No tickets match the selected filter',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: _filteredComplaints.length,
                  itemBuilder: (ctx, i) =>
                      _buildComplaintCard(_filteredComplaints[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildInProgressTab() {
    final items = _complaints
        .where((c) => c['status'] == 'in_progress')
        .toList();
    return items.isEmpty
        ? const EmptyStateWidget(
            icon: Icons.pending_actions_rounded,
            title: 'No in-progress tickets',
            description: 'All tickets are either open or resolved',
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: items.length,
            itemBuilder: (ctx, i) => _buildComplaintCard(items[i]),
          );
  }

  Widget _buildResolvedTab() {
    final items = _complaints.where((c) => c['status'] == 'resolved').toList();
    return items.isEmpty
        ? const EmptyStateWidget(
            icon: Icons.check_circle_outline_rounded,
            title: 'No resolved tickets',
            description: 'Resolved tickets will appear here',
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: items.length,
            itemBuilder: (ctx, i) => _buildComplaintCard(items[i]),
          );
  }

  Widget _buildCategoryFilter() {
    final categories = [
      'All',
      'Facilities',
      'Teacher',
      'Student',
      'Finance',
      'Other',
    ];
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: categories.map((cat) {
            final selected = _selectedCategory == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.primary
                          : AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected
                            ? AppTheme.primary
                            : AppTheme.outlineVariant,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : AppTheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildComplaintCard(Map<String, dynamic> c) {
    final statusColors = {
      'open': AppTheme.warning,
      'in_progress': AppTheme.info,
      'resolved': AppTheme.success,
    };
    final priorityColors = {
      'high': AppTheme.error,
      'medium': AppTheme.warning,
      'low': AppTheme.success,
    };
    final statusColor = statusColors[c['status']] ?? AppTheme.muted;
    final priorityColor = priorityColors[c['priority']] ?? AppTheme.muted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withAlpha(40)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    c['ticketNo'] as String? ?? '',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.muted,
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
                    color: priorityColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${c['priority']} priority',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: priorityColor,
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
                    color: statusColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    (c['status'] as String).replaceAll('_', ' '),
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              c['title'] as String? ?? '',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              c['description'] as String? ?? '',
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppTheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 12,
                  color: AppTheme.muted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    c['submittedBy'] as String? ?? '',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppTheme.muted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 12,
                  color: AppTheme.muted,
                ),
                const SizedBox(width: 4),
                Text(
                  c['date'] as String? ?? '',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
            if ((c['assignedTo'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.assignment_ind_rounded,
                    size: 12,
                    color: AppTheme.info,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Assigned to: ${c['assignedTo']}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppTheme.info,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                if (c['status'] != 'resolved') ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showUpdateDialog(c),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        textStyle: GoogleFonts.dmSans(fontSize: 12),
                      ),
                      child: const Text('Update'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _resolveComplaint(c),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        textStyle: GoogleFonts.dmSans(fontSize: 12),
                      ),
                      child: const Text('Resolve'),
                    ),
                  ),
                ] else
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Resolution: ${c['resolution']}',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: AppTheme.success,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _resolveComplaint(Map<String, dynamic> c) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ResolveComplaintPage(
          complaint: c,
          onSubmit: (resolution) async {
            final idx = _complaints.indexWhere((x) => x['id'] == c['id']);
            if (idx == -1) return false;
            final updated = Map<String, dynamic>.from(_complaints[idx]);
            updated['status'] = 'resolved';
            updated['resolution'] = resolution.trim().isEmpty
                ? 'Issue resolved by management.'
                : resolution.trim();
            return _saveComplaint(updated);
          },
        ),
      ),
    );
  }

  void _showUpdateDialog(Map<String, dynamic> c) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _UpdateComplaintPage(
          complaint: c,
          onSubmit: ({required String status, required String assignedTo}) {
            final idx = _complaints.indexWhere((x) => x['id'] == c['id']);
            if (idx == -1) return Future.value(false);
            final updated = Map<String, dynamic>.from(_complaints[idx]);
            updated['status'] = status;
            updated['assignedTo'] = assignedTo.trim();
            return _saveComplaint(updated);
          },
        ),
      ),
    );
  }

  void _showNewComplaintDialog() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _NewComplaintPage(
          complaintCount: _complaints.length,
          monthName: _monthName,
          onSubmit: (ticket) async {
            final saved = await _saveComplaint(ticket);
            if (saved) await _loadData();
            return saved;
          },
        ),
      ),
    );
  }

  String _monthName(int m) {
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
    return months[m - 1];
  }
}

class _ResolveComplaintPage extends StatefulWidget {
  const _ResolveComplaintPage({
    required this.complaint,
    required this.onSubmit,
  });

  final Map<String, dynamic> complaint;
  final Future<bool> Function(String resolution) onSubmit;

  @override
  State<_ResolveComplaintPage> createState() => _ResolveComplaintPageState();
}

class _ResolveComplaintPageState extends State<_ResolveComplaintPage> {
  final _formKey = GlobalKey<FormState>();
  final _resolutionCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _resolutionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.onSubmit(_resolutionCtrl.text);
    if (!mounted) return;
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ticket resolved'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = false;
      _error = 'Ticket was not resolved because backend save failed.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = '${widget.complaint['title'] ?? 'Complaint'}';
    return Scaffold(
      appBar: AppBar(title: const Text('Resolve Ticket')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                title,
                style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.muted),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _resolutionCtrl,
                enabled: !_saving,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Resolution details',
                ),
                validator: (value) => value != null && value.length > 500
                    ? 'Resolution must be under 500 characters'
                    : null,
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
                    : const Icon(Icons.check_circle_rounded),
                label: Text(_saving ? 'Saving...' : 'Mark Resolved'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpdateComplaintPage extends StatefulWidget {
  const _UpdateComplaintPage({required this.complaint, required this.onSubmit});

  final Map<String, dynamic> complaint;
  final Future<bool> Function({
    required String status,
    required String assignedTo,
  })
  onSubmit;

  @override
  State<_UpdateComplaintPage> createState() => _UpdateComplaintPageState();
}

class _UpdateComplaintPageState extends State<_UpdateComplaintPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _assignCtrl;
  late String _status;
  bool _saving = false;
  String? _error;

  static const _statuses = ['open', 'in_progress', 'resolved'];

  @override
  void initState() {
    super.initState();
    _assignCtrl = TextEditingController(
      text: '${widget.complaint['assignedTo'] ?? ''}',
    );
    final current = '${widget.complaint['status'] ?? 'open'}';
    _status = _statuses.contains(current) ? current : 'open';
  }

  @override
  void dispose() {
    _assignCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final saved = await widget.onSubmit(
      status: _status,
      assignedTo: _assignCtrl.text,
    );
    if (!mounted) return;
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ticket updated'),
          backgroundColor: AppTheme.info,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = false;
      _error = 'Ticket was not updated because backend save failed.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Update Ticket')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: _statuses
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.replaceAll('_', ' ')),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _status = value ?? _status),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _assignCtrl,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Assigned To'),
                validator: (value) => value != null && value.length > 80
                    ? 'Assigned person must be under 80 characters'
                    : null,
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
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Saving...' : 'Update'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewComplaintPage extends StatefulWidget {
  const _NewComplaintPage({
    required this.complaintCount,
    required this.monthName,
    required this.onSubmit,
  });

  final int complaintCount;
  final String Function(int month) monthName;
  final Future<bool> Function(Map<String, dynamic> ticket) onSubmit;

  @override
  State<_NewComplaintPage> createState() => _NewComplaintPageState();
}

class _NewComplaintPageState extends State<_NewComplaintPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _submittedByCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  String _category = 'Facilities';
  String _priority = 'medium';
  bool _saving = false;
  String? _error;

  static const _categories = [
    'Facilities',
    'Teacher',
    'Student',
    'Finance',
    'Other',
  ];

  static const _priorities = ['high', 'medium', 'low'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _submittedByCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final now = DateTime.now();
    final ticket = {
      'id': 'cp${now.millisecondsSinceEpoch}',
      'ticketNo':
          'GRV-${now.year}-${(widget.complaintCount + 1).toString().padLeft(3, '0')}',
      'title': _titleCtrl.text.trim(),
      'category': _category,
      'submittedBy': _submittedByCtrl.text.trim().isEmpty
          ? 'Unknown'
          : _submittedByCtrl.text.trim(),
      'date': '${now.day} ${widget.monthName(now.month)} ${now.year}',
      'status': 'open',
      'priority': _priority,
      'description': _descriptionCtrl.text.trim(),
      'assignedTo': '',
      'resolution': '',
    };
    final saved = await widget.onSubmit(ticket);
    if (!mounted) return;
    if (saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ticket created'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = false;
      _error = 'Ticket was not created because backend save failed.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Complaint Ticket')),
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
                controller: _submittedByCtrl,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Submitted By'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _category = value ?? _category),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: _priorities
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _priority = value ?? _priority),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionCtrl,
                enabled: !_saving,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Description is required'
                    : null,
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
                    : const Icon(Icons.add_rounded),
                label: Text(_saving ? 'Creating...' : 'Create Ticket'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
