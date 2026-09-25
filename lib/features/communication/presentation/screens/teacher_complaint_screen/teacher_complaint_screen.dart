import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:schooldesk1/core/repositories/repository_state.dart';
import 'package:schooldesk1/core/widgets/empty_state_widget.dart';
import 'package:schooldesk1/core/widgets/erp_module_scaffold.dart';
import 'package:schooldesk1/core/widgets/repository_state_view.dart';
import 'package:schooldesk1/core/utils/extensions.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/modules/communication/data/repositories/api_complaint_repository.dart';
import 'package:schooldesk1/modules/communication/domain/repositories/complaint_repository.dart';

class TeacherComplaintScreen extends StatefulWidget {
  final ComplaintRepository? repository;

  const TeacherComplaintScreen({super.key, this.repository});

  @override
  State<TeacherComplaintScreen> createState() => _TeacherComplaintScreenState();
}

class _TeacherComplaintScreenState extends State<TeacherComplaintScreen>
    with SingleTickerProviderStateMixin {
  ComplaintRepository get _repository =>
      widget.repository ?? ApiComplaintRepository.legacyDefault;

  late TabController _tabController;
  String _selectedCategory = 'All';
  List<Map<String, dynamic>> _complaints = [];
  RepositoryState<List<Map<String, dynamic>>> _repositoryState =
      const RepositoryState.loading();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final previous = _repositoryState;
    setState(() {
      _repositoryState = RepositoryState.loading(
        data: previous.data,
        source: previous.source,
        isStale: previous.isStale,
        isRefreshing: previous.hasData,
        lastUpdated: previous.lastUpdated,
      );
    });
    try {
      final result = await _repository.loadForRole('teacher');
      _throwIfFailed(result, 'Unable to load complaints');
      final data = result.dataOrNull!;
      if (!mounted) return;
      setState(() {
        _complaints = data;
        _repositoryState = RepositoryState(
          data: List<Map<String, dynamic>>.unmodifiable(data),
          source: RepositorySource.remote,
          phase: data.isEmpty ? RepositoryPhase.empty : RepositoryPhase.ready,
          lastUpdated: DateTime.now().toUtc(),
        );
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _repositoryState = previous.hasData
            ? RepositoryState(
                data: previous.data,
                source: RepositorySource.cache,
                isStale: true,
                error: e,
                lastUpdated: previous.lastUpdated,
              )
            : RepositoryState.error(error: e);
      });
    }
  }

  Future<bool> _saveComplaint(Map<String, dynamic> complaint) async {
    try {
      complaint['role'] = 'teacher';
      final id = '${complaint['id'] ?? ''}';
      final persisted =
          complaint.containsKey('resource') ||
          complaint.containsKey('created_at');
      if (id.isEmpty ||
          (!persisted && (id.startsWith('cp') || id.startsWith('disc_')))) {
        final result = await _repository.save(complaint, role: 'teacher');
        _throwIfFailed(result, 'Unable to save complaint');
        final saved = result.dataOrNull!;
        if (!mounted || '${saved['id'] ?? ''}'.isEmpty) return false;

        // Report to super admin if it's an error
        if (complaint['type'] == 'error') {
          await _reportToSuperAdmin(saved);
        }

        final localIndex = _complaints.indexWhere((c) => c['id'] == id);
        if (localIndex != -1) {
          setState(() {
            _complaints[localIndex] = saved;
            _repositoryState = RepositoryState(
              data: List<Map<String, dynamic>>.unmodifiable(_complaints),
              source: RepositorySource.localMutation,
            );
          });
        }
        return true;
      }
      final result = await _repository.save(complaint, role: 'teacher');
      _throwIfFailed(result, 'Unable to save complaint');
      final saved = result.dataOrNull!;
      if (!mounted || '${saved['id'] ?? ''}'.isEmpty) return false;
      final localIndex = _complaints.indexWhere((c) => c['id'] == id);
      if (localIndex != -1) {
        setState(() {
          _complaints[localIndex] = saved;
          _repositoryState = RepositoryState(
            data: List<Map<String, dynamic>>.unmodifiable(_complaints),
            source: RepositorySource.localMutation,
          );
        });
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
      final result = await _repository.reportToSuperAdmin(
        complaint: complaint,
        role: 'teacher',
      );
      _throwIfFailed(result, 'Unable to report complaint');
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

  void _throwIfFailed<T>(Result<T> result, String fallback) {
    if (result.isFailure) {
      throw StateError(result.failureOrNull?.message ?? fallback);
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
      body: SchoolDeskRepositoryStateView<List<Map<String, dynamic>>>(
        state: _repositoryState,
        onRetry: _loadData,
        emptyTitle: 'No complaints found',
        emptyMessage: 'No support tickets exist for this teacher scope.',
        errorTitle: 'Complaints unavailable',
        data: (_) => TabBarView(
          controller: _tabController,
          children: [
            _buildAllTab(),
            _buildInProgressTab(),
            _buildResolvedTab(),
          ],
        ),
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
    final statusColor = status == 'resolved' || status == 'closed'
        ? Colors.green
        : status == 'in_progress'
        ? Colors.orange
        : Colors.blue;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              complaint['message'] ?? 'No description',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: ['All', 'Academic', 'Facility', 'Admin', 'Other']
            .map(
              (category) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilterChip(
                  selected: _selectedCategory == category,
                  label: Text(category),
                  onSelected: (selected) {
                    setState(() => _selectedCategory = category);
                  },
                ),
              ),
            )
            .toList(),
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
                'Admin',
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
                'role': 'teacher',
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
