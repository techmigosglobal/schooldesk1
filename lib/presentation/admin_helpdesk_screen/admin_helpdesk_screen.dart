import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/backend_data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/admin_navigation.dart';
import '../../widgets/dashboard_fab_widget.dart';
import '../../widgets/erp_module_scaffold.dart';

class AdminHelpdeskScreen extends StatefulWidget {
  const AdminHelpdeskScreen({super.key});

  @override
  State<AdminHelpdeskScreen> createState() => _AdminHelpdeskScreenState();
}

class _AdminHelpdeskScreenState extends State<AdminHelpdeskScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _filterStatus = 'All';
  BackendDataService? _storage;
  bool _loading = true;

  List<Map<String, dynamic>> _tickets = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    _storage = await BackendDataService.getInstance();
    final stored = await _storage!.getList(
      BackendDataService.kSharedHelpdeskTickets,
    );
    setState(() {
      _tickets = stored;
      _loading = false;
    });
  }

  Future<void> _saveTicket(Map<String, dynamic> ticket) async {
    await _storage?.saveList(BackendDataService.kSharedHelpdeskTickets, [
      ticket,
    ]);
    await _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _ticketText(
    Map<String, dynamic> ticket,
    String key, {
    String fallback = '',
  }) {
    final value = ticket[key];
    if (value == null) return fallback;
    final text = '$value'.trim();
    return text.isEmpty ? fallback : text;
  }

  String _ticketStatus(Map<String, dynamic> ticket) {
    final raw = _ticketText(ticket, 'status', fallback: 'Open').toLowerCase();
    if (raw == 'in_progress' || raw == 'in progress') return 'In Progress';
    if (raw == 'resolved' || raw == 'closed') return 'Resolved';
    if (raw == 'escalated') return 'Escalated';
    return 'Open';
  }

  List<Map<String, dynamic>> get _filtered => _filterStatus == 'All'
      ? _tickets
      : _tickets.where((t) => _ticketStatus(t) == _filterStatus).toList();

  @override
  Widget build(BuildContext context) {
    final drawer = AdminDrawer(selectedIndex: 8, onDestinationSelected: (_) {});
    if (_loading) {
      return SchoolDeskModuleScaffold(
        title: 'Parent Support / Helpdesk',
        subtitle: 'Track parent tickets, escalations, and resolution health',
        drawer: drawer,
        floatingActionButton: const DashboardFabWidget(
          role: DashboardRole.admin,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return SchoolDeskModuleScaffold(
      title: 'Parent Support / Helpdesk',
      subtitle: 'Track parent tickets, escalations, and resolution health',
      drawer: drawer,
      floatingActionButton: const DashboardFabWidget(role: DashboardRole.admin),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      actions: [
        IconButton(
          tooltip: 'Create ticket',
          icon: const Icon(Icons.add_rounded),
          onPressed: _openNewTicketPage,
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Tickets'),
          Tab(text: 'Stats'),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildTickets(), _buildStats()],
      ),
    );
  }

  Widget _buildTickets() {
    return Column(
      children: [
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ['All', 'Open', 'In Progress', 'Resolved'].length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final s = ['All', 'Open', 'In Progress', 'Resolved'][i];
                return FilterChip(
                  label: Text(s, style: GoogleFonts.dmSans(fontSize: 11)),
                  selected: _filterStatus == s,
                  onSelected: (_) => setState(() => _filterStatus = s),
                );
              },
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: AppTheme.primary,
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _buildTicketCard(_filtered[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> t) {
    final statusColors = {
      'Open': AppTheme.error,
      'In Progress': AppTheme.warning,
      'Resolved': AppTheme.success,
    };
    final priorityColors = {
      'High': AppTheme.error,
      'Medium': AppTheme.warning,
      'Low': AppTheme.success,
    };
    final status = _ticketStatus(t);
    final priority = _ticketText(t, 'priority', fallback: 'Medium');
    final category = _ticketText(t, 'category', fallback: 'General');
    final ticketId = _ticketText(t, 'id', fallback: 'Ticket');
    final subject = _ticketText(t, 'subject', fallback: 'Helpdesk ticket');
    final date = _ticketText(
      t,
      'date',
      fallback: _ticketText(t, 'created_at'),
    ).split('T').first;
    final sc = statusColors[status] ?? AppTheme.muted;
    final pc = priorityColors[priority] ?? AppTheme.muted;
    final parentName = _ticketText(
      t,
      'parentName',
      fallback: _ticketText(t, 'parent'),
    );
    final studentName = _ticketText(
      t,
      'studentName',
      fallback: _ticketText(t, 'student'),
    );
    final response = _ticketText(t, 'response');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status == 'Open'
              ? AppTheme.errorContainer
              : AppTheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                ticketId,
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: pc.withAlpha(25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  priority,
                  style: GoogleFonts.dmSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: pc,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: sc.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: sc,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subject,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '$parentName (Parent of $studentName) • $category • $date',
            style: GoogleFonts.dmSans(fontSize: 11, color: AppTheme.muted),
          ),
          if (response.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Response: $response',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (status != 'Resolved') ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openRespondPage(t),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    child: Text(
                      'Respond',
                      style: GoogleFonts.dmSans(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      setState(() => t['status'] = 'Resolved');
                      await _saveTicket(t);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Ticket $ticketId resolved'),
                            backgroundColor: AppTheme.success,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    child: Text(
                      'Resolve',
                      style: GoogleFonts.dmSans(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              OutlinedButton(
                onPressed: () async {
                  setState(() => t['status'] = 'Escalated');
                  await _saveTicket(t);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Ticket $ticketId escalated to Principal',
                        ),
                      ),
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  foregroundColor: AppTheme.error,
                  side: const BorderSide(color: AppTheme.error),
                ),
                child: Text(
                  'Escalate',
                  style: GoogleFonts.dmSans(fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final open = _tickets.where((t) => _ticketStatus(t) == 'Open').length;
    final inProgress = _tickets
        .where((t) => _ticketStatus(t) == 'In Progress')
        .length;
    final resolved = _tickets
        .where((t) => _ticketStatus(t) == 'Resolved')
        .length;
    final categories = <String, int>{};
    for (final t in _tickets) {
      final category = _ticketText(t, 'category', fallback: 'General');
      categories[category] = (categories[category] ?? 0) + 1;
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ticket Overview',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard('Open', open, AppTheme.error)),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  'In Progress',
                  inProgress,
                  AppTheme.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard('Resolved', resolved, AppTheme.success),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'By Category',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...categories.entries.map(
            (e) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.key,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${e.value}',
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
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

  Widget _buildStatCard(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: GoogleFonts.dmSans(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(label, style: GoogleFonts.dmSans(fontSize: 11, color: color)),
        ],
      ),
    );
  }

  Future<void> _openRespondPage(Map<String, dynamic> t) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => _HelpdeskResponsePage(
          ticket: t,
          onSubmit: (response) async {
            setState(() {
              t['response'] = response;
              t['status'] = 'In Progress';
            });
            await _saveTicket(t);
            return 'Response sent to parent';
          },
        ),
      ),
    );
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.success),
    );
  }

  Future<void> _openNewTicketPage() async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => _HelpdeskTicketFormPage(
          nextTicketNumber: _tickets.length + 1,
          onSubmit: (ticket) async {
            setState(() => _tickets.insert(0, ticket));
            await _saveTicket(ticket);
            return 'Ticket created';
          },
        ),
      ),
    );
    if (!mounted || message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.success),
    );
  }
}

class _HelpdeskResponsePage extends StatefulWidget {
  final Map<String, dynamic> ticket;
  final Future<String> Function(String response) onSubmit;

  const _HelpdeskResponsePage({required this.ticket, required this.onSubmit});

  @override
  State<_HelpdeskResponsePage> createState() => _HelpdeskResponsePageState();
}

class _HelpdeskResponsePageState extends State<_HelpdeskResponsePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _responseCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _responseCtrl = TextEditingController(
      text: widget.ticket['response'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    _responseCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final message = await widget.onSubmit(_responseCtrl.text.trim());
      if (mounted) Navigator.pop(context, message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Response failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticketId = widget.ticket['id']?.toString() ?? 'Ticket';
    final subject = widget.ticket['subject']?.toString() ?? 'Support ticket';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Respond to $ticketId',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                subject,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _responseCtrl,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Your Response',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final response = value?.trim() ?? '';
                  if (response.isEmpty) return 'Enter a response';
                  if (response.length < 10) return 'Add more response detail';
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _HelpdeskInlineError(message: _error!),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_saving ? 'Sending...' : 'Send Response'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpdeskTicketFormPage extends StatefulWidget {
  final int nextTicketNumber;
  final Future<String> Function(Map<String, dynamic> ticket) onSubmit;

  const _HelpdeskTicketFormPage({
    required this.nextTicketNumber,
    required this.onSubmit,
  });

  @override
  State<_HelpdeskTicketFormPage> createState() =>
      _HelpdeskTicketFormPageState();
}

class _HelpdeskTicketFormPageState extends State<_HelpdeskTicketFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _parentCtrl = TextEditingController();
  final _studentCtrl = TextEditingController();
  String _category = 'Fee';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _parentCtrl.dispose();
    _studentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ticket = {
      'id': 'TKT${widget.nextTicketNumber.toString().padLeft(3, '0')}',
      'parentName': _parentCtrl.text.trim().isEmpty
          ? 'Unknown Parent'
          : _parentCtrl.text.trim(),
      'studentName': _studentCtrl.text.trim().isEmpty
          ? 'N/A'
          : _studentCtrl.text.trim(),
      'class': 'N/A',
      'subject': _subjectCtrl.text.trim(),
      'category': _category,
      'status': 'Open',
      'priority': 'Medium',
      'date': DateTime.now().toIso8601String().split('T').first,
      'response': '',
    };
    try {
      final message = await widget.onSubmit(ticket);
      if (mounted) Navigator.pop(context, message);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Ticket creation failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'New Support Ticket',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppTheme.surface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _parentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Parent Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _studentCtrl,
                decoration: const InputDecoration(
                  labelText: 'Student Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subjectCtrl,
                decoration: const InputDecoration(
                  labelText: 'Issue Subject',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final subject = value?.trim() ?? '';
                  if (subject.isEmpty) return 'Enter issue subject';
                  if (subject.length < 5) return 'Add more subject detail';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items:
                    const [
                          'Fee',
                          'Attendance',
                          'Document',
                          'Complaint',
                          'Facilities',
                          'Other',
                        ]
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _category = value!),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _HelpdeskInlineError(message: _error!),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded),
                label: Text(_saving ? 'Creating...' : 'Create Ticket'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpdeskInlineError extends StatelessWidget {
  final String message;

  const _HelpdeskInlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withAlpha(18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.error.withAlpha(80)),
      ),
      child: Text(
        message,
        style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.error),
      ),
    );
  }
}
