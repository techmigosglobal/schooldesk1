import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/widgets/empty_state_widget.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/backend_data_service.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/utils/extensions.dart';

class ParentComplaintScreen extends StatefulWidget {
  const ParentComplaintScreen({super.key});

  @override
  State<ParentComplaintScreen> createState() => _ParentComplaintScreenState();
}

class _ParentComplaintScreenState extends State<ParentComplaintScreen>
    with SingleTickerProviderStateMixin {
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
        _complaints = data
            .where(
              (c) => c['role'] == 'parent' || c['reported_by_role'] == 'parent',
            )
            .toList();
        _loading = false;
        _error = null;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<bool> _saveComplaint(Map<String, dynamic> complaint) async {
    try {
      complaint['role'] = 'parent';
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

        // Report to super admin if it's an error
        if (complaint['type'] == 'error') {
          await _reportToSuperAdmin(saved);
        }

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
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Complaint save failed: $e'),
            backgroundColor: context.appTheme.error,
          ),
        );
      }
      await _loadData();
      return false;
    }
  }

  Future<void> _reportToSuperAdmin(Map<String, dynamic> complaint) async {
    try {
      await BackendApiClient.instance.createRaw('/error-reports', {
        'complaint_id': complaint['id'],
        'type': complaint['type'],
        'message': complaint['message'],
        'reported_by_role': 'parent',
        'severity': 'high',
      });
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to report to admin: $e'),
            backgroundColor: context.appTheme.error,
          ),
        );
      }
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
    if (_loading) {
      return const SchoolDeskModuleScaffold(
        title: 'Complaints',
        subtitle: 'Submit support tickets and track resolution',
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SchoolDeskModuleScaffold(
        title: 'Complaints',
        subtitle: 'Submit support tickets and track resolution',
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
      subtitle: 'Submit support tickets and track resolution',
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
      body: TabBarView(
        controller: _tabController,
        children: [_buildAllTab(), _buildInProgressTab(), _buildResolvedTab()],
      ),
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
                  itemBuilder: (context, index) {
                    final complaint = _filteredComplaints[index];
                    return _buildComplaintCard(complaint);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInProgressTab() {
    final inProgress = _filteredComplaints
        .where((c) => c['status'] == 'in_progress' || c['status'] == 'open')
        .toList();
    return inProgress.isEmpty
        ? const EmptyStateWidget(
            icon: Icons.done_all_rounded,
            title: 'No active complaints',
            description: 'All tickets have been resolved',
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: inProgress.length,
            itemBuilder: (context, index) {
              final complaint = inProgress[index];
              return _buildComplaintCard(complaint);
            },
          );
  }

  Widget _buildResolvedTab() {
    final resolved = _filteredComplaints
        .where((c) => c['status'] == 'resolved' || c['status'] == 'closed')
        .toList();
    return resolved.isEmpty
        ? const EmptyStateWidget(
            icon: Icons.inbox_rounded,
            title: 'No resolved complaints',
            description: 'You have no closed tickets yet',
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: resolved.length,
            itemBuilder: (context, index) {
              final complaint = resolved[index];
              return _buildComplaintCard(complaint);
            },
          );
  }

  Widget _buildComplaintCard(Map<String, dynamic> complaint) {
    final status = complaint['status'] ?? 'open';
    final isResolved = status == 'resolved' || status == 'closed';
    final isInProgress = status == 'in_progress';
    final statusColor = isResolved
        ? const Color(0xFF16A34A)
        : isInProgress
        ? const Color(0xFFD97706)
        : const Color(0xFF1D4ED8);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: context.appTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withAlpha(50)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withAlpha(18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Accent sidebar
            Container(
              width: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [statusColor, statusColor.withAlpha(160)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            complaint['subject'] ?? 'Untitled',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: context.appTheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                statusColor.withAlpha(28),
                                statusColor.withAlpha(16),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: statusColor.withAlpha(60),
                            ),
                          ),
                          child: Text(
                            status.replaceAll('_', ' ').toUpperCase(),
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.notes_rounded,
                          size: 13,
                          color: context.appTheme.muted,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            complaint['message'] ?? 'No description',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: context.appTheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if ((complaint['category'] ?? '')
                        .toString()
                        .isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: context.appTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          complaint['category'].toString(),
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.appTheme.muted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final categories = ['All', 'Academic', 'Facility', 'Staff', 'Other'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: categories.map((category) {
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = category),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF0F766E), Color(0xFF1A6B4A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : context.appTheme.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : context.appTheme.outlineVariant,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF1A6B4A).withAlpha(50),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  category,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? Colors.white
                        : context.appTheme.onSurface,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showNewComplaintDialog() {
    final subjectCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    String selectedCategory = 'Academic';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Complaint'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: subjectCtrl,
              decoration: const InputDecoration(hintText: 'Subject'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              items: [
                'Academic',
                'Facility',
                'Staff',
                'Other',
              ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) {
                if (v != null) selectedCategory = v;
              },
              decoration: const InputDecoration(hintText: 'Category'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Message',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              _saveComplaint({
                'id': 'cp_${DateTime.now().millisecondsSinceEpoch}',
                'subject': subjectCtrl.text,
                'message': messageCtrl.text,
                'category': selectedCategory,
                'status': 'open',
                'role': 'parent',
              }).then((_) {
                if (context.mounted) {
                  Navigator.pop(context);
                  _loadData();
                }
              });
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
